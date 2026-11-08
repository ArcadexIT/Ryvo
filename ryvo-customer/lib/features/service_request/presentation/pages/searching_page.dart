import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/job/active_job_session.dart';
import '../../../../core/network/tracking_socket.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../payment/presentation/pages/payment_options_page.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/location/nearby_fleet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../home/presentation/widgets/map_markers.dart';
import '../../../tracking/presentation/trip_map_providers.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';

/// Pickup the customer actually requested. Job coordinates win; a zeroed job
/// falls through to the draft pin. There is no city fallback.
LatLng pickupLatLngOf(JobRequestDraft draft) {
  final job = draft.activeJob;
  final lat = job?.pickupLat ?? draft.pickupLat;
  final lng = job?.pickupLng ?? draft.pickupLng;
  if (lat.abs() < 0.0001 && lng.abs() < 0.0001) {
    return LatLng(draft.pickupLat, draft.pickupLng);
  }
  return LatLng(lat, lng);
}

/// Searching camera. Created from the live draft so the map never opens on
/// the shared trip-camera placeholder.
final searchingMapCameraProvider = StateProvider<RyvoMapCamera>((ref) {
  return RyvoMapCamera(
    target: pickupLatLngOf(ref.read(jobDraftProvider)),
    zoom: 16,
  );
});

class SearchingPage extends ConsumerStatefulWidget {
  const SearchingPage({super.key});

