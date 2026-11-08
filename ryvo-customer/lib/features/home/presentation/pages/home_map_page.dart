import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/job/resume_customer_job.dart';
import '../../../../core/location/nearby_fleet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../home_map_providers.dart';
import '../widgets/active_job_banner.dart';
import '../widgets/ryvo_spatial_drawer.dart';
import '../widgets/ryvo_spatial_menu.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class HomeMapPage extends ConsumerStatefulWidget {
  const HomeMapPage({super.key});

  @override
  ConsumerState<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends ConsumerState<HomeMapPage>
    with WidgetsBindingObserver {
  final GlobalKey<RyvoSpatialDrawerControllerState> _drawerKey =
      GlobalKey<RyvoSpatialDrawerControllerState>();
  final ValueNotifier<EdgeInsets> _mapPadding =
      ValueNotifier(const EdgeInsets.only(top: 120));
  GoogleMapController? _mapController;
  GoRouter? _router;
  String? _lastHomeRefreshPath;

  bool _pickupPinnedManually = false;
  int _pickupRequest = 0;
  int _cameraGeneration = 0;
  String? _coveragePromptKey;
  int _coverageRequest = 0;

  LatLng get _pickup {
    final draft = ref.read(jobDraftProvider);
    return LatLng(draft.pickupLat, draft.pickupLng);
  }

  bool get _locating => ref.read(homeMapLocatingProvider);

  void _setLocating(bool value) {
    ref.read(homeMapLocatingProvider.notifier).state = value;
  }

  void _requestCamera(LatLng target, double zoom) {
    ref.read(homeMapCameraProvider.notifier).state = RyvoMapCamera(
      target: target,
      zoom: zoom,
      generation: ++_cameraGeneration,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Provider writes are illegal during initState. The map reads the camera
    // on the next frame, then recenters onto the saved pickup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final draft = ref.read(jobDraftProvider);
      _requestCamera(LatLng(draft.pickupLat, draft.pickupLng), 14.5);
      ref.invalidate(serviceCategoriesProvider);
      _init();
    });
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
    _mapPadding.dispose();
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
    if (!isContextActive(context) || !ref.read(isAuthenticatedProvider)) {
      return;
    }
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

  Future<void> _selectRecentDestination(_RecentPlace place) async {
    if (!await _guardNewRequest()) return;
    final covered = await _promptIfOutsideCoverage(force: true);
    if (!covered || !mounted) return;
    final draft = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state = draft.copyWith(
      dropoffAddress: place.address,
      dropoffLat: place.lat,
      dropoffLng: place.lng,
    );
    if (!mounted) return;
    context.push('/service-request');
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
      if (!applied || !mounted || !_hasDropoff(ref.read(jobDraftProvider))) {
        return;
      }
    }
    if (!mounted) return;
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
    _setLocating(false);
    await _refreshActiveJob();
    if (!mounted) return;
    // Always take a fresh GPS fix on home open so a previous launch
    // address is never reused as the current pickup.
    await _resolveLocation(silent: true, recenter: true);
    await _loadNearbyProviders();
  }

  Future<void> _resolveLocation(
      {bool silent = false, bool recenter = true}) async {
    if (_locating) return;
    final request = ++_pickupRequest;
    _setLocating(true);
    final error = await refreshPickupLocation(ref);
    if (!mounted || request != _pickupRequest) return;
    _setLocating(false);

    if (error != null) {
      if (!silent) _showLocationError(error);
      return;
    }

    _pickupPinnedManually = false;
    if (recenter) _requestCamera(_pickup, 15);
    await _loadNearbyProviders();
    await _promptIfOutsideCoverage();
  }

  Future<void> _openLocationPicker() async {
    final applied =
        await showPickupLocationPicker(context: context, autofocusSearch: true);
    if (!applied || !mounted) return;
    ref.read(pickupEditGenerationProvider.notifier).state++;
    _pickupRequest++;
    _pickupPinnedManually = true;
    if (_locating) _setLocating(false);
    _requestCamera(_pickup, 16);
    await _loadNearbyProviders();
    await _promptIfOutsideCoverage();
  }

  void _onMapTap(LatLng position) {
    if (_locating) return;
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
    _setLocating(true);
    if (recenter) _requestCamera(position, 16);
    await applyPickupCoordinates(ref, position.latitude, position.longitude);
    if (!mounted || request != _pickupRequest) return;
    _setLocating(false);
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
    // Compact car icons only: no ETA bubble on the idle map. Icons are cached
    // by the renderer, so a refresh only moves the cars.
    final fleet = await buildNearbyFleet(providers);
    if (!mounted || request != _pickupRequest) return;
    ref.read(homeMapFleetProvider.notifier).state = fleet;
  }

  void _onSheetExtent(double size) {
    final height = MediaQuery.sizeOf(context).height;
    final capped = size > 0.56 ? 0.56 : size;
    final bottom = height * capped;
    if ((_mapPadding.value.bottom - bottom).abs() < 0.5) return;
    _mapPadding.value = EdgeInsets.only(top: 120, bottom: bottom);
  }

  @override
  Widget build(BuildContext context) {
    return RyvoSpatialDrawerController(
      key: _drawerKey,
      drawer: RyvoSpatialMenu(
        onSearch: _editDropoff,
        onNewRide: () async {},
        onRecentRide: (address, lat, lng) {
          return _selectRecentDestination(
            _RecentPlace(
              title: _shortPlace(address),
              subtitle: '',
              address: address,
              lat: lat,
              lng: lng,
            ),
          );
        },
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            RyvoMapCanvas(
              markers: homeMapMarkersProvider,
              fleet: homeMapFleetProvider,
              polylines: homeMapPolylinesProvider,
              camera: homeMapCameraProvider,
              showLiveLocation: true,
              padding: const EdgeInsets.only(top: 120),
              paddingListenable: _mapPadding,
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTap,
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _HomeTopBar(
                  onProfileTap: () => _drawerKey.currentState?.open(),
                  onNotificationsTap: () => context.push('/notifications'),
                  onPickupTap: _openLocationPicker,
                  onLocate: () => _resolveLocation(),
                ),
              ),
            ),
            Positioned.fill(
              child: _HomeBottomOverlay(
                onSheetExtent: _onSheetExtent,
                onLocate: () => _resolveLocation(),
                onZoomIn: () =>
                    _mapController?.animateCamera(CameraUpdate.zoomIn()),
                onZoomOut: () =>
                    _mapController?.animateCamera(CameraUpdate.zoomOut()),
                onFindRide: _findRide,
                onSearch: _editDropoff,
                onRecentPlace: _selectRecentDestination,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortPlace(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return trimmed;
  final first = trimmed.split(',').first.trim();
  return first.isEmpty ? trimmed : first;
}

bool _hasPrecisePickup(String address, bool locationResolved) {
  final trimmed = address.trim();
  return locationResolved &&
      trimmed.isNotEmpty &&
      trimmed != 'Locating your position…';
}

String _ctaLabel(String jobType) => switch (jobType) {
      'bidding' => 'Find Drivers',
      'parcel' => 'Send Parcel',
      _ => 'Request Ride',
    };

String _searchPrompt(String jobType) => switch (jobType) {
      'bidding' => 'Where to? (Set your fare)',
      'parcel' => 'Deliver parcel to?',
      _ => 'Where to?',
    };

class _RecentPlace {
  const _RecentPlace({
    required this.title,
    required this.subtitle,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String title;
  final String subtitle;
  final String address;
  final double lat;
  final double lng;
}

List<_RecentPlace> _recentPlaces(List<JobModel> jobs) {
  final ordered = [...jobs]..sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  final seen = <String>{};
  final places = <_RecentPlace>[];
  for (final job in ordered) {
    final address = job.dropoffAddress?.trim() ?? '';
    final lat = job.dropoffLat;
    final lng = job.dropoffLng;
    if (address.isEmpty || lat == null || lng == null) continue;
    if (job.status == 'cancelled' || job.status.startsWith('cancelled')) {
      continue;
    }
    final key = address.toLowerCase();
    if (!seen.add(key)) continue;
    final parts = address.split(',');
    final title = parts.first.trim();
    final rest = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    places.add(
      _RecentPlace(
        title: title.isEmpty ? address : title,
        subtitle: rest.isEmpty ? 'Recent' : rest,
        address: address,
        lat: lat,
        lng: lng,
      ),
    );
    if (places.length == 3) break;
  }
  return places;
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar({
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onPickupTap,
    required this.onLocate,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onPickupTap;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final fullName = profile?.fullName.trim() ?? '';
    final unread = ref.watch(notificationsProvider.select((async) {
      final items = async.valueOrNull;
      if (items == null) return 0;
      var count = 0;
      for (final item in items) {
        if (!item.isRead) count++;
      }
      return count;
    }));
    final pickupAddress = ref.watch(
      jobDraftProvider.select((draft) => draft.pickupAddress),
    );
    final locationResolved = ref.watch(
      jobDraftProvider.select((draft) => draft.locationResolved),
    );
    final locating = ref.watch(homeMapLocatingProvider);
    final activeJob = ref.watch(
      jobDraftProvider.select((draft) => draft.activeJob),
    );
    final l10n = AppLocalizations.of(context);
    final pickup = _hasPrecisePickup(pickupAddress, locationResolved)
        ? _shortPlace(pickupAddress)
        : l10n.findingAddress;
    final showActiveJob = isResumableCustomerJob(activeJob);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _CircleAction(
              onTap: onProfileTap,
              child: _ProfileFace(
                initials: fullName.isEmpty ? null : profile?.initials,
                avatarUrl: profile?.avatarUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickupPill(
                label: pickup,
                locating: locating,
                onTap: locating ? null : onPickupTap,
                onLocate: locating ? null : onLocate,
              ),
            ),
            const SizedBox(width: 10),
            _CircleAction(
              onTap: onNotificationsTap,
              badge: unread == 0 ? null : unread,
              child: Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ],
        ),
        if (showActiveJob && activeJob != null) ...[
          const SizedBox(height: 10),
          ActiveJobBanner(job: activeJob),
        ],
      ],
    );
  }
}

class _HomeBottomOverlay extends ConsumerStatefulWidget {
  const _HomeBottomOverlay({
    required this.onSheetExtent,
    required this.onLocate,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFindRide,
    required this.onSearch,
    required this.onRecentPlace,
  });

  final ValueChanged<double> onSheetExtent;
  final VoidCallback onLocate;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFindRide;
  final VoidCallback onSearch;
  final ValueChanged<_RecentPlace> onRecentPlace;

  @override
  ConsumerState<_HomeBottomOverlay> createState() => _HomeBottomOverlayState();
}

class _HomeBottomOverlayState extends ConsumerState<_HomeBottomOverlay> {
  static const _detents = <double>[0.42, 0.56, 0.88];

  final DraggableScrollableController _sheet = DraggableScrollableController();
  final ValueNotifier<double> _extent = ValueNotifier(0.42);
  double? _detent;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onSheetExtent();
    });
  }

  void _onSheetExtent() {
    if (!isContextActive(context) || !_sheet.isAttached) return;
    final size = _sheet.size;
    if ((_extent.value - size).abs() >= 0.001) {
      _extent.value = size;
    }
    widget.onSheetExtent(size);
    double? nearest;
    for (final detent in _detents) {
      if ((size - detent).abs() < 0.012) nearest = detent;
    }
    if (nearest != null && nearest != _detent) {
      final arrived = _detent != null;
      _detent = nearest;
      if (arrived) HapticFeedback.selectionClick();
    }
  }

  void _revealRequest() {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      0.56,
      duration: const Duration(milliseconds: 280),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSheetExtent);
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }

  void _selectMode(String mode) {
    final draft = ref.read(jobDraftProvider);
    if (draft.jobType == mode) return;
    HapticFeedback.selectionClick();
    ref.read(jobDraftProvider.notifier).state = draft.copyWith(jobType: mode);
    ref.invalidate(serviceCategoriesProvider);
  }

  double _controlsBottom(
    BuildContext context,
    BoxConstraints constraints,
    double extent,
  ) {
    const controlsHeight = 36.0 * 3 + 16;
    final safeTop = MediaQuery.paddingOf(context).top + 72;
    final limit = constraints.maxHeight - safeTop - controlsHeight;
    final capped = extent > 0.56 ? 0.56 : extent;
    final desired = constraints.maxHeight * capped + 12;
    if (limit < 12) return 12;
    return desired.clamp(12.0, limit);
  }

  @override
  Widget build(BuildContext context) {
    final jobType =
        ref.watch(jobDraftProvider.select((draft) => draft.jobType));
    final locating = ref.watch(homeMapLocatingProvider);
    final hasDropoff = ref.watch(
      jobDraftProvider.select(
        (draft) =>
            draft.dropoffLat != null &&
            draft.dropoffLng != null &&
            draft.dropoffAddress.trim().isNotEmpty,
      ),
    );
    ref.listen<bool>(
      jobDraftProvider.select(
        (draft) =>
            draft.dropoffLat != null &&
            draft.dropoffLng != null &&
            draft.dropoffAddress.trim().isNotEmpty,
      ),
      (previous, next) {
        if (next && previous != true) _revealRequest();
      },
    );
    ref.listen<String>(
      jobDraftProvider.select((draft) => draft.jobType),
      (previous, next) {
        if (previous != null && previous != next) _revealRequest();
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: 0.42,
              minChildSize: 0.42,
              maxChildSize: 0.88,
              snap: true,
              snapSizes: _detents,
              snapAnimationDuration: const Duration(milliseconds: 260),
              builder: (context, scrollController) {
                return _HomeRequestSheet(
                  scrollController: scrollController,
                  jobType: jobType,
                  hasDropoff: hasDropoff,
                  ctaLabel: _ctaLabel(jobType),
                  onModeSelected: _selectMode,
                  onSearch: locating
                      ? null
                      : () {
                          if (hasDropoff) {
                            widget.onSearch();
                          } else {
                            widget.onFindRide();
                          }
                        },
                  onFindRide: locating ? null : widget.onFindRide,
                  onRecentPlace: locating ? null : widget.onRecentPlace,
                );
              },
            ),
            ValueListenableBuilder<double>(
              valueListenable: _extent,
              builder: (context, extent, child) {
                return Positioned(
                  right: 16,
                  bottom: _controlsBottom(context, constraints, extent),
                  child: child!,
                );
              },
              child: _MapControls(
                locating: locating,
                onLocate: locating ? null : widget.onLocate,
                onZoomIn: widget.onZoomIn,
                onZoomOut: widget.onZoomOut,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.onTap,
    required this.child,
    this.badge,
  });

  final VoidCallback onTap;
  final Widget child;
  final int? badge;

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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.modal,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.obsidian.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: _CountBadge(count: badge!),
            ),
        ],
      ),
    );
  }
}

