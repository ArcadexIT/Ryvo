import 'dart:async';
import 'dart:math' as math;
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
import '../../../../core/utils/phone_call.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../../data/models/models.dart';
import '../../../tracking/presentation/trip_map_providers.dart';
import '../../../tracking/presentation/widgets/driver_trip_card.dart';
import '../../../tracking/presentation/widgets/share_trip_button.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class LiveTrackingPage extends ConsumerStatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  ConsumerState<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends ConsumerState<LiveTrackingPage> {
  final DrivingRouteService _routes = DrivingRouteService();
  StreamSubscription<JobLocation>? _locSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Timer? _pollTimer;
  LatLng? _providerPos;
  late LatLng _userPos;
  String? _jobId;
  List<LatLng> _routePoints = const [];
  int? _routeMinutes;
  double? _routeKm;
  String? _routeKey;
  TripMarkerSet? _markers;
  Widget? _map;
  int _cameraGeneration = 0;

  @override
  void initState() {
    super.initState();
    final job = ref.read(jobDraftProvider).activeJob;
    final draft = ref.read(jobDraftProvider);
    _userPos = _destinationFor(job, draft);
    _jobId = job?.id;
    _seedProviderPos(job);
    _publishDriver();
    ref.read(tripCameraProvider(TripMapScope.live).notifier).state =
        RyvoMapCamera(target: _userPos, zoom: 14.8);
    _connect();
    Future.microtask(_refreshJob);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (ref.read(trackingSocketProvider).connected) return;
      _refreshJob();
    });
    _loadMarkers();
    _loadRoute();
  }

  Future<void> _loadMarkers() async {
    final set = await TripMarkers.load();
    if (!mounted) return;
    _markers = set;
    _publishDriver();
    _publishStaticMarkers();
  }

  LatLng _destinationFor(JobModel? job, JobRequestDraft draft) {
    final onTrip = job?.status == 'in_progress';
    final lat = onTrip
        ? (job?.dropoffLat ?? draft.dropoffLat)
        : (job?.pickupLat ?? draft.pickupLat);
    final lng = onTrip
        ? (job?.dropoffLng ?? draft.dropoffLng)
        : (job?.pickupLng ?? draft.pickupLng);
    return LatLng(lat ?? draft.pickupLat, lng ?? draft.pickupLng);
  }

  void _seedProviderPos(JobModel? job) {
    final lat = job?.provider?.currentLat;
    final lng = job?.provider?.currentLng;
    if (lat == null || lng == null) return;
    _providerPos = LatLng(lat, lng);
  }

  Future<void> _refreshJob() async {
    if (!mounted || _jobId == null) return;
    try {
      final updated = await ref.read(jobRepositoryProvider).getJob(_jobId!);
      if (!mounted) return;
      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(activeJob: updated);
      final next = _destinationFor(updated, ref.read(jobDraftProvider));
      if (next != _userPos) _userPos = next;
      if (_providerPos == null) {
        _seedProviderPos(updated);
        _publishDriver();
      }
      _publishStaticMarkers();
      _loadRoute();
      _handleStatus(updated.status);
    } catch (_) {}
  }

  void _handleStatus(String status) {
    if (!mounted) return;
    if (status == 'in_progress') {
      context.pushReplacement('/in-progress');
    } else if (status == 'completed') {
      context.go('/payment-success');
    } else if (status == 'searching') {
      context.go('/searching');
    } else if (status == 'no_provider_found') {
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: _jobId,
      );
      context.go('/no-providers');
    } else if (status.startsWith('cancelled')) {
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: _jobId,
      );
      context.go('/home');
    }
  }

  Future<void> _cancelJob() async {
    final jobId = _jobId ?? ref.read(jobDraftProvider).activeJob?.id;
    if (jobId == null) return;
    final reason = await promptJobCancelReason(context);
    if (reason == null || !mounted) return;
    try {
      await ref.read(jobRepositoryProvider).cancelJob(jobId, reason: reason);
      if (!mounted) return;
      markJobSessionFinished(ProviderScope.containerOf(context, listen: false),
          jobId: jobId);
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _connect() async {
    if (_jobId == null) return;
    final socket = ref.read(trackingSocketProvider);
    await socket.connect();
    socket.subscribeJob(_jobId!);

    _locSub = socket.onLocation.listen((loc) {
      if (!mounted) return;
      _providerPos = LatLng(loc.lat, loc.lng);
      _publishDriver(bearing: loc.heading ?? 0);
      _loadRoute();
    });

    _statusSub = socket.onStatus.listen((data) {
      if (!mounted) return;
      final status = data['status'] as String?;
      if (status != null) {
        _refreshJob();
      }
    });
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _statusSub?.cancel();
    _pollTimer?.cancel();
    if (_jobId != null) {
      ref.read(trackingSocketProvider).unsubscribeJob(_jobId!);
    }
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final origin = _providerPos;
    if (origin == null) return;
    final dest = _userPos;
    final key =
        '${origin.latitude.toStringAsFixed(3)},${origin.longitude.toStringAsFixed(3)}>'
        '${dest.latitude.toStringAsFixed(4)},${dest.longitude.toStringAsFixed(4)}';
    if (key == _routeKey) return;
    _routeKey = key;
    final route = await _routes.fetch(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destinationLat: dest.latitude,
      destinationLng: dest.longitude,
    );
    if (!mounted || _routeKey != key) return;
    _routePoints = route?.points ?? [origin, dest];
    _routeMinutes = route?.durationMin;
    _routeKm = route?.distanceKm;
    ref.read(tripRouteMetaProvider(TripMapScope.live).notifier).state =
        TripRouteMeta(minutes: _routeMinutes, km: _routeKm);
    ref.read(tripPolylinesProvider(TripMapScope.live).notifier).state =
        _routeLines(_routePoints);
    _publishCamera(_routePoints);
  }

  void _publishDriver({double bearing = 0}) {
    final pos = _providerPos;
    ref.read(tripDriverProvider(TripMapScope.live).notifier).state = pos == null
        ? null
        : DriverPose(
            position: pos,
            bearing: bearing,
            icon: _markers?.car,
          );
  }

  void _publishStaticMarkers() {
    ref.read(tripMarkersProvider(TripMapScope.live).notifier).state = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _userPos,
        anchor: TripMarkers.pickupAnchor,
        zIndexInt: 1,
        icon: _markers?.pickup ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
    ref.read(tripCameraProvider(TripMapScope.live).notifier).state =
        cameraForPoints(
      points,
      generation: ++_cameraGeneration,
      zoom: 15,
      fallback: _userPos,
    );
  }

  void _recenter() {
    final points = <LatLng>[..._routePoints];
    if (points.isEmpty) {
      points.add(_userPos);
      final driver = _providerPos;
      if (driver != null) points.add(driver);
    }
    _publishCamera(points);
  }

  Widget _liveMap() {
    return _map ??= RyvoMapCanvas(
      markers: tripMarkersProvider(TripMapScope.live),
      polylines: tripPolylinesProvider(TripMapScope.live),
      camera: tripCameraProvider(TripMapScope.live),
      driver: tripDriverProvider(TripMapScope.live),
      padding: const EdgeInsets.only(top: 80, bottom: 280),
      boundsPadding: 96,
    );
  }

  double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDraftProvider.select((draft) => draft.activeJob));
    final pose = ref.watch(tripDriverProvider(TripMapScope.live));
    final meta = ref.watch(tripRouteMetaProvider(TripMapScope.live));
    final provider = job?.provider;
    final providerName =
        provider?.fullName ?? AppLocalizations.of(context).yourProvider;
    final rating = provider?.ratingAvg;
    final serviceName = job?.serviceCategory?.name ??
        AppLocalizations.of(context).roadsideService;
    final vehicle = job?.vehicle;
    final fare = job?.displayFare ?? 0;
    final status = job?.status ?? '';
    final hasArrived = status == 'arrived';

    final straightKm =
        pose == null ? null : _distanceKm(pose.position, _userPos);
    final distanceKm = meta.km ?? straightKm;
    final chainMin = job?.pickupEtaMinutes;
    final etaMin = chainMin ??
        meta.minutes ??
        (straightKm == null
            ? null
            : math.max(1, (straightKm / 30 * 60).round()));
    final vehicleLine = vehicle == null
        ? serviceName
        : '${vehicle.make} ${vehicle.model}'.trim();

    return Scaffold(
      body: Stack(
        children: [
          _liveMap(),

          // Top info bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12)
                        ],
                      ),
                      child: Icon(Icons.arrow_back_ios_new,
                          color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasArrived ? Icons.check_circle : Icons.access_time,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasArrived
                              ? AppLocalizations.of(context).providerArrived
                              : (etaMin == null
                                  ? AppLocalizations.of(context).locating
                                  : '$etaMin min away'),
                          style: RyvoTypography.eta(
                            fontSize: 13,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: 320,
            child: GestureDetector(
              onTap: _recenter,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.3), blurRadius: 12)
                  ],
                ),
                child: Icon(Icons.center_focus_strong,
                    color: AppColors.textPrimary, size: 22),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DriverTripCard(
              name: providerName,
              ratingLabel: rating == null || rating <= 0
                  ? '—'
                  : rating.toStringAsFixed(1),
              plate: vehicle?.plateNumber,
              vehicleLine: vehicleLine,
              headline: hasArrived ? 'Driver is here' : 'Driver on the way',
              subtitle: chainMin != null
                  ? 'Finishing a nearby trip, then heading to you'
                  : hasArrived
                      ? 'Your driver will start the trip when you are in the car.'
                      : 'You can follow the driver until they reach pickup.',
              onCall: () => _callProvider(provider?.phone),
              onChat: () => _openChat(job?.id),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.straighten,
                          label: AppLocalizations.of(context).distance,
                          value: distanceKm == null
                              ? '—'
                              : '${distanceKm.toStringAsFixed(1)} km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.access_time,
                          label: AppLocalizations.of(context).eta,
                          value: hasArrived
                              ? AppLocalizations.of(context).arrived
                              : (etaMin == null ? '—' : '$etaMin min'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.payments_outlined,
                          label: AppLocalizations.of(context).total,
                          value: formatMoney(fare),
                        ),
                      ),
                    ],
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
                  if (status == 'in_progress') ...[
                    const SizedBox(height: 12),
                    RyvoButton(
                      label: 'On trip',
                      variant: RyvoButtonVariant.outline,
                      onPressed: () => context.push('/in-progress'),
                    ),
                  ],
                  const SizedBox(height: 4),
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

  void _openChat(String? jobId) {
    if (jobId == null) return;
    context.push('/chat/$jobId');
  }

  void _callProvider(String? phone) {
    dialPhone(context, phone);
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: RyvoTypography.distance(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: RyvoTypography.style(
              fontSize: 10,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
