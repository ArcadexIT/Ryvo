import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/location/trip_markers.dart';
import '../../../../core/network/tracking_socket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/job_elapsed.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../../data/models/models.dart';
import '../trip_map_providers.dart';
import '../widgets/driver_trip_card.dart';
import '../widgets/share_trip_button.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class InProgressPage extends ConsumerStatefulWidget {
  const InProgressPage({super.key});

  @override
  ConsumerState<InProgressPage> createState() => _InProgressPageState();
}

class _InProgressPageState extends ConsumerState<InProgressPage> {
  final DrivingRouteService _routes = DrivingRouteService();
  Timer? _ticker;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  StreamSubscription<JobLocation>? _locSub;
  String? _jobId;
  LatLng? _driverPos;
  List<LatLng> _routePoints = const [];
  String? _routeKey;
  TripMarkerSet? _markers;
  int? _routeMinutes;
  Widget? _map;
  int _cameraGeneration = 0;

  @override
  void initState() {
    super.initState();
    final job = ref.read(jobDraftProvider).activeJob;
    _jobId = job?.id;
    _seedDriver(job);
    _publishDriver();
    final camera =
        _dropoffOf(job) ?? _pickupOf(job) ?? const LatLng(52.48, -1.89);
    ref.read(tripCameraProvider(TripMapScope.progress).notifier).state =
        RyvoMapCamera(target: camera, zoom: 14);
    _loadMarkers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (ref.read(trackingSocketProvider).connected) return;
      _refreshJob();
    });
    Future.microtask(() async {
      final status = ref.read(jobDraftProvider).activeJob?.status;
      if (status != null) _handleStatus(status);
      if (!mounted) return;
      await _refreshJob();
      await _connectTracking();
      _loadRoute();
    });
  }

  Future<void> _loadMarkers() async {
    final set = await TripMarkers.load();
    if (!mounted) return;
    _markers = set;
    _publishDriver();
    _publishStaticMarkers();
  }

  void _seedDriver(JobModel? job) {
    final lat = job?.provider?.currentLat;
    final lng = job?.provider?.currentLng;
    if (lat == null || lng == null) return;
    _driverPos = LatLng(lat, lng);
  }

  LatLng? _dropoffOf(JobModel? job) {
    final draft = ref.read(jobDraftProvider);
    final lat = job?.dropoffLat ?? draft.dropoffLat;
    final lng = job?.dropoffLng ?? draft.dropoffLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _pickupOf(JobModel? job) {
    final lat = job?.pickupLat;
    final lng = job?.pickupLng;
    if (lat == null || lng == null) return null;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return null;
    return LatLng(lat, lng);
  }

  Future<void> _connectTracking() async {
    if (_jobId == null) return;
    final socket = ref.read(trackingSocketProvider);
    await socket.connect();
    socket.subscribeJob(_jobId!);
    _statusSub = socket.onStatus.listen((data) {
      if (!mounted) return;
      final status = data['status'] as String?;
      if (status != null) _refreshJob();
    });
    _locSub = socket.onLocation.listen((loc) {
      if (!mounted) return;
      _driverPos = LatLng(loc.lat, loc.lng);
      _publishDriver(bearing: loc.heading ?? 0);
      _loadRoute();
    });
  }

  Future<void> _refreshJob() async {
    final jobId = _jobId ?? ref.read(jobDraftProvider).activeJob?.id;
    if (jobId == null || !mounted) return;
    try {
      final updated = await ref.read(jobRepositoryProvider).getJob(jobId);
      if (!mounted) return;
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(jobDraftProvider.notifier).state =
          container.read(jobDraftProvider).copyWith(activeJob: updated);
      if (_driverPos == null) {
        _seedDriver(updated);
        _publishDriver();
      }
      _publishStaticMarkers();
      _loadRoute();
      _handleStatus(updated.status);
    } catch (_) {}
  }

  Future<void> _loadRoute() async {
    final job = ref.read(jobDraftProvider).activeJob;
    final dropoff = _dropoffOf(job);
    final origin = _driverPos ?? _pickupOf(job);
    if (origin == null || dropoff == null) return;
    final key =
        '${origin.latitude.toStringAsFixed(3)},${origin.longitude.toStringAsFixed(3)}>'
        '${dropoff.latitude.toStringAsFixed(4)},${dropoff.longitude.toStringAsFixed(4)}';
    if (key == _routeKey) return;
    _routeKey = key;
    final route = await _routes.fetch(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destinationLat: dropoff.latitude,
      destinationLng: dropoff.longitude,
    );
    if (!mounted || _routeKey != key) return;
    _routePoints = route?.points ?? [origin, dropoff];
    _routeMinutes = route?.durationMin;
    ref.read(tripRouteMetaProvider(TripMapScope.progress).notifier).state =
        TripRouteMeta(minutes: _routeMinutes);
    ref.read(tripPolylinesProvider(TripMapScope.progress).notifier).state =
        _routeLines(_routePoints);
    _publishCamera(_routePoints);
  }

  void _publishDriver({double bearing = 0}) {
    final pos = _driverPos;
    ref.read(tripDriverProvider(TripMapScope.progress).notifier).state =
        pos == null
            ? null
            : DriverPose(
                position: pos,
                bearing: bearing,
                icon: _markers?.car,
              );
  }

  void _publishStaticMarkers() {
    final dropoff = _dropoffOf(ref.read(jobDraftProvider).activeJob);
    ref.read(tripMarkersProvider(TripMapScope.progress).notifier).state = {
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          anchor: TripMarkers.dropoffAnchor,
          zIndexInt: 1,
          icon: _markers?.dropoff ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };
  }

  Set<Polyline> _routeLines(List<LatLng> points) {
    if (points.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('route-casing'),
        color: AppColors.white,
        width: 8,
        points: points,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        color: AppColors.primary,
        width: 5,
        points: points,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  void _publishCamera(List<LatLng> points) {
    final fallback =
        points.isNotEmpty ? points.first : const LatLng(52.48, -1.89);
    ref.read(tripCameraProvider(TripMapScope.progress).notifier).state =
        cameraForPoints(
      points,
      generation: ++_cameraGeneration,
      zoom: 14,
      fallback: fallback,
    );
  }

  Widget _tripMap() {
    return _map ??= RyvoMapCanvas(
      markers: tripMarkersProvider(TripMapScope.progress),
      polylines: tripPolylinesProvider(TripMapScope.progress),
      camera: tripCameraProvider(TripMapScope.progress),
      driver: tripDriverProvider(TripMapScope.progress),
      padding: const EdgeInsets.only(top: 72, bottom: 280),
      boundsPadding: 96,
    );
  }

  static const _preArrivalStatuses = {
    'draft',
    'searching',
    'payment_pending',
    'matched',
    'provider_en_route',
  };

  void _handleStatus(String status) {
    if (!mounted) return;
    if (status == 'searching') {
      context.go('/searching');
      return;
    }
    if (_preArrivalStatuses.contains(status)) {
      context.go('/live-tracking');
      return;
    }
    switch (status) {
      case 'completed':
        _pollTimer?.cancel();
        _statusSub?.cancel();
        context.go('/payment-success');
        break;
      case 'no_provider_found':
        _pollTimer?.cancel();
        _statusSub?.cancel();
        final noProviderContainer =
            ProviderScope.containerOf(context, listen: false);
        context.go('/no-providers');
        Future.microtask(
          () => markJobSessionFinished(noProviderContainer, jobId: _jobId),
        );
        break;
      case 'cancelled_by_customer':
      case 'cancelled_by_provider':
      case 'cancelled_by_admin':
        _pollTimer?.cancel();
        _statusSub?.cancel();
        final container = ProviderScope.containerOf(context, listen: false);
        context.go('/home');
        Future.microtask(
          () => markJobSessionFinished(container, jobId: _jobId),
        );
        break;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pollTimer?.cancel();
    _statusSub?.cancel();
    _locSub?.cancel();
    if (_jobId != null) {
      ref.read(trackingSocketProvider).unsubscribeJob(_jobId!);
    }
    super.dispose();
  }

  Future<void> _cancelJob() async {
    final jobId = _jobId ?? ref.read(jobDraftProvider).activeJob?.id;
    if (jobId == null) return;
    final reason = await promptJobCancelReason(context);
    if (reason == null || !mounted) return;
    try {
      await ref.read(jobRepositoryProvider).cancelJob(jobId, reason: reason);
      if (!mounted) return;
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: jobId,
      );
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  String _elapsedDisplay(JobModel? job) {
    return formatElapsedClock(
        serviceElapsedDuration(startedAt: job?.startedAt));
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDraftProvider.select((draft) => draft.activeJob));
    final meta = ref.watch(tripRouteMetaProvider(TripMapScope.progress));
    final providerName =
        job?.provider?.fullName ?? AppLocalizations.of(context).yourProvider;
    final rating = job?.provider?.ratingAvg;
    final service = job?.serviceCategory?.name ?? 'Ride';
    final vehicle = job?.vehicle;
    final dropoffLabel = job?.dropoffAddress?.trim();
    final street = (dropoffLabel == null || dropoffLabel.isEmpty)
        ? 'dropoff'
        : dropoffLabel.split(',').first.trim();
    final minutes = meta.minutes ?? _routeMinutes;
    final vehicleLine =
        vehicle == null ? service : '${vehicle.make} ${vehicle.model}'.trim();

    return Scaffold(
      body: Stack(
        children: [
          _tripMap(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    minutes != null ? '$minutes min' : _elapsedDisplay(job),
                    style: RyvoTypography.eta(
                      fontSize: 14,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 280,
            child: Material(
              color: AppColors.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _publishCamera(_routePoints),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.center_focus_strong, size: 22),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DriverTripCard(
              name: providerName,
              ratingLabel: rating == null || rating <= 0
                  ? '—'
                  : rating.toStringAsFixed(1),
              plate: vehicle?.plateNumber,
              vehicleLine: vehicleLine,
              headline: 'Heading to $street',
              subtitle: dropoffLabel,
              onCall: () => dialPhone(context, job?.provider?.phone),
              onChat: job?.id == null
                  ? null
                  : () => context.push('/chat/${job!.id}'),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    formatMoney(job?.displayFare ?? 0),
                    style: RyvoTypography.price(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (job?.id != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ShareTripButton.action(jobId: job!.id),
                    ),
                  ],
                  if (job?.jobType == 'parcel' &&
                      (job?.recipientOtp ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Give this OTP to the recipient: ${job!.recipientOtp}',
                      style: RyvoTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  RyvoButton(
                    label: AppLocalizations.of(context).cancelJob,
                    variant: RyvoButtonVariant.ghost,
                    onPressed: _cancelJob,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
