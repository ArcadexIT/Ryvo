import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/job/active_job_session.dart';
import '../../../payment/presentation/widgets/payment_sheet.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/map_style_utils.dart';
import '../../../../data/models/models.dart';
import '../../../home/presentation/widgets/map_markers.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';

class SearchingPage extends ConsumerStatefulWidget {
  const SearchingPage({super.key});

  @override
  ConsumerState<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends ConsumerState<SearchingPage> with TickerProviderStateMixin {
  static const _mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"water","stylers":[{"color":"#c9e8f5"}]},
    {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffd180"}]}
  ]''';

  late final AnimationController _radar;
  late final AnimationController _zoomBreath;
  final DrivingRouteService _routes = DrivingRouteService();
  GoogleMapController? _mapController;
  Timer? _pollTimer;
  Timer? _clock;
  Timer? _providerTimer;

  bool _cancelling = false;
  int _paymentPendingHits = 0;
  int _radarStep = -1;
  int _providerGen = 0;
  bool _mapReady = false;
  bool _sceneReady = false;
  bool _cameraLocked = false;
  bool _touchingMap = false;
  double? _baseZoom;
  double? _lastAppliedZoom;
  Timer? _resumeZoom;

  DateTime _startedAt = DateTime.now();
  List<NearbyProvider> _providers = const [];
  List<LatLng> _routePoints = const [];
  int _routeMinutes = 0;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;
  List<JobBidModel> _bids = const [];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _radar = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..addListener(_onRadarTick)
      ..repeat();
    _zoomBreath = AnimationController(vsync: this, duration: const Duration(milliseconds: 5600))
      ..addListener(_onZoomBreath);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollJob());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _providerTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadProviders());
    Future.microtask(_pollJob);
    Future.microtask(_prepareMap);
  }

  Duration get _elapsed => DateTime.now().difference(_startedAt);

  void _onRadarTick() {
    final step = (_radar.value * 20).floor();
    if (step == _radarStep) return;
    _radarStep = step;
    if (mounted) setState(() {});
  }

  Future<void> _prepareMap() async {
    final pickupIcon = await MapMarkers.buildStopLabel(
      title: 'Pickup',
      subtitle: 'Now',
      color: const Color(0xFF32BB78),
    );
    if (!mounted) return;
    setState(() => _pickupIcon = pickupIcon);
    await Future.wait([_loadRoute(), _loadProviders()]);
    if (!mounted) return;
    _sceneReady = true;
    _lockAndBreathe();
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
    final arrival = DateTime.now().add(Duration(minutes: minutes == 0 ? 1 : minutes));
    final hour = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
    final minute = arrival.minute.toString().padLeft(2, '0');
    final suffix = arrival.hour >= 12 ? 'PM' : 'AM';
    final dropoffIcon = await MapMarkers.buildStopLabel(
      title: 'Dropoff',
      subtitle: '$hour:$minute $suffix',
      color: const Color(0xFF1F2937),
    );
    if (!mounted) return;
    setState(() {
      _routePoints = route?.points ?? const [];
      _routeMinutes = minutes;
      _dropoffIcon = dropoffIcon;
    });
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
  }

  LatLng _pickupOf(JobRequestDraft draft) {
    final job = draft.activeJob;
    final lat = job?.pickupLat ?? draft.pickupLat;
    final lng = job?.pickupLng ?? draft.pickupLng;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) {
      return LatLng(draft.pickupLat, draft.pickupLng);
    }
    return LatLng(lat, lng);
  }

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

  Future<void> _lockAndBreathe() async {
    final controller = _mapController;
    if (_cameraLocked || !_mapReady || !_sceneReady || controller == null || !mounted) return;
    _cameraLocked = true;

    final draft = ref.read(jobDraftProvider);
    final pickup = _pickupOf(draft);
    final dropoff = _dropoffOf(draft);
    final points = <LatLng>[pickup, ..._routePoints];
    if (dropoff != null) points.add(dropoff);

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

    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final visibleHeight = math.max(180.0, size.height - 88 - 420 - bottomInset);
    final center = LatLng((south + north) / 2, (west + east) / 2);
    final zoom = points.length < 2 || ((north - south).abs() < 0.0001 && (east - west).abs() < 0.0001)
        ? 15.2
        : _zoomToFit(
            south: south,
            north: north,
            west: west,
            east: east,
            widthPx: size.width - 36,
            heightPx: visibleHeight,
          );

    _baseZoom = zoom;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: center, zoom: zoom)),
    );
    if (!mounted || _touchingMap) return;
    _startZoomBreath();
  }

  void _startZoomBreath() {
    if (_baseZoom == null || _touchingMap) return;
    _lastAppliedZoom = null;
    _zoomBreath.value = 0.5;
    _zoomBreath.repeat(reverse: true);
  }

  void _onMapPointerDown() {
    _touchingMap = true;
    _resumeZoom?.cancel();
    _zoomBreath.stop();
  }

  Future<void> _onMapPointerUp() async {
    _touchingMap = false;
    final controller = _mapController;
    if (controller == null || !mounted) return;
    _resumeZoom?.cancel();
    _resumeZoom = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted || _touchingMap || _mapController == null) return;
      try {
        _baseZoom = await _mapController!.getZoomLevel();
      } catch (_) {}
      if (!mounted || _touchingMap) return;
      _startZoomBreath();
    });
  }

  void _onZoomBreath() {
    final controller = _mapController;
    final base = _baseZoom;
    if (_touchingMap || controller == null || base == null || !mounted) return;
    final t = Curves.easeInOutCubic.transform(_zoomBreath.value);
    final zoom = base - 0.62 + t * 1.24;
    if (_lastAppliedZoom != null && (zoom - _lastAppliedZoom!).abs() < 0.008) return;
    _lastAppliedZoom = zoom;
    controller.moveCamera(CameraUpdate.zoomTo(zoom));
  }

  double _zoomToFit({
    required double south,
    required double north,
    required double west,
    required double east,
    required double widthPx,
    required double heightPx,
  }) {
    double zoomFor(double fraction, double pixels) {
      if (fraction <= 0.0000001 || pixels <= 0) return 16;
      return math.log(pixels / 256 / fraction) / math.ln2;
    }

    final latFraction = (_mercatorY(south) - _mercatorY(north)).abs();
    var lngDiff = (east - west).abs();
    if (lngDiff > 180) lngDiff = 360 - lngDiff;
    final fitted = math.min(zoomFor(latFraction, heightPx), zoomFor(lngDiff / 360, widthPx));
    return (fitted - 0.55).clamp(12.4, 16.2);
  }

  double _mercatorY(double lat) {
    final sinLat = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
    return 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
  }

  Set<Circle> _radarCircles(LatLng pickup) {
    final circles = <Circle>{};
    for (var i = 0; i < 3; i++) {
      final progress = (_radar.value + i / 3) % 1.0;
      final fade = (1 - progress).clamp(0.0, 1.0);
      circles.add(
        Circle(
          circleId: CircleId('radar-$i'),
          center: pickup,
          radius: 70 + progress * 780,
          fillColor: AppColors.primary.withOpacity(0.11 * fade),
          strokeColor: AppColors.primary.withOpacity(0.55 * fade),
          strokeWidth: 2,
        ),
      );
    }
    return circles;
  }

  Set<Marker> _markers(LatLng pickup, LatLng? dropoff) {
    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 1),
        zIndex: 3,
      ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1),
          zIndex: 2,
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
        color: Colors.white,
        width: 10,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: const Color(0xFF32BB78),
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
    if (seconds < 7) {
      return _SearchStatus(
        title: 'Looking for nearby drivers',
        subtitle: count == 0
            ? 'Scanning around your pickup'
            : count == 1
                ? '1 driver is nearby'
                : '$count drivers are nearby',
        step: 0,
      );
    }
    if (seconds < 18) {
      final first = _firstName(driver?.fullName);
      final detail = _driverDetail(driver);
      return _SearchStatus(
        title: first == null ? 'Contacting drivers' : 'Contacting $first',
        subtitle: detail ?? 'Your request is going out now',
        step: 1,
      );
    }
    if (seconds < 34) {
      return const _SearchStatus(
        title: 'Waiting for a driver to accept',
        subtitle: 'Nearby drivers can see your offer',
        step: 2,
      );
    }
    if (seconds < 52) {
      return const _SearchStatus(
        title: 'Expanding the search',
        subtitle: 'Looking a little further out',
        step: 2,
      );
    }
    return const _SearchStatus(
      title: 'Still looking for a driver',
      subtitle: 'Hang tight — someone should accept soon',
      step: 2,
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
      if (driver.distanceKm != null) '${driver.distanceKm!.toStringAsFixed(1)} km',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  String _clockLabel(Duration elapsed) {
    final minutes = elapsed.inMinutes.remainder(60).toString();
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _searchProgress {
    final seconds = _elapsed.inMilliseconds / 1000;
    return (1 - math.exp(-seconds / 42)).clamp(0.06, 0.92);
  }

  Future<void> _pollJob() async {
    if (!mounted) return;
    final job = ref.read(jobDraftProvider).activeJob;
    if (job == null) return;

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
          final route = await showRyvoCheckoutSheet(context);
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
          final bids = await ref.read(jobRepositoryProvider).listBids(updated.id);
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
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_outlined, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.noProvidersAvailable,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.thereAreNoProvidersAvailableNearbyRightNowPlease,
          style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
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
      await ref.read(jobRepositoryProvider).cancelJob(job.id, reason: 'Cancelled by customer');
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
  void dispose() {
    _radar.dispose();
    _zoomBreath.dispose();
    _resumeZoom?.cancel();
    _pollTimer?.cancel();
    _clock?.cancel();
    _providerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(jobDraftProvider);
    final job = draft.activeJob;
    final pickup = _pickupOf(draft);
    final dropoff = _dropoffOf(draft);
    final status = _status();
    final serviceName = draft.serviceCategory?.name ?? job?.serviceCategory?.name ?? AppLocalizations.of(context).service;
    final pickupAddress = (job?.pickupAddress.trim().isNotEmpty ?? false) ? job!.pickupAddress : draft.pickupAddress;
    final dropoffAddress = (job?.dropoffAddress?.trim().isNotEmpty ?? false) ? job!.dropoffAddress! : draft.dropoffAddress;
    final fare = job?.displayFare ?? draft.estimate?.estimatedFare ?? 0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _onMapPointerDown(),
              onPointerUp: (_) => _onMapPointerUp(),
              onPointerCancel: (_) => _onMapPointerUp(),
              child: GoogleMap(
                padding: EdgeInsets.only(top: 88, bottom: 420 + bottomInset),
                initialCameraPosition: CameraPosition(target: pickup, zoom: 14.6),
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await applyMapStyle(controller, _mapStyle);
                  if (!mounted) return;
                  _mapReady = true;
                  _lockAndBreathe();
                },
                mapType: MapType.normal,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                markers: _markers(pickup, dropoff),
                circles: _radarCircles(pickup),
                polylines: _polylines(pickup, dropoff),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Searching · ${_clockLabel(_elapsed)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _SearchSheet(
                status: status,
                progress: _searchProgress,
                serviceName: serviceName,
                fare: formatMoney(fare),
                pickupAddress: pickupAddress,
                dropoffAddress: dropoffAddress,
                routeMinutes: _routeMinutes,
                driverCount: _providers.length,
                cancelling: _cancelling,
                onCancel: _cancelling ? null : _cancel,
                bids: _bids,
                onAcceptBid: (bid) async {
                  final job = ref.read(jobDraftProvider).activeJob;
                  if (job == null) return;
                  try {
                    final updated = await ref.read(jobRepositoryProvider).acceptBid(job.id, bid.id);
                    if (!mounted) return;
                    ref.read(jobDraftProvider.notifier).state =
                        ref.read(jobDraftProvider).copyWith(activeJob: updated);
                    context.pushReplacement(routeForActiveCustomerJob(updated.status));
                  } catch (e) {
                    if (mounted) showApiError(context, e);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchStatus {
  const _SearchStatus({
    required this.title,
    required this.subtitle,
    required this.step,
  });

  final String title;
  final String subtitle;
  final int step;
}

class _SearchSheet extends StatelessWidget {
  const _SearchSheet({
    required this.status,
    required this.progress,
    required this.serviceName,
    required this.fare,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.routeMinutes,
    required this.driverCount,
    required this.cancelling,
    required this.onCancel,
    this.bids = const [],
    this.onAcceptBid,
  });

  final _SearchStatus status;
  final double progress;
  final String serviceName;
  final String fare;
  final String pickupAddress;
  final String dropoffAddress;
  final int routeMinutes;
  final int driverCount;
  final bool cancelling;
  final VoidCallback? onCancel;
  final List<JobBidModel> bids;
  final Future<void> Function(JobBidModel bid)? onAcceptBid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status.title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.subtitle,
                style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.primaryLight,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              _StatusSteps(activeStep: status.step),
              if (bids.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Driver offers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ...bids.take(4).map(
                  (bid) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(bid.providerName ?? 'Driver'),
                    subtitle: Text(bid.kind == 'counter' ? 'Counter offer' : 'Accepted your price'),
                    trailing: TextButton(
                      onPressed: onAcceptBid == null ? null : () => onAcceptBid!(bid),
                      child: Text(formatMoney(bid.amount)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_car_filled, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          driverCount == 0
                              ? (routeMinutes > 0 ? '$routeMinutes min trip' : 'Request sent')
                              : driverCount == 1
                                  ? '1 driver nearby'
                                  : '$driverCount drivers nearby',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    fare,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RouteStops(pickup: pickupAddress, dropoff: dropoffAddress),
              const SizedBox(height: 16),
              RyvoButton(
                label: cancelling ? l10n.cancelling : l10n.cancelRequest,
                variant: RyvoButtonVariant.outline,
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Sent', 'Contacting', 'Accepting'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                color: i <= activeStep ? AppColors.primary : AppColors.divider,
              ),
            ),
          _StepDot(label: labels[i], done: i < activeStep, active: i == activeStep),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.done, required this.active});

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.primary : AppColors.grey300;
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? AppColors.primary : (active ? AppColors.primaryLight : AppColors.card),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : active
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: done || active ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RouteStops extends StatelessWidget {
  const _RouteStops({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
              Container(width: 2, height: 22, color: AppColors.divider),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup.trim().isEmpty ? 'Pickup' : pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 14),
                Text(
                  dropoff.trim().isEmpty ? 'Dropoff' : dropoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