class _ProfileFace extends StatelessWidget {
  const _ProfileFace({this.initials, this.avatarUrl});

  final String? initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final letter = (initials == null || initials!.isEmpty || initials == '?')
        ? null
        : initials;
    final fallback = ColoredBox(
      color: AppColors.obsidian,
      child: Center(
        child: letter == null
            ? const Icon(Icons.person_rounded, size: 20, color: AppColors.white)
            : Text(
                letter,
                style: RyvoTypography.heading(
                  fontSize: 13,
                  color: AppColors.white,
                  letterSpacing: -0.4,
                ),
              ),
      ),
    );
    return SizedBox.expand(
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _PickupPill extends StatelessWidget {
  const _PickupPill({
    required this.label,
    required this.locating,
    required this.onTap,
    required this.onLocate,
  });

  final String label;
  final bool locating;
  final VoidCallback? onTap;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.modal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RyvoTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onLocate,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 44,
                child: Center(
                  child: locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          Icons.my_location_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 4),
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.modal, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: RyvoTypography.style(
          fontSize: 9,
          height: 1,
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
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
                  color: AppColors.obsidian.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(icon, color: AppColors.textPrimary, size: 18),
          ),
        ],
      ),
    );
  }
}

class _HomeRequestSheet extends ConsumerWidget {
  const _HomeRequestSheet({
    required this.scrollController,
    required this.jobType,
    required this.hasDropoff,
    required this.ctaLabel,
    required this.onModeSelected,
    required this.onSearch,
    required this.onFindRide,
    required this.onRecentPlace,
  });

