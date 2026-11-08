import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/location/driver_marker_renderer.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/location/trip_markers.dart';
import '../../../../core/network/tracking_socket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../../data/models/models.dart';
import '../../../tracking/presentation/trip_map_providers.dart';
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
  static const double _snapPeek = 0.35;
  static const double _snapMax = 0.85;
  static const List<double> _snaps = [_snapPeek, _snapMax];

  /// Handle and the gaps around it. The collapsed HUD fills whatever is left
  /// of the peek height so trip details stay below the fold.
  static const double _sheetChrome = 20;
  static const Duration _socketStaleAfter = Duration(seconds: 12);

  final DrivingRouteService _routes = DrivingRouteService();
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(_snapPeek);
  StreamSubscription<JobLocation>? _locSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Timer? _pollTimer;
  ValueNotifier<EdgeInsets>? _mapPadding;
  int _snapIndex = 0;
  int? _shownStraight;
  double? _straightKm;
  LatLng? _providerPos;
  late LatLng _userPos;
  String? _jobId;
  List<LatLng> _routePoints = const [];
  int? _routeMinutes;
  double? _routeKm;
  String? _routeKey;
  TripMarkerSet? _markers;
  DriverMarkerIcon? _driverIcon;
  String? _driverIconUrl;
  Widget? _map;
  int _cameraGeneration = 0;
  late final TrackingSocket _socket;
  ProviderContainer? _container;
  bool _closed = false;
  DateTime? _lastSocketEventAt;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(trackingSocketProvider);
    final job = ref.read(jobDraftProvider).activeJob;
    final draft = ref.read(jobDraftProvider);
    _userPos = _destinationFor(job, draft);
    _jobId = job?.id;
    _seedProviderPos(job);
    // Provider writes are illegal during initState. The map reads the camera
    // on the next frame, then recenters onto the rider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _publishDriver();
      _noteStraightLine();
      ref.read(tripCameraProvider(TripMapScope.live).notifier).state =
          RyvoMapCamera(target: _userPos, zoom: 14.8);
    });
    _connect();
    Future.microtask(_refreshJob);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_closed || _socketHealthy) return;
      _refreshJob();
    });
    _loadMarkers();
    _loadRoute();
  }

  Future<void> _loadMarkers() async {
    final set = await TripMarkers.load();
    if (!mounted) return;
    _markers = set;
    _publishStaticMarkers();
    await _loadDriverIcon();
  }

  /// Loads the unified driver marker once per image URL. The renderer caches
  /// it for the session, so calling this on every job refresh is cheap.
  Future<void> _loadDriverIcon() async {
    final url = ref.read(jobDraftProvider).activeJob?.provider?.vehicleImageUrl;
    if (_driverIcon != null && url == _driverIconUrl) return;
    _driverIconUrl = url;
    final icon = await DriverMarkerRenderer.load(imageUrl: url);
    if (!mounted || url != _driverIconUrl) return;
    _driverIcon = icon;
    _publishDriver();
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

  bool get _alive => !_closed && mounted && context.mounted;

  Future<void> _refreshJob() async {
    if (!_alive || _jobId == null) return;
    try {
      final updated = await ref.read(jobRepositoryProvider).getJob(_jobId!);
      if (!_alive) return;
      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(activeJob: updated);
      final next = _destinationFor(updated, ref.read(jobDraftProvider));
      if (next != _userPos) _userPos = next;
      if (_providerPos == null) {
        _seedProviderPos(updated);
        _publishDriver();
      }
      _publishStaticMarkers();
      _loadDriverIcon();
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
    if (_jobId == null || _closed) return;
    await _socket.connect();
    if (_closed || _jobId == null) return;
    _socket.subscribeJob(_jobId!);

    _locSub = _socket.onLocation.listen((loc) {
      _lastSocketEventAt = DateTime.now();
      if (!mounted) return;
      _providerPos = LatLng(loc.lat, loc.lng);
      _publishDriver(bearing: loc.heading);
      _noteStraightLine();
      _loadRoute();
    });

    _statusSub = _socket.onStatus.listen((data) {
      _lastSocketEventAt = DateTime.now();
      if (!mounted) return;
      final status = data['status'] as String?;
      if (status != null) {
        _refreshJob();
      }
    });
  }

  /// Connected is not the same as receiving trip events. A quiet socket still
  /// needs the HTTP refresh so a missed status cannot freeze the sheet.
  bool get _socketHealthy {
    if (!_socket.connected) return false;
    final last = _lastSocketEventAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _socketStaleAfter;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
    final bottom = MediaQuery.sizeOf(context).height * _snapPeek;
    final next = EdgeInsets.only(top: 88, bottom: bottom);
    final padding = _mapPadding;
    if (padding == null) {
      _mapPadding = ValueNotifier(next);
    }
  }

  @override
  void dispose() {
    _closed = true;
    _locSub?.cancel();
    _statusSub?.cancel();
    _pollTimer?.cancel();
    _mapPadding?.dispose();
    _sheetExtent.dispose();
    _releaseSocketRoom();
    super.dispose();
  }

  /// [WidgetRef.read] throws once the element is defunct. The container was
  /// captured while this page was mounted and still sees the live job.
  void _releaseSocketRoom() {
    final jobId = _jobId;
    if (jobId == null) return;
    final activeId = _container?.read(jobDraftProvider).activeJob?.id;
    if (activeId == jobId) return;
    _socket.unsubscribeJob(jobId);
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

  void _publishDriver({double? bearing}) {
    final pos = _providerPos;
    ref.read(tripDriverProvider(TripMapScope.live).notifier).state = pos == null
        ? null
        : DriverPose(
            position: pos,
            bearing: bearing,
            icon: _driverIcon,
          );
  }

  /// Added only after the bitmaps are ready, so no stock pin ever shows.
  void _publishStaticMarkers() {
    final icons = _markers;
    ref.read(tripMarkersProvider(TripMapScope.live).notifier).state = {
      if (icons != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _userPos,
          anchor: TripMarkers.pickupAnchor,
          zIndexInt: 1,
          icon: icons.pickup,
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
    final padding = _mapPadding;
    if (padding == null) return const SizedBox.expand();
    return _map ??= RyvoMapCanvas(
      markers: tripMarkersProvider(TripMapScope.live),
      polylines: tripPolylinesProvider(TripMapScope.live),
      camera: tripCameraProvider(TripMapScope.live),
      driver: tripDriverProvider(TripMapScope.live),
      initialTarget: _userPos,
      initialZoom: 14.8,
      paddingListenable: padding,
      boundsPadding: 72,
    );
  }

  /// Straight-line fallback until a road distance arrives. Only the displayed
  /// tenth of a kilometre rebuilds the sheet, never a driver-marker frame.
  void _noteStraightLine() {
    final driver = _providerPos;
    if (driver == null) return;
    final km = _distanceKm(driver, _userPos);
    final shown = (km * 10).round();
    if (shown == _shownStraight) return;
    _shownStraight = shown;
    _straightKm = km;
    final hasRoad =
        ref.read(tripRouteMetaProvider(TripMapScope.live)).km != null;
    if (!hasRoad && mounted) setState(() {});
  }

  int _nearestSnap(double extent) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < _snaps.length; i++) {
      final gap = (extent - _snaps[i]).abs();
      if (gap < distance) {
        distance = gap;
        best = i;
      }
    }
    return best;
  }

  bool _onSheet(DraggableScrollableNotification notification) {
    final extent = notification.extent;
    if ((_sheetExtent.value - extent).abs() > 0.002) {
      _sheetExtent.value = extent;
    }
    final index = _nearestSnap(extent);
    if (index != _snapIndex) {
      _snapIndex = index;
      HapticFeedback.selectionClick();
    }
    return false;
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
    final l10n = AppLocalizations.of(context);
    final job = ref.watch(jobDraftProvider.select((draft) => draft.activeJob));
    final meta = ref.watch(tripRouteMetaProvider(TripMapScope.live));
    final provider = job?.provider;
    final providerName = provider?.fullName ?? l10n.yourProvider;
    final rating = provider?.ratingAvg;
    final serviceName = job?.serviceCategory?.name ?? l10n.roadsideService;
    final vehicle = job?.vehicle;
    final fare = job?.displayFare ?? 0;
    final status = job?.status ?? '';
    final hasArrived = status == 'arrived';
    final straightKm = _straightKm;
    final distanceKm = meta.km ?? straightKm;
    final chainMin = job?.pickupEtaMinutes;
    final etaMin = chainMin ??
        meta.minutes ??
        (straightKm == null
            ? null
            : math.max(1, (straightKm / 30 * 60).round()));
    final colorName = vehicle?.color?.trim() ?? '';
    final makeModel = vehicle == null
        ? serviceName
        : '${vehicle.make} ${vehicle.model}'.trim();
    final vehicleLine =
        colorName.isEmpty ? makeModel : '$makeModel • $colorName';
    final etaHeadline = hasArrived
        ? l10n.providerArrived
        : (etaMin == null ? l10n.locating : '${l10n.arrivingIn} $etaMin min');
    final distanceLabel =
        distanceKm == null ? '—' : '${distanceKm.toStringAsFixed(1)} km';
    final pickup = job?.pickupAddress.trim() ?? '';
    final dropoff = job?.dropoffAddress?.trim() ?? '';
    final otp = job?.jobType == 'parcel' ? (job?.recipientOtp ?? '') : '';
    final primaryMinHeight = math.max(
      0.0,
      MediaQuery.sizeOf(context).height * _snapPeek -
          _sheetChrome -
          MediaQuery.paddingOf(context).bottom,
    );

    final sheet = _EnRouteBody(
      etaHeadline: etaHeadline,
      primaryMinHeight: primaryMinHeight,
      name: providerName,
      avatarUrl: provider?.avatarUrl,
      ratingLabel:
          rating == null || rating <= 0 ? '—' : rating.toStringAsFixed(1),
      vehicleLine: vehicleLine,
      plate: vehicle?.plateNumber ?? '',
      distance: distanceLabel,
      fare: formatMoney(fare),
      pickup: pickup,
      dropoff: dropoff,
      jobId: job?.id,
      otp: otp,
      showOnTrip: status == 'in_progress',
      messageLabel: l10n.message,
      callLabel: l10n.callProvider,
      cancelLabel: l10n.cancelJob,
      onChat: () => _openChat(job?.id),
      onCall: () => _callProvider(provider?.phone),
      onTrip: () => context.push('/in-progress'),
      onCancel: _cancelJob,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _liveMap(),
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _BackButton(),
              ),
            ),
          ),
          Positioned.fill(
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: _onSheet,
              child: DraggableScrollableSheet(
                initialChildSize: _snapPeek,
                minChildSize: _snapPeek,
                maxChildSize: _snapMax,
                snap: true,
                snapSizes: _snaps,
                builder: (context, controller) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.obsidian.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: AppColors.modal,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SafeArea(
                        top: false,
                        child: ListView(
                          controller: controller,
                          primary: false,
                          padding: EdgeInsets.zero,
                          children: [
                            const SizedBox(height: 8),
                            const _SheetHandle(),
                            const SizedBox(height: 8),
                            sheet,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, child) {
              if (extent > 0.78) return const SizedBox.shrink();
              final bottom = MediaQuery.sizeOf(context).height * extent + 16;
              return Positioned(
                right: 16,
                bottom: bottom,
                child: child!,
              );
            },
            child: _MapCircleButton(
              icon: Icons.my_location_rounded,
              onTap: _recenter,
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

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return _MapCircleButton(
      icon: Icons.arrow_back_rounded,
      onTap: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.modal,
      shape: CircleBorder(side: BorderSide(color: AppColors.divider)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
        child: const SizedBox(width: 36, height: 4),
      ),
    );
  }
}

class _EnRouteBody extends StatelessWidget {
  const _EnRouteBody({
    required this.etaHeadline,
    required this.primaryMinHeight,
    required this.name,
    required this.avatarUrl,
    required this.ratingLabel,
    required this.vehicleLine,
    required this.plate,
    required this.distance,
    required this.fare,
    required this.pickup,
    required this.dropoff,
    required this.jobId,
    required this.otp,
    required this.showOnTrip,
    required this.messageLabel,
    required this.callLabel,
    required this.cancelLabel,
    required this.onChat,
    required this.onCall,
    required this.onTrip,
    required this.onCancel,
  });

  final String etaHeadline;
  final double primaryMinHeight;
  final String name;
  final String? avatarUrl;
  final String ratingLabel;
  final String vehicleLine;
  final String plate;
  final String distance;
  final String fare;
  final String pickup;
  final String dropoff;
  final String? jobId;
  final String otp;
  final bool showOnTrip;
  final String messageLabel;
  final String callLabel;
  final String cancelLabel;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final VoidCallback onTrip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final showRoute = pickup.isNotEmpty || dropoff.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: primaryMinHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  etaHeadline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                    height: 1.05,
                    tabular: true,
                  ),
                ),
                const SizedBox(height: 16),
                _DriverRow(
                  name: name,
                  avatarUrl: avatarUrl,
                  ratingLabel: ratingLabel,
                  vehicleLine: vehicleLine,
                  plate: plate,
                ),
                const SizedBox(height: 16),
                _ActionBar(
                  messageLabel: messageLabel,
                  callLabel: callLabel,
                  jobId: jobId,
                  onChat: onChat,
                  onCall: onCall,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showRoute) ...[
                _RouteTimeline(pickup: pickup, dropoff: dropoff),
                const SizedBox(height: 16),
              ],
              _PaymentTile(distance: distance, fare: fare),
              if (otp.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Recipient OTP',
                  style: RyvoTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  otp,
                  style: RyvoTypography.price(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
              if (showOnTrip) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onTrip,
                  child: Text(
                    'On trip',
                    style: RyvoTypography.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _CancelTripButton(label: cancelLabel, onTap: onCancel),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.name,
    required this.avatarUrl,
    required this.ratingLabel,
    required this.vehicleLine,
    required this.plate,
  });

  final String name;
  final String? avatarUrl;
  final String ratingLabel;
  final String vehicleLine;
  final String plate;

  @override
  Widget build(BuildContext context) {
    final plateText = plate.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DriverAvatar(name: name, url: avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RatingPill(label: ratingLabel),
                ],
              ),
              if (vehicleLine.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  vehicleLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (plateText.isNotEmpty) ...[
          const SizedBox(width: 8),
          _PlateBadge(plate: plateText),
        ],
      ],
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final photo = url?.trim() ?? '';
    final initials = Text(
      _initials(name),
      style: RyvoTypography.heading(
        fontSize: 18,
        color: AppColors.white,
        letterSpacing: -0.4,
      ),
    );
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        borderRadius: BorderRadius.circular(32),
      ),
      child: photo.isEmpty
          ? initials
          : Image.network(
              photo,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => initials,
            ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 14,
              color: AppColors.warning,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: RyvoTypography.eta(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlateBadge extends StatelessWidget {
  const _PlateBadge({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          plate.toUpperCase(),
          style: RyvoTypography.style(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
            height: 1,
            tabular: true,
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.messageLabel,
    required this.callLabel,
    required this.jobId,
    required this.onChat,
    required this.onCall,
  });

  final String messageLabel;
  final String callLabel;
  final String? jobId;
  final VoidCallback onChat;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MessagePill(label: messageLabel, onTap: onChat),
        ),
        const SizedBox(width: 8),
        _CallPill(label: callLabel, onTap: onCall),
        if (jobId != null) ...[
          const SizedBox(width: 8),
          ShareTripButton.hud(jobId: jobId!),
        ],
      ],
    );
  }
}

class _MessagePill extends StatelessWidget {
  const _MessagePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                size: 18,
                color: AppColors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: RyvoTypography.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallPill extends StatelessWidget {
  const _CallPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 48,
            width: 64,
            child: Icon(
              Icons.phone_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.distance, required this.fare});

  final String distance;
  final String fare;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.creditcard,
              size: 20,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment',
                    style: RyvoTypography.style(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance,
                    style: RyvoTypography.distance(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fare,
              style: RyvoTypography.price(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelTripButton extends StatelessWidget {
  const _CancelTripButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.dangerSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: RyvoTypography.style(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.dangerText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    final stops = <String>[
      if (pickup.isNotEmpty) pickup,
      if (dropoff.isNotEmpty) dropoff,
    ];
    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          _RouteStop(
            label: stops[i],
            isPickup: i == 0 && pickup.isNotEmpty,
            showLine: i < stops.length - 1,
          ),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.label,
    required this.isPickup,
    required this.showLine,
  });

  final String label;
  final bool isPickup;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 8,
          child: Column(
            children: [
              const SizedBox(height: 4),
              isPickup
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: AppColors.textPrimary,
                          width: 1.5,
                        ),
                      ),
                      child: const SizedBox(width: 8, height: 8),
                    ),
              if (showLine)
                SizedBox(
                  width: 1.5,
                  height: 24,
                  child: ColoredBox(color: AppColors.divider),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: showLine ? 8 : 0),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RyvoTypography.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _initials(String value) {
  final parts =
      value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) return '?';
  if (list.length == 1) return list.first[0].toUpperCase();
  return '${list.first[0]}${list.last[0]}'.toUpperCase();
}
