import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/job/resume_customer_job.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/map_style_utils.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/active_job_banner.dart';
import '../widgets/map_markers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class HomeMapPage extends ConsumerStatefulWidget {
  const HomeMapPage({super.key});

  @override
  ConsumerState<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends ConsumerState<HomeMapPage>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _mapController;
  GoRouter? _router;
  String? _lastHomeRefreshPath;

  // Custom marker bitmaps — loaded once in initState
  BitmapDescriptor? _youMarker;
  final Map<String, BitmapDescriptor> _providerMarkers = {};
  Set<Marker> _markers = {};
  List<NearbyProvider> _providers = const [];
  bool _locating = false;
  bool _pickupPinnedManually = false;
  int _pickupRequest = 0;
  DateTime? _lastMarkerDragAt;
  String? _coveragePromptKey;
  int _coverageRequest = 0;

  LatLng get _pickup {
    final draft = ref.read(jobDraftProvider);
    return LatLng(draft.pickupLat, draft.pickupLng);
  }

  // Light map style matching the reference design
  static const _mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"water","stylers":[{"color":"#c9e8f5"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffd180"}]}
  ]''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(serviceCategoriesProvider);
    });
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    if (path == '/home' && _lastHomeRefreshPath != path) {
      _lastHomeRefreshPath = path;
      _refreshActiveJob();
    } else if (path != '/home') {
      _lastHomeRefreshPath = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(serviceCategoriesProvider);
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    await _refreshActiveJob();
    if (!mounted) return;
    if (!_pickupPinnedManually &&
        !isResumableCustomerJob(ref.read(jobDraftProvider).activeJob)) {
      await _resolveLocation(silent: true, recenter: true);
    }
  }

  Future<void> _refreshActiveJob() async {
    if (!mounted || !ref.read(isAuthenticatedProvider)) return;
    final container = ProviderScope.containerOf(context, listen: false);
    await fetchAndApplyActiveJob(container);
  }

  Future<bool> _guardNewRequest() async {
    await _refreshActiveJob();
    if (!mounted) return false;
    final active = ref.read(jobDraftProvider).activeJob;
    if (!isResumableCustomerJob(active)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)
              .finishCurrentRequestBeforeStartingAnother,
        ),
      ),
    );
    await resumeCustomerJob(context, active!);
    return false;
  }

  bool _hasDropoff(JobRequestDraft draft) {
    return draft.dropoffLat != null &&
        draft.dropoffLng != null &&
        draft.dropoffAddress.trim().isNotEmpty;
  }

  Future<void> _editDropoff() async {
    if (!await _guardNewRequest()) return;
    final covered = await _promptIfOutsideCoverage(force: true);
    if (!covered || !mounted) return;
    await showPickupLocationPicker(
      context: context,
      autofocusSearch: true,
      forDropoff: true,
    );
  }

  Future<void> _findRide() async {
    if (!await _guardNewRequest()) return;
    final covered = await _promptIfOutsideCoverage(force: true);
    if (!covered || !mounted) return;

    if (!_hasDropoff(ref.read(jobDraftProvider))) {
      final applied = await showPickupLocationPicker(
        context: context,
        autofocusSearch: true,
        forDropoff: true,
      );
      if (!applied || !mounted || !_hasDropoff(ref.read(jobDraftProvider)))
        return;
    }
    if (!mounted) return;
    context.push('/service-request');
  }

  String _ctaLabel(String jobType) => switch (jobType) {
        'bidding' => 'Place a bid',
        'parcel' => 'Send a parcel',
        _ => 'Request ride',
      };

  String _sheetTitle(String jobType) => switch (jobType) {
        'bidding' => 'Name your price',
        'parcel' => 'Send a parcel',
        _ => 'Choose your ride',
      };

  String _sheetSubtitle(String jobType) => switch (jobType) {
        'bidding' => 'Drivers can accept or counter',
        'parcel' => 'A driver delivers your package',
        _ => 'Fast, safe and reliable',
      };

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _firstName(String? fullName) {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty) return 'Rider';
    return name.split(RegExp(r'\s+')).first;
  }

  String _shortPlace(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return trimmed;
    final first = trimmed.split(',').first.trim();
    return first.isEmpty ? trimmed : first;
  }

  String _coverageKey(double lat, double lng) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  /// True when this pickup is inside an admin service zone, or when coverage
  /// could not be checked. False when the dialog was shown.
  Future<bool> _promptIfOutsideCoverage({bool force = false}) async {
    final request = force ? null : ++_coverageRequest;
    final draft = ref.read(jobDraftProvider);
    if (!draft.locationResolved) return true;
    if (!force && isResumableCustomerJob(draft.activeJob)) return true;

    final inside =
        await customerAreaCovered(ref, draft.pickupLat, draft.pickupLng);
    if (!mounted) return true;
    if (!force && request != _coverageRequest) return true;
    if (inside != false) {
      if (inside == true) _coveragePromptKey = null;
      return true;
    }

    final key = _coverageKey(draft.pickupLat, draft.pickupLng);
    if (!force && _coveragePromptKey == key) return false;
    _coveragePromptKey = key;
    await showServiceUnavailableDialog(
      context,
      ref,
      lat: draft.pickupLat,
      lng: draft.pickupLng,
      addressLabel: draft.pickupAddress,
    );
    return false;
  }

  Future<void> _init() async {
    await _refreshActiveJob();
    final youIcon = await MapMarkers.buildYouMarker();
    if (mounted) setState(() => _youMarker = youIcon);
    // Always take a fresh GPS fix on home open so a previous launch
    // address is never reused as the current pickup.
    await _resolveLocation(silent: true, recenter: true);
    await _loadNearbyProviders();
  }

  Future<void> _resolveLocation(
      {bool silent = false, bool recenter = true}) async {
    if (_locating) return;
    final request = ++_pickupRequest;
    setState(() => _locating = true);
    final error = await refreshPickupLocation(ref);
    if (!mounted || request != _pickupRequest) return;
    setState(() => _locating = false);

    if (error != null) {
      if (!silent) _showLocationError(error);
      return;
    }

    _pickupPinnedManually = false;
    if (recenter) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_pickup, 15));
    }
    setState(() => _markers = _buildMarkers());
    await _loadNearbyProviders();
    await _promptIfOutsideCoverage();
  }

  bool _hasPrecisePickup(JobRequestDraft draft) {
    final address = draft.pickupAddress.trim();
    return draft.locationResolved &&
        address.isNotEmpty &&
        address != 'Locating your position…';
  }

  Future<void> _openLocationPicker() async {
    final applied =
        await showPickupLocationPicker(context: context, autofocusSearch: true);
    if (!applied || !mounted) return;
    ref.read(pickupEditGenerationProvider.notifier).state++;
    _pickupRequest++;
    _pickupPinnedManually = true;
    if (_locating) setState(() => _locating = false);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_pickup, 16));
    setState(() => _markers = _buildMarkers());
    await _loadNearbyProviders();
    await _promptIfOutsideCoverage();
  }

  void _onMarkerDragEnd(LatLng position) {
    _lastMarkerDragAt = DateTime.now();
    _commitPickup(position);
  }

  void _onMapTap(LatLng position) {
    final draggedAt = _lastMarkerDragAt;
    if (draggedAt != null &&
        DateTime.now().difference(draggedAt) <
            const Duration(milliseconds: 400)) {
      return;
    }
    _commitPickup(position, recenter: true);
  }

  Future<void> _commitPickup(LatLng position, {bool recenter = false}) async {
    final request = ++_pickupRequest;
    ref.read(pickupEditGenerationProvider.notifier).state++;
    _pickupPinnedManually = true;
    final draft = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state = draft.copyWith(
      pickupLat: position.latitude,
      pickupLng: position.longitude,
      locationResolved: true,
    );
    if (!mounted) return;
    setState(() {
      _locating = true;
      _markers = _buildMarkers();
    });
    if (recenter) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 16));
    }
    await applyPickupCoordinates(ref, position.latitude, position.longitude);
    if (!mounted || request != _pickupRequest) return;
    setState(() {
      _locating = false;
      _markers = _buildMarkers();
    });
    await _loadNearbyProviders();
    await _promptIfOutsideCoverage();
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: AppLocalizations.of(context).settings,
          textColor: Colors.white,
          onPressed: () => ref.read(locationServiceProvider).openAppSettings(),
        ),
      ),
    );
  }

  Future<void> _loadNearbyProviders() async {
    final request = _pickupRequest;
    final pickup = _pickup;
    List<NearbyProvider> providers = const [];
    try {
      providers = await ref
          .read(jobRepositoryProvider)
          .nearbyProviders(lat: pickup.latitude, lng: pickup.longitude);
    } catch (_) {}
    // Only keep providers that have a live location to plot.
    providers = providers.where((p) => p.lat != null && p.lng != null).toList();

    final providerIcons = await Future.wait(
      providers.map((p) => MapMarkers.buildProviderMarker(
            p.etaMinutes != null ? '${p.etaMinutes} min' : '—',
            p.distanceKm != null
                ? '${p.distanceKm!.toStringAsFixed(1)} km'
                : '—',
          )),
    );
    if (!mounted || request != _pickupRequest) return;
    setState(() {
      _providers = providers;
      _providerMarkers.clear();
      for (var i = 0; i < providers.length; i++) {
        _providerMarkers['p$i'] = providerIcons[i];
      }
      _markers = _buildMarkers();
    });
  }

  Set<Marker> _buildMarkers() {
    return {
      Marker(
        markerId: const MarkerId('user'),
        position: _pickup,
        icon: _youMarker ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.75),
        zIndex: 2,
        draggable: true,
        consumeTapEvents: true,
        onDragEnd: _onMarkerDragEnd,
      ),
      ..._providers.asMap().entries.map((e) => Marker(
            markerId: MarkerId('p${e.key}'),
            position: LatLng(e.value.lat!, e.value.lng!),
            icon: _providerMarkers['p${e.key}'] ??
                BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
            anchor: const Offset(0.5, 0.78),
          )),
    };
  }

  Widget _buildDrawer(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final balanceAsync = config.customerWalletEnabled
        ? ref.watch(walletBalanceProvider)
        : const AsyncValue.data(null);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      profileAsync.valueOrNull?.initials ?? '—',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profileAsync.valueOrNull?.fullName ??
                              AppLocalizations.of(context).welcome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          profileAsync.valueOrNull?.phone ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 8),
            _DrawerTile(
              icon: Icons.home_outlined,
              label: AppLocalizations.of(context).home,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerTile(
              icon: Icons.receipt_long_outlined,
              label: AppLocalizations.of(context).bookings,
              onTap: () {
                Navigator.pop(context);
                context.go('/bookings');
              },
            ),
            if (config.customerWalletEnabled)
              _DrawerTile(
                icon: Icons.account_balance_wallet_outlined,
                label: AppLocalizations.of(context).wallet,
                trailing: balanceAsync.valueOrNull != null
                    ? formatMoney(balanceAsync.valueOrNull!.balance)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/wallet');
                },
              ),
            _DrawerTile(
              icon: Icons.directions_car_outlined,
              label: AppLocalizations.of(context).myVehicle,
              onTap: () {
                Navigator.pop(context);
                context.push('/add-vehicle');
              },
            ),
            _DrawerTile(
              icon: Icons.notifications_outlined,
              label: AppLocalizations.of(context).notifications,
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),
            _DrawerTile(
              icon: Icons.person_outline,
              label: AppLocalizations.of(context).profile,
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            const Spacer(),
            Divider(color: AppColors.divider, height: 1),
            _DrawerTile(
              icon: Icons.logout,
              label: AppLocalizations.of(context).signOut,
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                await signOut(ref);
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(jobDraftProvider);
    final activeJob = draft.activeJob;
    final showActiveJobBanner = isResumableCustomerJob(activeJob);
    final unread = ref.watch(notificationsProvider).maybeWhen(
          data: (list) => list.where((n) => !n.isRead).length,
          orElse: () => 0,
        );

    // Keep the "you" marker in sync with the resolved pickup location.
    _markers = _buildMarkers();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(draft.pickupLat, draft.pickupLng),
              zoom: 14.5,
            ),
            onMapCreated: (c) async {
              _mapController = c;
              await applyMapStyle(c, _mapStyle);
              if (!mounted) return;
              if (draft.locationResolved) {
                c.animateCamera(CameraUpdate.newLatLngZoom(_pickup, 15));
              }
            },
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 150, bottom: 250),
            markers: _markers,
            onTap: _locating ? null : _onMapTap,
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HomeHeader(
                    greeting: _greeting(),
                    name: _firstName(
                        ref.watch(profileProvider).valueOrNull?.fullName),
                    unread: unread,
                    onAvatarTap: () => _scaffoldKey.currentState?.openDrawer(),
                    onNotificationsTap: () => context.push('/notifications'),
                  ),
                  const SizedBox(height: 8),
                  _LocationCard(
                    locating: _locating,
                    pickup: _hasPrecisePickup(draft)
                        ? _shortPlace(draft.pickupAddress)
                        : AppLocalizations.of(context).findingAddress,
                    dropoff: draft.dropoffAddress.trim().isEmpty
                        ? null
                        : _shortPlace(draft.dropoffAddress),
                    onPickupTap: _locating ? null : _openLocationPicker,
                    onLocate: _locating ? null : () => _resolveLocation(),
                    onDropoffTap: _locating ? null : _editDropoff,
                  ),
                  if (showActiveJobBanner && activeJob != null) ...[
                    const SizedBox(height: 10),
                    ActiveJobBanner(job: activeJob),
                  ],
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: _MapControls(
                      locating: _locating,
                      onLocate: _locating ? null : () => _resolveLocation(),
                      onZoomIn: () =>
                          _mapController?.animateCamera(CameraUpdate.zoomIn()),
                      onZoomOut: () =>
                          _mapController?.animateCamera(CameraUpdate.zoomOut()),
                    ),
                  ),
                ),
                _HomeRequestSheet(
                  jobType: draft.jobType,
                  title: _sheetTitle(draft.jobType),
                  subtitle: _sheetSubtitle(draft.jobType),
                  ctaLabel: _ctaLabel(draft.jobType),
                  onModeSelected: (mode) {
                    ref.read(jobDraftProvider.notifier).state =
                        draft.copyWith(jobType: mode);
                    ref.invalidate(serviceCategoriesProvider);
                  },
                  onFindRide: _locating ? null : _findRide,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final Color? color;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500, color: c)),
      trailing: trailing != null
          ? Text(trailing!,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary))
          : null,
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.unread,
    required this.onAvatarTap,
    required this.onNotificationsTap,
  });

  final String greeting;
  final String name;
  final int unread;
  final VoidCallback onAvatarTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: AppColors.navy, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: const Center(child: AppLogo(size: 20)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.05),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.1),
              ),
            ],
          ),
        ),
        _RoundMapButton(
          icon: Icons.notifications_none_rounded,
          badge: unread == 0 ? null : unread,
          onTap: onNotificationsTap,
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.locating,
    required this.pickup,
    required this.dropoff,
    required this.onPickupTap,
    required this.onLocate,
    required this.onDropoffTap,
  });

  final bool locating;
  final String pickup;
  final String? dropoff;
  final VoidCallback? onPickupTap;
  final VoidCallback? onLocate;
  final VoidCallback? onDropoffTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        child: Column(
          children: [
            _LocationRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.primary,
              bubble: AppColors.primaryLight,
              label: 'Your location',
              value: pickup,
              valueStrong: true,
              trailing: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.grey500),
                    )
                  : const Icon(Icons.my_location_rounded,
                      color: AppColors.grey500, size: 16),
              onTap: onPickupTap,
              onTrailingTap: onLocate,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 38),
              child: Divider(height: 8, color: Color(0xFFE8EAED)),
            ),
            _LocationRow(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFE11D48),
              bubble: const Color(0xFFFFE4E6),
              label: dropoff == null ? 'Where to?' : 'Dropoff',
              value: dropoff,
              trailing: Icon(
                dropoff == null
                    ? Icons.add_rounded
                    : Icons.chevron_right_rounded,
                color: AppColors.grey500,
                size: 18,
              ),
              onTap: onDropoffTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.bubble,
    required this.label,
    required this.trailing,
    this.value,
    this.valueStrong = false,
    this.onTap,
    this.onTrailingTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color bubble;
  final String label;
  final String? value;
  final bool valueStrong;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bubble, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: value == null ? 14 : 10,
                      fontWeight:
                          value == null ? FontWeight.w500 : FontWeight.w500,
                      color: value == null
                          ? AppColors.grey500
                          : AppColors.textSecondary,
                      height: 1.1,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: valueStrong ? FontWeight.w600 : FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onTrailingTap ?? onTap,
              child: SizedBox(
                  width: 32, height: 32, child: Center(child: trailing)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.locating,
    required this.onLocate,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool locating;
  final VoidCallback? onLocate;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoundMapButton(
          icon: Icons.navigation_rounded,
          busy: locating,
          onTap: onLocate,
        ),
        const SizedBox(height: 8),
        _RoundMapButton(icon: Icons.add_rounded, onTap: onZoomIn),
        const SizedBox(height: 8),
        _RoundMapButton(icon: Icons.remove_rounded, onTap: onZoomOut),
      ],
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.onTap,
    this.badge,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int? badge;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(icon, color: AppColors.navy, size: 18),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.card, width: 1.5),
                ),
                child: Text(
                  badge! > 99 ? '99+' : '$badge',
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      height: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeRequestSheet extends StatelessWidget {
  const _HomeRequestSheet({
    required this.jobType,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onModeSelected,
    required this.onFindRide,
  });

  final String jobType;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final ValueChanged<String> onModeSelected;
  final VoidCallback? onFindRide;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (
        'taxi',
        'Ride',
        'A driver picks you up',
        Icons.directions_car_filled_rounded
      ),
      ('bidding', 'Bid', 'Offer your own price', Icons.sell_rounded),
      ('parcel', 'Parcel', 'Send a package', Icons.inventory_2_rounded),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFD5D8DE),
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15)),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.2)),
            const SizedBox(height: 10),
            for (final mode in modes) ...[
              _ModeOption(
                icon: mode.$4,
                label: mode.$2,
                detail: mode.$3,
                selected: jobType == mode.$1,
                onTap: () => onModeSelected(mode.$1),
              ),
              if (mode.$1 != 'parcel') const SizedBox(height: 6),
            ],
            const SizedBox(height: 10),
            _FindRideButton(
              label: ctaLabel,
              icon: jobType == 'parcel'
                  ? Icons.inventory_2_rounded
                  : jobType == 'bidding'
                      ? Icons.sell_rounded
                      : Icons.directions_car_filled_rounded,
              onTap: onFindRide,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE6E8EC),
                width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? AppColors.card : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: selected ? AppColors.primaryDark : AppColors.navy,
                    size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.1)),
                    Text(detail,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.15)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.grey300,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindRideButton extends StatelessWidget {
  const _FindRideButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null
          ? AppColors.primaryDark.withOpacity(0.45)
          : AppColors.primaryDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
