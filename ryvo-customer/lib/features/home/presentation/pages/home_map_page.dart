import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/job/active_job_session.dart';
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

  Future<void> _chooseDropoff() async {
    await _refreshActiveJob();
    if (!mounted) return;
    final active = ref.read(jobDraftProvider).activeJob;
    if (isResumableCustomerJob(active)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).finishCurrentRequestBeforeStartingAnother,
          ),
        ),
      );
      context.push(routeForActiveCustomerJobModel(active!));
      return;
    }

    final covered = await _promptIfOutsideCoverage(force: true);
    if (!covered || !mounted) return;

    final applied = await showPickupLocationPicker(
      context: context,
      autofocusSearch: true,
      forDropoff: true,
    );
    if (!applied || !mounted) return;
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null ||
        draft.dropoffLng == null ||
        draft.dropoffAddress.trim().isEmpty) {
      return;
    }
    context.push('/service-request');
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

    final inside = await customerAreaCovered(ref, draft.pickupLat, draft.pickupLng);
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
    return draft.locationResolved && address.isNotEmpty && address != 'Locating your position…';
  }

  Future<void> _openLocationPicker() async {
    final applied = await showPickupLocationPicker(context: context, autofocusSearch: true);
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
            markers: _markers,
            onTap: _locating ? null : _onMapTap,
          ),

          // Top app bar overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _CircleButton(
                        icon: Icons.menu,
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const AppLogo(
                            size: 18,
                            variant: AppLogoVariant.wordmark,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: _CircleButton(
                        icon: Icons.notifications_outlined,
                        badge: unread == 0 ? null : unread,
                        onTap: () => context.push('/notifications'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (showActiveJobBanner && activeJob != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 68,
              left: 16,
              right: 16,
              child: ActiveJobBanner(job: activeJob),
            ),

          Positioned(
            right: 16,
            bottom: showActiveJobBanner ? 320 : 280,
            child: _CircleButton(
              icon: _locating ? Icons.hourglass_top : Icons.my_location,
              onTap: _locating ? () {} : () => _resolveLocation(),
              bgColor: AppColors.surface,
            ),
          ),

          // Bottom panel
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.2,
            maxChildSize: 0.55,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, -4))
                ],
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (final mode in const [
                          ('taxi', 'Ride', Icons.local_taxi_outlined),
                          ('bidding', 'Bid', Icons.gavel_outlined),
                          ('parcel', 'Parcel', Icons.inventory_2_outlined),
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(mode.$2),
                                avatar: Icon(mode.$3, size: 16),
                                selected: draft.jobType == mode.$1,
                                onSelected: (_) {
                                  ref.read(jobDraftProvider.notifier).state =
                                      draft.copyWith(jobType: mode.$1);
                                  ref.invalidate(serviceCategoriesProvider);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RouteField(
                      icon: Icons.trip_origin,
                      iconColor: AppColors.primary,
                      label: 'Pickup',
                      value: _hasPrecisePickup(draft)
                          ? draft.pickupAddress
                          : AppLocalizations.of(context).findingAddress,
                      trailing: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.my_location, color: AppColors.grey500, size: 18),
                      onTap: _locating ? null : _openLocationPicker,
                      onTrailingTap: _locating ? null : () => _resolveLocation(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RouteField(
                      icon: Icons.search,
                      iconColor: AppColors.navy,
                      label: 'Dropoff',
                      value: draft.dropoffAddress.trim().isEmpty
                          ? 'Where to?'
                          : draft.dropoffAddress,
                      emphasize: draft.dropoffAddress.trim().isEmpty,
                      onTap: _locating ? null : _chooseDropoff,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Provider count + verified badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _providers.length == 1
                                    ? '1 driver nearby'
                                    : '${_providers.length} drivers nearby',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(AppLocalizations.of(context).readyToHelpYou,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified,
                                  color: AppColors.success, size: 14),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      AppLocalizations.of(context)
                                          .verifiedTrusted,
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success)),
                                  Text(
                                      AppLocalizations.of(context)
                                          .backgroundChecked,
                                      style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: AppColors.success
                                              .withOpacity(0.7))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final int? badge;
  final VoidCallback onTap;
  final Color? bgColor;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.badge,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor ?? AppColors.surface.withOpacity(0.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)
              ],
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle),
                child: Text(
                  '$badge',
                  style: GoogleFonts.poppins(
                      fontSize: 10,
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

class _RouteField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool emphasize;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;

  const _RouteField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.trailing,
    this.onTap,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: emphasize ? 18 : 14,
                        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                        color: emphasize ? AppColors.textPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                GestureDetector(onTap: onTrailingTap ?? onTap, child: trailing),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

