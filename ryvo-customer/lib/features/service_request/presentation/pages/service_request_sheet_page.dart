import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/location/driving_route.dart';
import '../../../../core/location/route_flow.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../home/presentation/widgets/map_markers.dart';
import '../../../payment/presentation/pages/payment_options_page.dart';
import '../../../tracking/presentation/trip_map_providers.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/action_dock.dart';
import '../widgets/bid_controls.dart';
import '../widgets/parcel_fields.dart';
import '../widgets/ride_tile.dart';

class ServiceRequestSheetPage extends ConsumerStatefulWidget {
  const ServiceRequestSheetPage({super.key});

  @override
  ConsumerState<ServiceRequestSheetPage> createState() =>
      _ServiceRequestSheetPageState();
}

class _ServiceRequestSheetPageState
    extends ConsumerState<ServiceRequestSheetPage> {
  static const double _snapMin = 0.38;
  static const double _snapMid = 0.56;
  static const double _snapMax = 0.88;
  static const List<double> _snaps = [_snapMin, _snapMid, _snapMax];

  Widget? _map;
  ValueNotifier<EdgeInsets>? _mapPadding;
  List<LatLng>? _flowPoints;
  int _routeGeneration = 0;
  Timer? _settleTimer;
  int _snapIndex = 1;
  int _cameraGeneration = 0;
  final Map<String, FareEstimate> _quotes = {};
  final DrivingRouteService _routes = DrivingRouteService();
  String? _quoteKey;
  String? _routeKey;
  String? _routeLoadingKey;
  bool _quoting = false;
  bool _confirming = false;
  ServiceCategory? _selected;
  String? _payment;
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  String _parcelSize = 'small';
  double? _offerPrice;
  List<LatLng> _routePoints = const [];
  int _routeMinutes = 0;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final draft = ref.read(jobDraftProvider);
      if (draft.dropoffLat == null || draft.dropoffAddress.trim().isEmpty) {
        if (mounted) context.go('/home');
        return;
      }
      _initPayment();
      ref.invalidate(serviceCategoriesProvider);
      // Warm the bitmaps and the route while the tiers are still quoting.
      unawaited(_loadRoute());
      final services = ref.read(serviceCategoriesProvider).valueOrNull;
      if (services != null && services.isNotEmpty) {
        _quote(services);
      }
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _mapPadding?.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    super.dispose();
  }

  void _initPayment() {
    final config =
        ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final methods = _enabledMethods(config);
    final draftMethod = ref.read(jobDraftProvider).paymentMethod;
    if (!mounted) return;
    setState(() {
      _payment = methods.contains(draftMethod)
          ? draftMethod
          : (methods.isNotEmpty ? methods.first : null);
    });
  }

  List<String> _enabledMethods(AppConfig config) => [
        if (config.walletPaymentEnabled) 'wallet',
        if (config.paymentMethods.stripe) 'stripe',
        if (config.paymentMethods.cash) 'cash',
      ];

  String _quoteIdentity(JobRequestDraft draft, List<ServiceCategory> services) {
    return '${draft.pickupLat.toStringAsFixed(5)},${draft.pickupLng.toStringAsFixed(5)}|'
        '${draft.dropoffLat},${draft.dropoffLng}|'
        '${services.map((service) => service.id).join(',')}';
  }

  Future<void> _quote(List<ServiceCategory> services) async {
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null ||
        draft.dropoffLng == null ||
        services.isEmpty) {
      return;
    }
    final key = _quoteIdentity(draft, services);
    if (_quoteKey == key && _quotes.isNotEmpty) return;
    _quoteKey = key;
    setState(() => _quoting = true);

    final results = await Future.wait(services.map((service) async {
      try {
        final estimate = await ref.read(jobRepositoryProvider).estimateFare(
              serviceCategoryId: service.id,
              pickupLat: draft.pickupLat,
              pickupLng: draft.pickupLng,
              dropoffLat: draft.dropoffLat!,
              dropoffLng: draft.dropoffLng!,
            );
        return MapEntry(service.id, estimate);
      } catch (_) {
        return MapEntry(service.id, null);
      }
    }));

    if (!mounted || _quoteKey != key) return;
    final quotes = <String, FareEstimate>{
      for (final entry in results)
        if (entry.value != null) entry.key: entry.value!,
    };
    ServiceCategory? selected = _selected;
    final stillListed = selected != null &&
        services.any((service) => service.id == selected!.id) &&
        quotes.containsKey(selected.id);
    if (!stillListed) {
      selected = null;
      for (final service in services) {
        if (quotes.containsKey(service.id)) {
          selected = service;
          break;
        }
      }
      selected ??= services.isEmpty ? null : services.first;
    }
    setState(() {
      _quoting = false;
      _quotes
        ..clear()
        ..addAll(quotes);
      _selected = selected;
    });
    await _loadRoute();
    if (!mounted) return;
    _publishMap();
  }

  Future<void> _loadPickupIcon() async {
    final icon = await MapMarkers.buildStopNode(
      kind: MapStopKind.pickup,
    );
    if (!mounted) return;
    _pickupIcon = icon;
    _publishMarkers();
  }

  Future<void> _loadRoute() async {
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null || draft.dropoffLng == null) return;
    final key =
        '${draft.pickupLat.toStringAsFixed(5)},${draft.pickupLng.toStringAsFixed(5)}|'
        '${draft.dropoffLat!.toStringAsFixed(5)},${draft.dropoffLng!.toStringAsFixed(5)}';
    if (_routeKey == key &&
        (_routeLoadingKey == key || _routePoints.length > 2)) {
      return;
    }
    if (_routeKey != key) {
      // The old dropoff pill describes a different trip; hide it until the
      // new one is drawn.
      _dropoffIcon = null;
      _publishMarkers();
      unawaited(_loadPickupIcon());
    }
    _routeKey = key;
    _routeLoadingKey = key;
    try {
      final route = await _routes.fetch(
        originLat: draft.pickupLat,
        originLng: draft.pickupLng,
        destinationLat: draft.dropoffLat!,
        destinationLng: draft.dropoffLng!,
      );
      if (!mounted || _routeKey != key) return;
      final minutes = route?.durationMin ?? 0;
      final dropoffIcon = await MapMarkers.buildStopNode(
        kind: MapStopKind.dropoff,
        badge: minutes > 0 ? '$minutes min' : null,
      );
      if (!mounted || _routeKey != key) return;
      setState(() {
        _routePoints = route?.points ?? const [];
        _routeMinutes = minutes;
        _dropoffIcon = dropoffIcon;
      });
      // Clear first: while a route is loading, _publishRoute holds back the
      // straight-line fallback so it never flashes before the real road.
      _routeLoadingKey = null;
      _publishMap();
    } finally {
      if (_routeLoadingKey == key) _routeLoadingKey = null;
    }
  }

  void _publishMap() {
    _publishMarkers();
    _publishRoute();
    _publishCamera();
  }

  LatLng get _pickupLatLng {
    final draft = ref.read(jobDraftProvider);
    return LatLng(draft.pickupLat, draft.pickupLng);
  }

  LatLng? get _dropoffLatLng {
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null || draft.dropoffLng == null) return null;
    return LatLng(draft.dropoffLat!, draft.dropoffLng!);
  }

  List<LatLng> get _displayPoints {
    final dropoff = _dropoffLatLng;
    if (_routePoints.length > 1) return _routePoints;
    return [_pickupLatLng, if (dropoff != null) dropoff];
  }

  /// Markers appear only once their bitmap exists, so no stock pin ever shows.
  void _publishMarkers() {
    final pickupIcon = _pickupIcon;
    final dropoffIcon = _dropoffIcon;
    final dropoff = _dropoffLatLng;
    ref.read(tripMarkersProvider(TripMapScope.request).notifier).state = {
      if (pickupIcon != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLatLng,
          icon: pickupIcon,
          anchor: MapMarkers.stopAnchor,
          zIndexInt: 2,
        ),
      if (dropoff != null && dropoffIcon != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: dropoffIcon,
          anchor: MapMarkers.stopAnchor,
          zIndexInt: 1,
        ),
    };
  }

  void _publishRoute() {
    final points = _displayPoints;
    if (_dropoffLatLng == null || points.length < 2) {
      if (_flowPoints == null) return;
      _flowPoints = null;
      ref.read(tripRouteFlowProvider(TripMapScope.request).notifier).state =
          null;
      ref.read(tripPolylinesProvider(TripMapScope.request).notifier).state =
          const {};
      return;
    }
    // While the road is loading, do not draw the straight-line fallback.
    if (_routeLoadingKey != null && _routePoints.length < 2) return;
    // Publishing the same road again must not restart the reveal.
    if (RouteFlow.sameRoute(points, _flowPoints)) return;
    _flowPoints = points;
    // The overlay reveals and pulses the route; the map only gets the two
    // static polylines, once. No animation frame touches the platform channel.
    ref.read(tripRouteFlowProvider(TripMapScope.request).notifier).state =
        RouteFlow(points: points, generation: ++_routeGeneration);
    ref.read(tripPolylinesProvider(TripMapScope.request).notifier).state =
        RouteStyle.polylines(points);
  }

  void _publishCamera() {
    ref.read(tripCameraProvider(TripMapScope.request).notifier).state =
        cameraForPoints(
      _displayPoints,
      generation: ++_cameraGeneration,
      zoom: 13,
      fallback: _pickupLatLng,
    );
  }

  Widget _requestMap(BuildContext context) {
    final padding = _mapPadding ??= ValueNotifier(_paddingFor(_snapMid));
    return _map ??= RyvoMapCanvas(
      markers: tripMarkersProvider(TripMapScope.request),
      polylines: tripPolylinesProvider(TripMapScope.request),
      routeFlow: tripRouteFlowProvider(TripMapScope.request),
      camera: tripCameraProvider(TripMapScope.request),
      paddingListenable: padding,
      boundsPadding: 40,
    );
  }

  /// Keeps the route between the compact route bar and the top of the sheet.
  EdgeInsets _paddingFor(double sheetFraction) {
    return EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + _RouteBar.clearance,
      bottom: MediaQuery.sizeOf(context).height * sheetFraction,
    );
  }

  int _nearestSnap(double extent) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < _snaps.length; i++) {
      final d = (extent - _snaps[i]).abs();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  /// Clicks when the drag crosses the midpoint toward another snap size, and
  /// re-centers the route once the sheet stops moving.
  bool _onSheetNotification(DraggableScrollableNotification notification) {
    final index = _nearestSnap(notification.extent);
    if (index != _snapIndex) {
      _snapIndex = index;
      HapticFeedback.selectionClick();
    }
    _settleTimer?.cancel();
    _settleTimer = Timer(
      const Duration(milliseconds: 160),
      () => _settleMap(notification.extent),
    );
    return false;
  }

  /// The map only needs to clear the sheet up to its default height; dragging
  /// higher covers the map instead of squeezing the route. Applying the value
  /// once per settle keeps the camera from jittering during the drag.
  void _settleMap(double extent) {
    final notifier = _mapPadding;
    if (!mounted || notifier == null) return;
    final fraction = extent.clamp(_snapMin, _snapMid).toDouble();
    final next = _paddingFor(fraction);
    if ((notifier.value.bottom - next.bottom).abs() < 1) return;
    notifier.value = next;
    // Let the new padding reach the platform view before the camera moves.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publishCamera();
    });
  }

  Future<void> _editPickup() async {
    final applied =
        await showPickupLocationPicker(context: context, autofocusSearch: true);
    if (!applied || !mounted) return;
    _quoteKey = null;
    final services = ref.read(serviceCategoriesProvider).valueOrNull ??
        const <ServiceCategory>[];
    await _quote(services);
    if (!mounted) return;
    _publishMap();
  }

  Future<void> _editDropoff() async {
    final applied = await showPickupLocationPicker(
      context: context,
      autofocusSearch: true,
      forDropoff: true,
    );
    if (!applied || !mounted) return;
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null || draft.dropoffAddress.trim().isEmpty) {
      context.go('/home');
      return;
    }
    _quoteKey = null;
    final services = ref.read(serviceCategoriesProvider).valueOrNull ??
        const <ServiceCategory>[];
    await _quote(services);
    if (!mounted) return;
    _publishMap();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    final draft = ref.read(jobDraftProvider);
    if (selected == null) {
      showApiError(context, l10n.pleaseSelectAService);
      return;
    }
    final estimate = _quotes[selected.id];
    if (estimate == null) {
      showApiError(context, l10n.missingServiceDetails);
      return;
    }
    if (draft.dropoffLat == null || draft.dropoffLng == null) {
      showApiError(context, 'Choose a dropoff before continuing');
      return;
    }
    if (!isPickupLocationReady(draft)) {
      showApiError(context, l10n.confirmYourAssistanceAddressFirst);
      return;
    }
    if (_payment == null) {
      showApiError(context, l10n.noPaymentMethodsAreAvailable);
      return;
    }
    if (draft.jobType == 'parcel' &&
        (_recipientName.text.trim().isEmpty ||
            _recipientPhone.text.trim().isEmpty)) {
      showApiError(context, 'Enter the recipient name and phone');
      return;
    }

    setState(() => _confirming = true);
    try {
      final covered = await ensureCustomerCoverage(
        context,
        ref,
        lat: draft.pickupLat,
        lng: draft.pickupLng,
        addressLabel: draft.pickupAddress,
      );
      if (!covered || !mounted) return;
      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(
                serviceCategory: selected,
                estimate: estimate,
                paymentMethod: _payment!,
                offeredPrice: draft.jobType == 'bidding'
                    ? (_offerPrice ?? estimate.estimatedFare)
                    : null,
                recipientName: _recipientName.text.trim(),
                recipientPhone: _recipientPhone.text.trim(),
                parcelSize: _parcelSize,
              );
      if (!mounted) return;
      final route = await showRyvoCheckout(context);
      if (!mounted) return;
      if (route != null) context.go(route);
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _handleBack() {
    if (_confirming) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// "Best value" goes to the cheapest quoted tier and "Fastest" to a tier
  /// with a strictly shorter ETA. Needs two quoted tiers to mean anything.
  Map<String, String> _badges(List<ServiceCategory> services) {
    final quoted =
        services.where((service) => _quotes.containsKey(service.id)).toList();
    if (quoted.length < 2) return const {};
    final cheapest = quoted.reduce((a, b) =>
        _quotes[b.id]!.estimatedFare < _quotes[a.id]!.estimatedFare ? b : a);
    final badges = <String, String>{cheapest.id: 'Best value'};
    final timed = quoted
        .where((service) => _quotes[service.id]!.durationMin > 0)
        .toList();
    if (timed.length >= 2) {
      final fastest = timed.reduce((a, b) =>
          _quotes[b.id]!.durationMin < _quotes[a.id]!.durationMin ? b : a);
      final unique = timed.every((service) =>
          service.id == fastest.id ||
          _quotes[service.id]!.durationMin > _quotes[fastest.id]!.durationMin);
      if (unique && fastest.id != cheapest.id) badges[fastest.id] = 'Fastest';
    }
    return badges;
  }

  List<Widget> _sheetSlivers({
    required BuildContext context,
    required String jobType,
    required AsyncValue<List<ServiceCategory>> servicesAsync,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _SheetHeaderDelegate(jobType: jobType),
      ),
      ...servicesAsync.when<List<Widget>>(
        loading: () => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const RideTileSkeleton(),
                childCount: 3,
              ),
            ),
          ),
        ],
        error: (_, __) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(serviceCategoriesProvider),
                  child: Text(l10n.couldNotLoadServicesTapToRetry),
                ),
              ),
            ),
          ),
        ],
        data: (services) {
          if (services.isEmpty) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No rides are available right now',
                      style: RyvoTypography.style(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ];
          }
          final badges = _badges(services);
          return [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) return const SizedBox(height: 8);
                    final service = services[index ~/ 2];
                    return RideTile(
                      key: ValueKey(service.id),
                      service: service,
                      estimate: _quotes[service.id],
                      quoting: _quoting,
                      routeMinutes: _routeMinutes,
                      selected: service.id == _selected?.id,
                      badge: badges[service.id],
                      retryLabel: l10n.retry,
                      onSelect: () => setState(() => _selected = service),
                      onRetry: () {
                        _quoteKey = null;
                        _quote(services);
                      },
                    );
                  },
                  childCount: services.length * 2 - 1,
                ),
              ),
            ),
          ];
        },
      ),
      if (jobType == 'parcel')
        SliverToBoxAdapter(
          child: ParcelFields(
            nameController: _recipientName,
            phoneController: _recipientPhone,
            size: _parcelSize,
            onSize: (size) => setState(() => _parcelSize = size),
          ),
        ),
      if (jobType == 'bidding' &&
          _selected != null &&
          _quotes[_selected!.id] != null)
        SliverToBoxAdapter(child: _bidControls(_quotes[_selected!.id]!)),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
  }

  Widget _bidControls(FareEstimate estimate) {
    final config =
        ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final suggested = estimate.estimatedFare;
    final min = suggested * config.bidMinFareRatio;
    final max = suggested * config.bidMaxFareRatio;
    final value = (_offerPrice ?? suggested).clamp(min, max).toDouble();
    return BidControls(
      suggested: suggested,
      min: min,
      max: max,
      value: value,
      onChanged: (next) => setState(() => _offerPrice = next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobType = ref.watch(jobDraftProvider.select((d) => d.jobType));
    final pickupAddress =
        ref.watch(jobDraftProvider.select((d) => d.pickupAddress));
    final dropoffAddress =
        ref.watch(jobDraftProvider.select((d) => d.dropoffAddress));
    final servicesAsync = ref.watch(serviceCategoriesProvider);
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final methods = _enabledMethods(config);
    final l10n = AppLocalizations.of(context);
    ref.listen<AsyncValue<List<ServiceCategory>>>(serviceCategoriesProvider,
        (_, next) {
      next.whenData(_quote);
    });

    // DraggableScrollableSheet re-runs its builder on every drag frame. The
    // slivers and the dock are built once per state change and only handed
    // through, so a drag reconciles identical widgets instead of rebuilding
    // the tier list 60-120 times a second.
    final slivers = _sheetSlivers(
      context: context,
      jobType: jobType,
      servicesAsync: servicesAsync,
    );
    final dock = RequestActionDock(
      paymentMethod: _payment,
      paymentLabel: _payment == null
          ? l10n.choosePaymentMethod
          : _paymentLabel(context, _payment!),
      noMethodsLabel: methods.isEmpty
          ? l10n.noPaymentMethodsAreCurrentlyAvailablePleaseConta
          : null,
      onPickPayment: _confirming ? null : () => _pickPayment(methods),
      buttonLabel: _buttonLabel(jobType),
      buttonPrice: _buttonPrice(jobType),
      loading: _confirming || _quoting,
      onPressed:
          _confirming || _quoting || _selected == null || _payment == null
              ? null
              : _confirm,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            _requestMap(context),
            SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _RouteBar(
                    pickup: _shortPlace(pickupAddress),
                    dropoff: _shortPlace(dropoffAddress),
                    onClose: _confirming ? null : _handleBack,
                    onPickup: _confirming ? null : _editPickup,
                    onDropoff: _confirming ? null : _editDropoff,
                  ),
                ),
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: _onSheetNotification,
              child: DraggableScrollableSheet(
                initialChildSize: _snapMid,
                minChildSize: _snapMin,
                maxChildSize: _snapMax,
                snap: true,
                snapSizes: _snaps,
                builder: (context, scrollController) {
                  const radius = BorderRadius.vertical(
                    top: Radius.circular(20),
                  );
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.modal,
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.obsidian.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        children: [
                          Expanded(
                            child: CustomScrollView(
                              controller: scrollController,
                              slivers: slivers,
                            ),
                          ),
                          dock,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _requestLabel(String jobType) {
    return switch (jobType) {
      'parcel' => 'Send a parcel',
      'bidding' => 'Place a bid',
      _ => 'Request ride',
    };
  }

  String _buttonLabel(String jobType) {
    final selected = _selected;
    if (selected == null) return _requestLabel(jobType);
    return switch (jobType) {
      'parcel' => 'Send with ${selected.name}',
      'bidding' => 'Bid on ${selected.name}',
      _ => 'Choose ${selected.name}',
    };
  }

  String? _buttonPrice(String jobType) {
    final selected = _selected;
    if (selected == null) return null;
    final estimate = _quotes[selected.id];
    if (estimate == null) return null;
    final amount = jobType == 'bidding'
        ? (_offerPrice ?? estimate.estimatedFare)
        : estimate.estimatedFare;
    return formatMoney(amount);
  }

  Future<void> _pickPayment(List<String> methods) async {
    final picked = await showRyvoPaymentOptions(
      context,
      selected: _payment,
      methods: methods,
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  String _shortPlace(String address) {
    final part = address.split(',').first.trim();
    return part.isEmpty ? address : part;
  }

  String _paymentLabel(BuildContext context, String method) {
    final l10n = AppLocalizations.of(context);
    return switch (method) {
      'wallet' => 'Ryvo balance',
      'cash' => l10n.cash,
      'google_pay' => l10n.googlePay,
      'apple_pay' => l10n.applePay,
      _ => l10n.card,
    };
  }
}

/// Pinned drag handle and title, so the sheet can always be grabbed.
class _SheetHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SheetHeaderDelegate({required this.jobType});

  final String jobType;

  static const double _extent = 84;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.modal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _ChooseRideHeader(jobType: jobType),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SheetHeaderDelegate oldDelegate) =>
      oldDelegate.jobType != jobType;
}

class _ChooseRideHeader extends StatelessWidget {
  const _ChooseRideHeader({required this.jobType});

  final String jobType;

  @override
  Widget build(BuildContext context) {
    final title = switch (jobType) {
      'parcel' => 'Send a parcel',
      'bidding' => 'Name your price',
      _ => 'Choose your ride',
    };
    final subtitle = switch (jobType) {
      'parcel' => 'Delivered to their door',
      'bidding' => 'Drivers accept your offer',
      _ => 'Fast, safe and reliable',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RyvoTypography.heading(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
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
          if (jobType != 'parcel' && jobType != 'bidding')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.isDark
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 13,
                    color: AppColors.isDark
                        ? AppColors.primary
                        : AppColors.primaryDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Best rates',
                    style: RyvoTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.isDark
                          ? AppColors.primary
                          : AppColors.primaryDark,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact floating header: a 40px back button beside pickup and dropoff.
class _RouteBar extends StatelessWidget {
  const _RouteBar({
    required this.pickup,
    required this.dropoff,
    required this.onClose,
    required this.onPickup,
    required this.onDropoff,
  });

  final String pickup;
  final String dropoff;
  final VoidCallback? onClose;
  final VoidCallback? onPickup;
  final VoidCallback? onDropoff;

  static const double rowHeight = 36;
  static const double dividerSlot = 8;
  static const double node = 8;
  static const double verticalPadding = 10;

  /// Address rows plus the divider slot. Nodes are centered on each row.
  static const double contentHeight = rowHeight * 2 + dividerSlot;

  /// Card chrome. Stays under the map clearance used by the camera.
  static const double height = contentHeight + verticalPadding * 2;

  /// Safe-area padding around the bar, the card, and a gap before the route.
  static const double clearance = 8 + height + 8 + 16;

  /// Distance from a row edge to an 8px node so the node sits on the row center.
  static const double nodeInset = (rowHeight - node) / 2;

  /// Line starts at the bottom of the pickup node and ends at the top of the square.
  static const double lineInset = nodeInset + node;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _RouteBackButton(onTap: onClose),
        const SizedBox(width: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.modal,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.obsidian.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    12, verticalPadding, 10, verticalPadding),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        width: 20,
                        child: _RouteTimeline(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RouteAddressRow(
                              semanticsLabel: 'Pickup',
                              label: pickup,
                              onTap: onPickup,
                            ),
                            SizedBox(
                              height: dividerSlot,
                              child: Center(
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.divider,
                                ),
                              ),
                            ),
                            _RouteAddressRow(
                              semanticsLabel: 'Dropoff',
                              label: dropoff,
                              onTap: onDropoff,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteBackButton extends StatelessWidget {
  const _RouteBackButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              CupertinoIcons.arrow_left,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteAddressRow extends StatelessWidget {
  const _RouteAddressRow({
    required this.semanticsLabel,
    required this.label,
    required this.onTap,
  });

  final String semanticsLabel;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$semanticsLabel, $label',
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          height: _RouteBar.rowHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pickup circle, a 1.5px connector, and a dropoff square. Each node is
/// centered on its 36px address row; the line runs only between the nodes.
class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline();

  @override
  Widget build(BuildContext context) {
    final square = AppColors.isDark ? AppColors.white : AppColors.obsidian;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: _RouteBar.nodeInset),
        const _RouteNode(color: AppColors.primary, circle: true),
        SizedBox(
          height: _RouteBar.contentHeight - _RouteBar.lineInset * 2,
          width: 1.5,
          child: ColoredBox(color: AppColors.divider),
        ),
        _RouteNode(color: square, circle: false),
        const SizedBox(height: _RouteBar.nodeInset),
      ],
    );
  }
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({required this.color, required this.circle});

  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _RouteBar.node,
      height: _RouteBar.node,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}
