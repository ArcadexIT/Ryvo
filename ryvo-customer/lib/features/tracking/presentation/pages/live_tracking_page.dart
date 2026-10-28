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
import '../../../../core/utils/phone_call.dart';
import '../../../../data/models/models.dart';
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
  GoogleMapController? _mapController;
  StreamSubscription<JobLocation>? _locSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Timer? _pollTimer;
  bool _confirmingStart = false;

  LatLng? _providerPos;
  late LatLng _userPos;
  String? _jobId;
  List<LatLng> _routePoints = const [];
  int? _routeMinutes;
  double? _routeKm;
  String? _routeKey;
  TripMarkerSet? _markers;

  @override
  void initState() {
    super.initState();
    final job = ref.read(jobDraftProvider).activeJob;
    final draft = ref.read(jobDraftProvider);
    _userPos = _destinationFor(job, draft);
    _jobId = job?.id;
    _seedProviderPos(job);
    _connect();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshJob());
    _loadMarkers();
    _loadRoute();
  }

  Future<void> _loadMarkers() async {
    final set = await TripMarkers.load();
    if (mounted) setState(() => _markers = set);
  }

  LatLng _destinationFor(JobModel? job, JobRequestDraft draft) {
    final onTrip = job?.status == 'in_progress';
    final lat = onTrip ? (job?.dropoffLat ?? draft.dropoffLat) : (job?.pickupLat ?? draft.pickupLat);
    final lng = onTrip ? (job?.dropoffLng ?? draft.dropoffLng) : (job?.pickupLng ?? draft.pickupLng);
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
      if (next != _userPos) {
        _userPos = next;
        setState(() {});
      }
      if (_providerPos == null) {
        _seedProviderPos(updated);
        if (mounted) setState(() {});
      }
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
    } else if (status == 'arrived' || status == 'provider_en_route' || status == 'matched') {
      setState(() {});
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
      markJobSessionFinished(ProviderScope.containerOf(context, listen: false), jobId: jobId);
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _confirmJobStarted() async {
    final jobId = _jobId ?? ref.read(jobDraftProvider).activeJob?.id;
    if (jobId == null || _confirmingStart) return;
    setState(() => _confirmingStart = true);
    try {
      final updated = await ref.read(jobRepositoryProvider).confirmJobStart(jobId);
      if (!mounted) return;
      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(activeJob: updated);
      _handleStatus(updated.status);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _confirmingStart = false);
    }
  }

  Future<void> _connect() async {
    if (_jobId == null) return;
    final socket = ref.read(trackingSocketProvider);
    await socket.connect();
    socket.subscribeJob(_jobId!);

    _locSub = socket.onLocation.listen((loc) {
      if (!mounted) return;
      setState(() => _providerPos = LatLng(loc.lat, loc.lng));
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
    setState(() {
      _routePoints = route?.points ?? [origin, dest];
      _routeMinutes = route?.durationMin;
      _routeKm = route?.distanceKm;
    });
    _fitRoute(_pointsToFit(_routePoints));
  }

  List<LatLng> _pointsToFit(List<LatLng> route) => route;

  void _fitRoute(List<LatLng> points) {
    final controller = _mapController;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
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

  void _recenter() {
    final points = <LatLng>[];
    if (_routePoints.isNotEmpty) {
      points.addAll(_routePoints);
    } else {
      points.add(_userPos);
      final driver = _providerPos;
      if (driver != null) points.add(driver);
    }
    _fitRoute(_pointsToFit(points));
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
    final job = ref.watch(jobDraftProvider).activeJob;
    final provider = job?.provider;
    final providerName = provider?.fullName ?? AppLocalizations.of(context).yourProvider;
    final rating = provider?.ratingAvg;
    final serviceName = job?.serviceCategory?.name ?? AppLocalizations.of(context).roadsideService;
    final fare = job?.displayFare ?? 0;
    final status = job?.status ?? '';
    final hasArrived = status == 'arrived';

    final straightKm = _providerPos == null ? null : _distanceKm(_providerPos!, _userPos);
    final distanceKm = _routeKm ?? straightKm;
    final etaMin = _routeMinutes ??
        (straightKm == null ? null : math.max(1, (straightKm / 30 * 60).round()));
    final routeLine = _routePoints.length >= 2
        ? _routePoints
        : (_providerPos == null ? const <LatLng>[] : [_providerPos!, _userPos]);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _userPos, zoom: 14.8),
            padding: const EdgeInsets.only(top: 80, bottom: 280),
            onMapCreated: (c) {
              _mapController = c;
              _fitRoute(_pointsToFit(routeLine));
            },
            mapType: MapType.normal,
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
              Marker(
                markerId: const MarkerId('pickup'),
                position: _userPos,
                anchor: TripMarkers.pickupAnchor,
                zIndexInt: 1,
                icon: _markers?.pickup ??
                    BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              if (_providerPos != null)
                Marker(
                  markerId: const MarkerId('provider'),
                  position: _providerPos!,
                  anchor: TripMarkers.carAnchor,
                  zIndexInt: 2,
                  flat: true,
                  icon: _markers?.car ??
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
            },
          ),

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
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)],
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
                              : (etaMin == null ? AppLocalizations.of(context).locating : '$etaMin min away'),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Icon(Icons.center_focus_strong, color: AppColors.textPrimary, size: 22),
              ),
            ),
          ),

          // Bottom info panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: AppColors.grey600, borderRadius: BorderRadius.circular(2)),
                    ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
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
                              Text(providerName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: AppColors.primary, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${rating?.toStringAsFixed(1) ?? '—'} · $serviceName',
                                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _ActionBtn(icon: Icons.phone, color: AppColors.success, onTap: () => _callProvider(provider?.phone)),
                        const SizedBox(width: 8),
                        _ActionBtn(icon: Icons.chat_bubble_outline, color: AppColors.info, onTap: () => _openChat(job?.id)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.straighten,
                            label: AppLocalizations.of(context).distance,
                            value: distanceKm == null ? '—' : '${distanceKm.toStringAsFixed(1)} km',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.access_time,
                            label: AppLocalizations.of(context).eta,
                            value: hasArrived ? AppLocalizations.of(context).arrived : (etaMin == null ? '—' : '~$etaMin min'),
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
                    if (job?.jobType == 'parcel' && (job?.recipientOtp ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    RyvoButton(
                      label: status == 'in_progress'
                          ? 'On trip'
                          : hasArrived
                              ? 'Driver is here'
                              : 'Driver on the way',
                      variant: RyvoButtonVariant.outline,
                      onPressed: status == 'in_progress'
                          ? () => context.push('/in-progress')
                          : null,
                    ),
                    if (status != 'in_progress') ...[
                      const SizedBox(height: 8),
                      Text(
                        hasArrived
                            ? 'Your driver will start the trip when you are in the car.'
                            : 'You can follow the driver until they reach pickup.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _openChat(String? jobId) {
    if (jobId == null) return;
    context.push('/chat/$jobId');
  }

  void _callProvider(String? phone) {
    dialPhone(context, phone);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

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
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }
}
