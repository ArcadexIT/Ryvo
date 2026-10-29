import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/location/trip_markers.dart';
import '../../../../core/network/tracking_socket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/job_elapsed.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../data/models/models.dart';
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
  GoogleMapController? _mapController;
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

  @override
  void initState() {
    super.initState();
    final job = ref.read(jobDraftProvider).activeJob;
    _jobId = job?.id;
    _seedDriver(job);
    _loadMarkers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshJob());
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
    if (mounted) setState(() => _markers = set);
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
      setState(() => _driverPos = LatLng(loc.lat, loc.lng));
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
      if (_driverPos == null) _seedDriver(updated);
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
    setState(() {
      _routePoints = route?.points ?? [origin, dropoff];
      _routeMinutes = route?.durationMin;
    });
    _fitRoute(_routePoints);
  }

  void _fitRoute(List<LatLng> points) {
    final controller = _mapController;
    if (controller == null || points.length < 2) return;
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points) {
      south = math.min(south, point.latitude);
      north = math.max(north, point.latitude);
      west = math.min(west, point.longitude);
      east = math.max(east, point.longitude);
    }
    if (south == north) {
      south -= 0.002;
      north += 0.002;
    }
    if (west == east) {
      west -= 0.002;
      east += 0.002;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        96,
      ),
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
        final noProviderContainer = ProviderScope.containerOf(context, listen: false);
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
    return formatElapsedClock(serviceElapsedDuration(startedAt: job?.startedAt));
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final JobModel? job = ref.watch(jobDraftProvider).activeJob;
    final providerName = job?.provider?.fullName ?? AppLocalizations.of(context).yourProvider;
    final rating = job?.provider?.ratingAvg;
    final service = job?.serviceCategory?.name ?? 'Ride';
    final dropoff = _dropoffOf(job);
    final pickup = _pickupOf(job);
    final origin = _driverPos ?? pickup;
    final routeLine = _routePoints.length >= 2
        ? _routePoints
        : (origin != null && dropoff != null ? [origin, dropoff] : const <LatLng>[]);
    final camera = dropoff ?? pickup ?? const LatLng(52.48, -1.89);
    final dropoffLabel = job?.dropoffAddress?.trim();
    final street = (dropoffLabel ?? 'dropoff').split(',').first.trim();

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: camera, zoom: 14),
            padding: const EdgeInsets.only(top: 72, bottom: 260),
            onMapCreated: (c) {
              _mapController = c;
              _fitRoute(routeLine);
            },
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            polylines: {
              if (routeLine.length >= 2) ...[
                Polyline(
                  polylineId: const PolylineId('route-casing'),
                  color: Colors.white,
                  width: 8,
                  points: routeLine,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: AppColors.primary,
                  width: 5,
                  points: routeLine,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
              ],
            },
            markers: {
              if (dropoff != null)
                Marker(
                  markerId: const MarkerId('dropoff'),
                  position: dropoff,
                  anchor: TripMarkers.dropoffAnchor,
                  zIndexInt: 1,
                  icon: _markers?.dropoff ??
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              if (_driverPos != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: _driverPos!,
                  anchor: TripMarkers.carAnchor,
                  zIndexInt: 2,
                  flat: true,
                  icon: _markers?.car ??
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    _routeMinutes != null ? '$_routeMinutes min' : _elapsedDisplay(job),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
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
                onTap: () => _fitRoute(routeLine),
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
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.grey600, borderRadius: BorderRadius.circular(2)),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Heading to $street',
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    if (dropoffLabel != null && dropoffLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dropoffLabel,
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    if (job?.jobType == 'parcel' && (job?.recipientOtp ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Give this OTP to the recipient: ${job!.recipientOtp}',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.grey700,
                          child: Text(
                            _initials(providerName),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(providerName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              Text(
                                [
                                  if (rating != null) rating.toStringAsFixed(1),
                                  service,
                                  formatMoney(job?.displayFare ?? 0),
                                ].join(' · '),
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.of(context).callProvider,
                          onPressed: () => dialPhone(context, job?.provider?.phone),
                          icon: const Icon(Icons.phone, color: AppColors.success),
                        ),
                        if (job?.id != null)
                          IconButton(
                            onPressed: () => context.push('/chat/${job!.id}'),
                            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.info),
                          ),
                        if (job?.id != null) ShareTripButton.icon(jobId: job!.id),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RyvoButton(
                      label: AppLocalizations.of(context).cancelJob,
                      variant: RyvoButtonVariant.ghost,
                      onPressed: _cancelJob,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