  final ScrollController scrollController;
  final String jobType;
  final bool hasDropoff;
  final String ctaLabel;
  final ValueChanged<String> onModeSelected;
  final VoidCallback? onSearch;
  final VoidCallback? onFindRide;
  final ValueChanged<_RecentPlace>? onRecentPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsListProvider);
    final places = _recentPlaces(jobsAsync.valueOrNull ?? const <JobModel>[]);
    final loading = jobsAsync.isLoading && places.isEmpty;
    final prompt = _searchPrompt(jobType);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: AppColors.modal,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    const Center(child: _SheetHandle()),
                    const SizedBox(height: 14),
                    _TripModeSelector(
                      jobType: jobType,
                      onSelected: onModeSelected,
                    ),
                    const SizedBox(height: 16),
                    _WhereToPill(
                      prompt: prompt,
                      onTap: onSearch,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Recent',
                      style: RyvoTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (loading)
                      const _RecentPlaceholder()
                    else if (places.isEmpty)
                      _DestinationRow(
                        icon: Icons.history_rounded,
                        title: 'No recent places',
                        subtitle: 'Search for a destination',
                        onTap: onSearch,
                      )
                    else
                      for (final place in places)
                        _DestinationRow(
                          icon: Icons.history_rounded,
                          title: place.title,
                          subtitle: place.subtitle,
                          onTap: onRecentPlace == null
                              ? null
                              : () => onRecentPlace!(place),
                        ),
                  ],
                ),
              ),
              if (hasDropoff)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _FindRideButton(label: ctaLabel, onTap: onFindRide),
                ),
              SizedBox(height: kFloatingNavClearance(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _TripModeSelector extends StatelessWidget {
  const _TripModeSelector({
    required this.jobType,
    required this.onSelected,
  });

  final String jobType;
  final ValueChanged<String> onSelected;

  static const _modes = <({String id, String label, IconData icon})>[
    (id: 'taxi', label: 'Ride', icon: Icons.directions_car_filled_rounded),
    (id: 'bidding', label: 'Bid', icon: Icons.sell_rounded),
    (id: 'parcel', label: 'Parcel', icon: Icons.inventory_2_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _modes.indexWhere((mode) => mode.id == jobType);
    final index = selected < 0 ? 0 : selected;
    final pill = AppColors.isDark ? AppColors.white : AppColors.modal;
    final selectedColor =
        AppColors.isDark ? AppColors.obsidian : AppColors.textPrimary;

    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / _modes.length;
              final alignX = switch (index) {
                0 => -1.0,
                1 => 0.0,
                _ => 1.0,
              };
              return Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment(alignX, 0),
                    child: SizedBox(
                      width: segmentWidth,
                      height: constraints.maxHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: pill,
                          borderRadius: BorderRadius.circular(19),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.obsidian.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final mode in _modes)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelected(mode.id),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  mode.icon,
                                  size: 16,
                                  color: mode.id == jobType
                                      ? selectedColor
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  mode.label,
                                  style: RyvoTypography.style(
                                    fontSize: 13,
                                    height: 1,
                                    fontWeight: mode.id == jobType
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: mode.id == jobType
                                        ? selectedColor
                                        : AppColors.textSecondary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WhereToPill extends StatelessWidget {
  const _WhereToPill({
    required this.prompt,
    required this.onTap,
  });

  final String prompt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.search_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RollingSwitcher(
                  value: prompt,
                  child: Text(
                    prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RyvoTypography.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RollingSwitcher extends StatelessWidget {
  const _RollingSwitcher({required this.value, required this.child});

  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              ...previous,
              if (current != null) current,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final reverse = animation.status == AnimationStatus.reverse;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: reverse ? const Offset(0, -0.45) : const Offset(0, 0.45),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey<String>(value), child: child),
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RyvoTypography.style(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RyvoTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlaceholder extends StatelessWidget {
  const _RecentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.shimmerBase,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 96,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.shimmerBase,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FindRideButton extends StatelessWidget {
  const _FindRideButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppColors.cta : AppColors.cta.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: RyvoTypography.button(
                fontSize: 16,
                color: AppColors.onCta,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