  @override
  ConsumerState<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends ConsumerState<SearchingPage> {
  final DrivingRouteService _routes = DrivingRouteService();
  GoogleMapController? _mapController;
  Timer? _pollTimer;
  Timer? _clock;
  Timer? _providerTimer;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Widget? _map;
  String? _socketJobId;
  late final TrackingSocket _socket;
  ProviderContainer? _container;

  bool _cancelling = false;
  int _paymentPendingHits = 0;
  int _providerGen = 0;
  static const double _pickupZoom = 16;

  /// Pickup the radar is centered on. Updated without rebuilding the map.
  late final ValueNotifier<LatLng> _radarAnchor;

  /// Sheet height, so the pickup pin sits in the open map above the HUD.
  late final ValueNotifier<EdgeInsets> _mapInsets;

  /// Last title and subtitle pushed to the sheet. The clock skips setState
  /// until this changes.
  String? _statusKey;

  bool _cameraLocked = false;

  DateTime _startedAt = DateTime.now();
  List<NearbyProvider> _providers = const [];
  List<LatLng> _routePoints = const [];
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  List<JobBidModel> _bids = const [];

  @override
  void initState() {
    super.initState();
    _socket = ref.read(trackingSocketProvider);
    _startedAt = DateTime.now();
    final pickup = pickupLatLngOf(ref.read(jobDraftProvider));
    _radarAnchor = ValueNotifier(pickup);
    _mapInsets = ValueNotifier(const EdgeInsets.only(top: 48, bottom: 340));
    final initial = _status();
    _statusKey = '${initial.title}|${initial.subtitle}';
    // The map is created on the draft pickup (see [_searchMap]). This write
    // keeps the shared camera provider on that same coordinate so a later
    // listen cannot fall back to the provider's placeholder city.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _centerOnPickup();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_socket.connected) return;
      _pollJob();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _onClock());
    _providerTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _loadProviders());
    Future.microtask(_pollJob);
    Future.microtask(_prepareMap);
  }

  Duration get _elapsed => DateTime.now().difference(_startedAt);

  void _onClock() {
    if (!mounted) return;
    final next = _status();
    final key = '${next.title}|${next.subtitle}';
    if (key == _statusKey) return;
    _statusKey = key;
    setState(() {});
  }

  Future<void> _prepareMap() async {
    final pickupIcon = await MapMarkers.buildStopNode(
      kind: MapStopKind.pickup,
    );
    if (!mounted) return;
    setState(() => _pickupIcon = pickupIcon);
    _publishScene();
    await Future.wait([_loadRoute(), _loadProviders()]);
    if (!mounted) return;
    _publishScene();
  }

  Future<void> _loadRoute() async {
    final draft = ref.read(jobDraftProvider);
    final dropoff = _dropoffOf(draft);
    if (dropoff == null) return;
    final pickup = _pickupOf(draft);
    final route = await _routes.fetch(
      originLat: pickup.latitude,
      originLng: pickup.longitude,
      destinationLat: dropoff.latitude,
      destinationLng: dropoff.longitude,
    );
    if (!mounted) return;
    final minutes = route?.durationMin ?? 0;
    final dropoffIcon = await MapMarkers.buildStopNode(
      kind: MapStopKind.dropoff,
      badge: minutes > 0 ? '$minutes min' : null,
    );
    if (!mounted) return;
    setState(() {
      _routePoints = route?.points ?? const [];
      _dropoffIcon = dropoffIcon;
    });
    _publishScene();
  }

  Future<void> _loadProviders() async {
    final gen = ++_providerGen;
    final pickup = _pickupOf(ref.read(jobDraftProvider));
    List<NearbyProvider> providers = const [];
    try {
      providers = await ref.read(jobRepositoryProvider).nearbyProviders(
            lat: pickup.latitude,
            lng: pickup.longitude,
          );
    } catch (_) {}
    providers = providers.where((p) => p.lat != null && p.lng != null).toList();
    if (!mounted || gen != _providerGen) return;
    setState(() => _providers = providers);
    // Idle cars around the pickup, drawn by the unified compact renderer.
    final fleet = await buildNearbyFleet(providers);
    if (!mounted || gen != _providerGen) return;
    ref.read(tripFleetProvider(TripMapScope.searching).notifier).state = fleet;
  }

  LatLng _pickupOf(JobRequestDraft draft) => pickupLatLngOf(draft);

  LatLng? _dropoffOf(JobRequestDraft draft) {
    final job = draft.activeJob;
    final lat = job?.dropoffLat ?? draft.dropoffLat;
    final lng = job?.dropoffLng ?? draft.dropoffLng;
    if (lat == null || lng == null) return null;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return null;
    return LatLng(lat, lng);
  }

  NearbyProvider? get _contacted {
    if (_providers.isEmpty || _elapsed.inSeconds < 7) return null;
    final index = (_elapsed.inSeconds ~/ 4) % _providers.length;
    return _providers[index];
  }

  /// Street-level lock on the requested pickup. [GoogleMap.padding] shifts
  /// this target into the band above the sheet, and the radar follows it.
  Future<void> _centerOnPickup({bool animate = false}) async {
    final pickup = _pickupOf(ref.read(jobDraftProvider));
    if (_radarAnchor.value != pickup) _radarAnchor.value = pickup;
    ref.read(searchingMapCameraProvider.notifier).state =
        RyvoMapCamera(target: pickup, zoom: _pickupZoom);
    final controller = _mapController;
    if (_cameraLocked || controller == null || !mounted) return;
    final update = CameraUpdate.newLatLngZoom(pickup, _pickupZoom);
    try {
      if (animate) {
        await controller.animateCamera(update);
      } else {
        await controller.moveCamera(update);
      }
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _cameraLocked = true;
  }

  /// A stop is added only after its bitmap exists, so no stock pin shows.
  Set<Marker> _markers(LatLng pickup, LatLng? dropoff) {
    final pickupIcon = _pickupIcon;
    final dropoffIcon = _dropoffIcon;
    return {
      if (pickupIcon != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: pickupIcon,
          anchor: MapMarkers.stopAnchor,
          zIndexInt: 3,
        ),
      if (dropoff != null && dropoffIcon != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: dropoffIcon,
          anchor: MapMarkers.stopAnchor,
          zIndexInt: 2,
        ),
    };
  }

  Set<Polyline> _polylines(LatLng pickup, LatLng? dropoff) {
    if (dropoff == null) return {};
    final points = _routePoints.length > 1 ? _routePoints : [pickup, dropoff];
    return {
      Polyline(
        polylineId: const PolylineId('route-casing'),
        points: points,
        color: AppColors.white,
        width: 10,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppColors.primary,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
      ),
    };
  }

  _SearchStatus _status() {
    final seconds = _elapsed.inSeconds;
    final count = _providers.length;
    final driver = _contacted;
    final first = _firstName(driver?.fullName);
    final detail = _driverDetail(driver);
    if (seconds < 7) {
      return _SearchStatus(
        title: 'Contacting driver...',
        subtitle: count == 0
            ? 'Scanning around your pickup'
            : count == 1
                ? '1 driver is nearby'
                : '$count drivers are nearby',
      );
    }
    if (seconds < 18) {
      return _SearchStatus(
        title: first == null ? 'Contacting driver...' : 'Contacting $first',
        subtitle: detail ?? 'Your request is going out now',
      );
    }
    if (seconds < 34) {
      return _SearchStatus(
        title: 'Waiting for a driver to accept',
        subtitle: detail ?? 'Nearby drivers can see your offer',
      );
    }
    if (seconds < 52) {
      return _SearchStatus(
        title: 'Expanding the search',
        subtitle: detail ?? 'Looking a little further out',
      );
    }
    return _SearchStatus(
      title: 'Still looking for a driver',
      subtitle: detail ?? 'Hang tight — someone should accept soon',
    );
  }

  String? _firstName(String? fullName) {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty || name.toLowerCase() == 'driver') return null;
    return name.split(RegExp(r'\s+')).first;
  }

  String? _driverDetail(NearbyProvider? driver) {
    if (driver == null) return null;
    final parts = <String>[
      if (driver.etaMinutes != null) '${driver.etaMinutes} min away',
      if (driver.distanceKm != null)
        '${driver.distanceKm!.toStringAsFixed(1)} km',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  void _publishScene() {
    final draft = ref.read(jobDraftProvider);
    final pickup = _pickupOf(draft);
    final dropoff = _dropoffOf(draft);
    ref.read(tripMarkersProvider(TripMapScope.searching).notifier).state =
        _markers(pickup, dropoff);
    ref.read(tripPolylinesProvider(TripMapScope.searching).notifier).state =
        _polylines(pickup, dropoff);
  }

  Widget _searchMap() {
    return _map ??= RyvoMapCanvas(
      markers: tripMarkersProvider(TripMapScope.searching),
      polylines: tripPolylinesProvider(TripMapScope.searching),
      fleet: tripFleetProvider(TripMapScope.searching),
      camera: searchingMapCameraProvider,
      radarAnchor: _radarAnchor,
      initialTarget: _radarAnchor.value,
      initialZoom: _pickupZoom,
      padding: _mapInsets.value,
      paddingListenable: _mapInsets,
      onMapCreated: (controller) {
        _mapController = controller;
        _centerOnPickup();
      },
    );
  }

  Future<void> _ensureSocket(String jobId) async {
    if (_socketJobId == jobId) return;
    _socketJobId = jobId;
    final socket = ref.read(trackingSocketProvider);
    await socket.connect();
    if (!mounted || _socketJobId != jobId) return;
    socket.subscribeJob(jobId);
    await _statusSub?.cancel();
    _statusSub = socket.onStatus.listen((_) {
      if (!mounted) return;
      _pollJob();
    });
  }

  Future<void> _pollJob() async {
    if (!mounted) return;
    final job = ref.read(jobDraftProvider).activeJob;
    if (job == null) return;
    _ensureSocket(job.id);

    try {
      final updated = await ref.read(jobRepositoryProvider).getJob(job.id);
      if (!mounted) return;
      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(activeJob: updated);

      if (updated.status == 'matched' ||
          updated.status == 'provider_en_route' ||
          updated.status == 'arrived' ||
          updated.status == 'in_progress') {
        _pollTimer?.cancel();
        context.pushReplacement(routeForActiveCustomerJob(updated.status));
      } else if (updated.status == 'payment_pending') {
        _paymentPendingHits += 1;
        if (_paymentPendingHits >= 2) {
          _pollTimer?.cancel();
          if (!mounted) return;
          final route = await showRyvoCheckout(context);
          if (!mounted) return;
          if (route != null) {
            context.go(route);
          } else if (ref.read(jobDraftProvider).activeJob == null) {
            context.go('/home');
          }
        }
      } else if (updated.status == 'no_provider_found') {
        _pollTimer?.cancel();
        if (!mounted) return;
        await _showNoProviderFoundDialog(job.id);
      } else if (updated.status.startsWith('cancelled')) {
        _pollTimer?.cancel();
        showApiError(context, formatJobStatus(updated.status));
        markJobSessionFinished(
          ProviderScope.containerOf(context, listen: false),
          jobId: job.id,
        );
        context.go('/home');
      } else {
        _paymentPendingHits = 0;
        if (updated.jobType == 'bidding' && updated.status == 'searching') {
          final bids =
              await ref.read(jobRepositoryProvider).listBids(updated.id);
          if (mounted) setState(() => _bids = bids);
        }
      }
    } catch (_) {}
  }

  Future<void> _showNoProviderFoundDialog(String jobId) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_outlined,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.noProvidersAvailable,
                style: RyvoTypography.heading(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.thereAreNoProvidersAvailableNearbyRightNowPlease,
          style: RyvoTypography.style(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10n.backToHome,
              style: RyvoTypography.button(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    markJobSessionFinished(
      ProviderScope.containerOf(context, listen: false),
      jobId: jobId,
    );
    context.go('/home');
  }

  Future<void> _cancel() async {
    final job = ref.read(jobDraftProvider).activeJob;
    if (job == null) return;
    setState(() => _cancelling = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .cancelJob(job.id, reason: 'Cancelled by customer');
      ref.invalidate(jobsListProvider);
      if (!mounted) return;
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: job.id,
      );
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _radarAnchor.dispose();
    _mapInsets.dispose();
    _pollTimer?.cancel();
    _clock?.cancel();
    _providerTimer?.cancel();
    _statusSub?.cancel();
    _releaseSocketRoom();
    super.dispose();
  }

  /// The fade-out runs after [LiveTrackingPage] has joined this same job.
  /// Leaving the room here dropped every later status event.
  ///
  /// The container is captured while this page is mounted. [WidgetRef.read]
  /// throws once the element is defunct, which is already true in [dispose].
  void _releaseSocketRoom() {
    final jobId = _socketJobId;
    if (jobId == null) return;
    final activeId = _container?.read(jobDraftProvider).activeJob?.id;
    if (activeId == jobId) return;
    _socket.unsubscribeJob(jobId);
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<JobRequestDraft>(jobDraftProvider, (previous, next) {
      if (previous != null &&
          _samePoint(_pickupOf(previous), _pickupOf(next))) {
        return;
      }
      _cameraLocked = false;
      _centerOnPickup(animate: true);
    });
    final view = ref.watch(jobDraftProvider.select(_sheetView));
    final status = _status();
    final serviceName = view.serviceName.isEmpty
        ? AppLocalizations.of(context).service
        : view.serviceName;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            _searchMap(),
            Align(
              alignment: Alignment.bottomCenter,
              child: _SheetExtent(
                insets: _mapInsets,
                child: _SearchSheet(
                  status: status,
                  serviceName: serviceName,
                  fare: formatMoney(view.fare),
                  pickupAddress: view.pickupAddress,
                  dropoffAddress: view.dropoffAddress,
                  cancelling: _cancelling,
                  onCancel: _cancelling ? null : _cancel,
                  bids: _bids,
                  onAcceptBid: (bid) async {
                    final job = ref.read(jobDraftProvider).activeJob;
                    if (job == null) return;
                    try {
                      final updated = await ref
                          .read(jobRepositoryProvider)
                          .acceptBid(job.id, bid.id);
                      if (!mounted || !context.mounted) return;
                      ref.read(jobDraftProvider.notifier).state = ref
                          .read(jobDraftProvider)
                          .copyWith(activeJob: updated);
                      context.pushReplacement(
                          routeForActiveCustomerJob(updated.status));
                    } catch (e) {
                      if (mounted && context.mounted) showApiError(context, e);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _SheetView = ({
  String serviceName,
  String pickupAddress,
  String dropoffAddress,
  double fare,
});

_SheetView _sheetView(JobRequestDraft draft) {
  final job = draft.activeJob;
  final pickup = (job?.pickupAddress.trim().isNotEmpty ?? false)
      ? job!.pickupAddress
      : draft.pickupAddress;
  final dropoff = (job?.dropoffAddress?.trim().isNotEmpty ?? false)
      ? job!.dropoffAddress!
      : draft.dropoffAddress;
  return (
    serviceName:
        draft.serviceCategory?.name ?? job?.serviceCategory?.name ?? '',
    pickupAddress: pickup,
    dropoffAddress: dropoff,
    fare: job?.displayFare ?? draft.estimate?.estimatedFare ?? 0,
  );
}

class _SearchStatus {
  const _SearchStatus({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class _SearchSheet extends StatelessWidget {
  const _SearchSheet({
    required this.status,
    required this.serviceName,
    required this.fare,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.cancelling,
    required this.onCancel,
    this.bids = const [],
    this.onAcceptBid,
  });

  final _SearchStatus status;
  final String serviceName;
  final String fare;
  final String pickupAddress;
  final String dropoffAddress;
  final bool cancelling;
  final VoidCallback? onCancel;
  final List<JobBidModel> bids;
  final Future<void> Function(JobBidModel bid)? onAcceptBid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _DragHandle()),
                  const SizedBox(height: 16),
                  Text(
                    status.title,
                    style: RyvoTypography.heading(
                      fontSize: 24,
                      letterSpacing: -0.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.subtitle,
                    style: RyvoTypography.style(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.textSecondary,
                      tabular: true,
                    ),
                  ),
                  if (bids.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Driver offers',
                      style: RyvoTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    for (final bid in bids.take(4))
                      _BidRow(
                        bid: bid,
                        onAccept: onAcceptBid == null
                            ? null
                            : () => onAcceptBid!(bid),
                      ),
                  ],
                  const SizedBox(height: 20),
                  _VehicleRow(name: serviceName, fare: fare),
                  const SizedBox(height: 16),
                  _CompactRoute(
                    pickup: _streetName(pickupAddress),
                    dropoff: _streetName(dropoffAddress),
                  ),
                  const SizedBox(height: 16),
                  _MutedCancelButton(
                    label: cancelling ? l10n.cancelling : l10n.cancelRequest,
                    onPressed: onCancel,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _EdgeProgress(),
          ),
        ],
      ),
    );
  }
}

/// Publishes the sheet's laid-out height as map padding so the pickup pin
/// stays in the open map above the HUD.
class _SheetExtent extends StatefulWidget {
  const _SheetExtent({required this.insets, required this.child});

  final ValueNotifier<EdgeInsets> insets;
  final Widget child;

  @override
  State<_SheetExtent> createState() => _SheetExtentState();
}

class _SheetExtentState extends State<_SheetExtent> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
    return widget.child;
  }

  void _publish() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = MediaQuery.paddingOf(context).top + 12;
    final next = EdgeInsets.only(top: top, bottom: box.size.height);
    if (widget.insets.value == next) return;
    widget.insets.value = next;
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}

class _EdgeProgress extends StatelessWidget {
  const _EdgeProgress();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Searching for a driver',
      child: SizedBox(
        height: 2,
        width: double.infinity,
        child: LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: AppColors.divider,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.name, required this.fare});

  final String name;
  final String fare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.directions_car_filled,
          size: 22,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RyvoTypography.style(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          fare,
          style: RyvoTypography.price(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BidRow extends StatelessWidget {
  const _BidRow({required this.bid, required this.onAccept});

  final JobBidModel bid;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid.providerName ?? 'Driver',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  bid.kind == 'counter'
                      ? 'Counter offer'
                      : 'Accepted your price',
                  style: RyvoTypography.style(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAccept,
            child: Text(
              formatMoney(bid.amount),
              style: RyvoTypography.price(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// First comma-separated segment: the street, without the city and region.
String _streetName(String address) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) return trimmed;
  final first = trimmed.split(',').first.trim();
  return first.isEmpty ? trimmed : first;
}

class _CompactRoute extends StatelessWidget {
  const _CompactRoute({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  static const double rowHeight = 22;
  static const double gap = 12;
  static const double node = 8;
  static const double contentHeight = rowHeight * 2 + gap;
  static const double nodeInset = (rowHeight - node) / 2;
  static const double lineInset = nodeInset + node;

  @override
  Widget build(BuildContext context) {
    final square = AppColors.isDark ? AppColors.white : AppColors.obsidian;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: nodeInset),
                const _TimelineNode(color: AppColors.primary, circle: true),
                SizedBox(
                  height: contentHeight - lineInset * 2,
                  width: 1.5,
                  child: ColoredBox(color: AppColors.divider),
                ),
                _TimelineNode(color: square, circle: false),
                const SizedBox(height: nodeInset),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteLine(text: pickup.isEmpty ? 'Pickup' : pickup),
                const SizedBox(height: gap),
                _RouteLine(text: dropoff.isEmpty ? 'Dropoff' : dropoff),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _CompactRoute.rowHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: RyvoTypography.style(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.color, required this.circle});

  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _CompactRoute.node,
      height: _CompactRoute.node,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

class _MutedCancelButton extends StatelessWidget {
  const _MutedCancelButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? AppColors.dangerText
        : AppColors.dangerText.withValues(alpha: 0.4);
    return RyvoPressScale(
      enabled: enabled,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: RyvoTypography.button(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

