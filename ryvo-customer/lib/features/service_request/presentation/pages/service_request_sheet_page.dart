import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/location/driving_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ryvo_map_canvas.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../home/presentation/widgets/map_markers.dart';
import '../../../payment/presentation/widgets/payment_sheet.dart';
import '../../../tracking/presentation/trip_map_providers.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';

class ServiceRequestSheetPage extends ConsumerStatefulWidget {
  const ServiceRequestSheetPage({super.key});

  @override
  ConsumerState<ServiceRequestSheetPage> createState() =>
      _ServiceRequestSheetPageState();
}

class _ServiceRequestSheetPageState
    extends ConsumerState<ServiceRequestSheetPage> {
  Widget? _map;
  int _cameraGeneration = 0;
  final Map<String, FareEstimate> _quotes = {};
  final DrivingRouteService _routes = DrivingRouteService();
  String? _quoteKey;
  String? _routeKey;
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
      final services = ref.read(serviceCategoriesProvider).valueOrNull;
      if (services != null && services.isNotEmpty) {
        _quote(services);
      }
    });
  }

  @override
  void dispose() {
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
        services.isEmpty) return;
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
    _publishMap();
  }

  Future<void> _loadRoute() async {
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null || draft.dropoffLng == null) return;
    final key =
        '${draft.pickupLat.toStringAsFixed(5)},${draft.pickupLng.toStringAsFixed(5)}|'
        '${draft.dropoffLat!.toStringAsFixed(5)},${draft.dropoffLng!.toStringAsFixed(5)}';
    if (_routeKey == key && _routePoints.length > 2) return;
    _routeKey = key;
    final route = await _routes.fetch(
      originLat: draft.pickupLat,
      originLng: draft.pickupLng,
      destinationLat: draft.dropoffLat!,
      destinationLng: draft.dropoffLng!,
    );
    if (!mounted || _routeKey != key) return;
    final minutes = route?.durationMin ?? 0;
    final arrival =
        DateTime.now().add(Duration(minutes: minutes == 0 ? 1 : minutes));
    final pickupIcon = await MapMarkers.buildStopLabel(
      title: 'Pickup',
      subtitle: 'Now',
      color: AppColors.primary,
    );
    final dropoffIcon = await MapMarkers.buildStopLabel(
      title: 'Dropoff',
      subtitle: DateFormat('h:mm a').format(arrival),
      color: AppColors.obsidian,
    );
    if (!mounted || _routeKey != key) return;
    setState(() {
      _routePoints = route?.points ?? const [];
      _routeMinutes = minutes;
      _pickupIcon = pickupIcon;
      _dropoffIcon = dropoffIcon;
    });
    _publishMap();
  }

  void _publishMap() {
    final draft = ref.read(jobDraftProvider);
    final pickup = LatLng(draft.pickupLat, draft.pickupLng);
    final dropoff = draft.dropoffLat == null || draft.dropoffLng == null
        ? null
        : LatLng(draft.dropoffLat!, draft.dropoffLng!);
    final points = _routePoints.length > 1
        ? _routePoints
        : [
            pickup,
            if (dropoff != null) dropoff,
          ];
    ref.read(tripMarkersProvider(TripMapScope.request).notifier).state = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: _pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 1),
      ),
      if (dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: dropoff,
          icon: _dropoffIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1),
        ),
    };
    ref.read(tripPolylinesProvider(TripMapScope.request).notifier).state = {
      if (dropoff != null && points.length > 1) ...{
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
      },
    };
    ref.read(tripCameraProvider(TripMapScope.request).notifier).state =
        cameraForPoints(
      points,
      generation: ++_cameraGeneration,
      zoom: 13,
      fallback: pickup,
    );
  }

  Widget _requestMap(BuildContext context) {
    return _map ??= RyvoMapCanvas(
      markers: tripMarkersProvider(TripMapScope.request),
      polylines: tripPolylinesProvider(TripMapScope.request),
      camera: tripCameraProvider(TripMapScope.request),
      padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * 0.5),
      boundsPadding: 72,
    );
  }

  Future<void> _editPickup() async {
    final applied =
        await showPickupLocationPicker(context: context, autofocusSearch: true);
    if (!applied || !mounted) return;
    _quoteKey = null;
    final services = ref.read(serviceCategoriesProvider).valueOrNull ??
        const <ServiceCategory>[];
    await _quote(services);
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
      final route = await showRyvoCheckoutSheet(context);
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(jobDraftProvider);
    final servicesAsync = ref.watch(serviceCategoriesProvider);
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final methods = _enabledMethods(config);
    ref.listen<AsyncValue<List<ServiceCategory>>>(serviceCategoriesProvider,
        (_, next) {
      next.whenData(_quote);
    });

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _RouteBar(
                  pickup: _shortPlace(draft.pickupAddress),
                  dropoff: _shortPlace(draft.dropoffAddress),
                  onClose: _confirming ? null : _handleBack,
                  onPickup: _confirming ? null : _editPickup,
                  onDropoff: _confirming ? null : _editDropoff,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.58),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.obsidian.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: servicesAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                        error: (_, __) => Center(
                          child: TextButton(
                            onPressed: () =>
                                ref.invalidate(serviceCategoriesProvider),
                            child: Text(AppLocalizations.of(context)
                                .couldNotLoadServicesTapToRetry),
                          ),
                        ),
                        data: (services) {
                          return Column(
                            children: [
                              _ChooseRideHeader(jobType: draft.jobType),
                              Expanded(
                                child: _RideList(
                                  services: services,
                                  quotes: _quotes,
                                  quoting: _quoting,
                                  routeMinutes: _routeMinutes,
                                  selectedId: _selected?.id,
                                  onSelect: (service) =>
                                      setState(() => _selected = service),
                                  onRetry: () {
                                    _quoteKey = null;
                                    _quote(services);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (draft.jobType == 'parcel')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          children: [
                            TextField(
                              controller: _recipientName,
                              decoration: const InputDecoration(
                                  labelText: 'Recipient name'),
                            ),
                            TextField(
                              controller: _recipientPhone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Recipient phone'),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Parcel size',
                                style: RyvoTypography.style(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final size in const [
                                  'small',
                                  'medium',
                                  'large'
                                ])
                                  ChoiceChip(
                                    label: Text(size[0].toUpperCase() +
                                        size.substring(1)),
                                    selected: _parcelSize == size,
                                    onSelected: (_) =>
                                        setState(() => _parcelSize = size),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (draft.jobType == 'bidding' &&
                        _selected != null &&
                        _quotes[_selected!.id] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Builder(builder: (context) {
                          final suggested =
                              _quotes[_selected!.id]!.estimatedFare;
                          final config =
                              ref.read(appConfigProvider).valueOrNull ??
                                  AppConfig.fallback;
                          final min = suggested * config.bidMinFareRatio;
                          final max = suggested * config.bidMaxFareRatio;
                          final value =
                              (_offerPrice ?? suggested).clamp(min, max);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your offer: ${value.toStringAsFixed(2)}',
                                style: RyvoTypography.price(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Slider(
                                min: min,
                                max: max <= min ? min + 1 : max,
                                value: value,
                                onChanged: (v) =>
                                    setState(() => _offerPrice = v),
                              ),
                            ],
                          );
                        }),
                      ),
                    if (methods.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          AppLocalizations.of(context)
                              .noPaymentMethodsAreCurrentlyAvailablePleaseConta,
                          style: RyvoTypography.style(
                              fontSize: 12, color: AppColors.error),
                        ),
                      )
                    else
                      InkWell(
                        onTap: _confirming ? null : () => _pickPayment(methods),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                          child: Row(
                            children: [
                              _PaymentChip(method: _payment),
                              const SizedBox(width: 8),
                              Text(
                                _payment == null
                                    ? AppLocalizations.of(context)
                                        .choosePaymentMethod
                                    : _paymentLabel(context, _payment!),
                                style: RyvoTypography.style(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 18, color: AppColors.grey500),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: SafeArea(
                        top: false,
                        child: _RequestRideButton(
                          label: _requestLabel(draft.jobType),
                          price: _buttonPrice(draft.jobType),
                          loading: _confirming || _quoting,
                          onPressed: _confirming ||
                                  _quoting ||
                                  _selected == null ||
                                  _payment == null
                              ? null
                              : _confirm,
                        ),
                      ),
                    ),
                  ],
                ),
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
    final picked = await showRyvoPaymentSheet(
      context,
      selected: _payment,
      methods: methods,
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  String _shortPlace(String address) {
    final part = address.split(',').first.trim();
    if (part.isEmpty) return address;
    if (part.length <= 22) return part;
    return '${part.substring(0, 21)}…';
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
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 13,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Best rates',
                    style: RyvoTypography.style(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
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

class _RideList extends StatelessWidget {
  const _RideList({
    required this.services,
    required this.quotes,
    required this.quoting,
    required this.routeMinutes,
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
  });

  final List<ServiceCategory> services;
  final Map<String, FareEstimate> quotes;
  final bool quoting;
  final int routeMinutes;
  final String? selectedId;
  final ValueChanged<ServiceCategory> onSelect;
  final VoidCallback onRetry;

  int _seats(String? slug) => switch (slug) {
        'van' => 8,
        'xl' => 6,
        _ => 4,
      };

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Text(
          'No rides are available right now',
          style: RyvoTypography.style(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      itemCount: services.length + (quoting ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (quoting && index == 0) {
          return const LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
          );
        }
        final serviceIndex = quoting ? index - 1 : index;
        final service = services[serviceIndex];
        final estimate = quotes[service.id];
        final selected = service.id == selectedId;
        final minutes =
            routeMinutes > 0 ? routeMinutes : (estimate?.durationMin ?? 0);
        final description = (service.description ?? '').trim();
        final borderColor = selected
            ? (AppColors.isDark ? AppColors.white : AppColors.obsidian)
            : Colors.transparent;
        return Material(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap:
                estimate == null && !quoting ? null : () => onSelect(service),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Row(
                children: [
                  _RideCar(service: service),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                service.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RyvoTypography.style(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            Text(
                              '${_seats(service.slug)}',
                              style: RyvoTypography.distance(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RyvoTypography.style(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.15,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (estimate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatMoney(estimate.estimatedFare),
                          style: RyvoTypography.price(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (minutes > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$minutes min',
                              style: RyvoTypography.eta(
                                fontSize: 11,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  else if (quoting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppLocalizations.of(context).retry,
                        style: RyvoTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RideCar extends StatelessWidget {
  const _RideCar({required this.service});

  final ServiceCategory service;

  String? get _asset {
    if (service.slug.startsWith('parcel') || service.businessType == 'parcel')
      return null;
    return switch (service.slug) {
      'comfort' => 'assets/images/ride_comfort.png',
      'xl' || 'van' || 'assist' || 'premium' => 'assets/images/ride_xl.png',
      _ => 'assets/images/ride_go.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    return SizedBox(
      width: 72,
      height: 40,
      child: asset == null
          ? Icon(serviceIcon(service.slug, service.icon),
              color: AppColors.navy, size: 26)
          : Image.asset(asset,
              fit: BoxFit.contain, filterQuality: FilterQuality.medium),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.method});

  final String? method;

  @override
  Widget build(BuildContext context) {
    final card = method == null ||
        method == 'stripe' ||
        method == 'google_pay' ||
        method == 'apple_pay';
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: card ? AppColors.obsidian : AppColors.surface,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        switch (method) {
          'wallet' => 'WALLET',
          'cash' => 'CASH',
          'apple_pay' => 'APPLE',
          'google_pay' => 'G PAY',
          _ => 'CARD',
        },
        style: RyvoTypography.style(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: card ? AppColors.white : AppColors.textPrimary,
          height: 1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _RequestRideButton extends StatelessWidget {
  const _RequestRideButton({
    required this.label,
    required this.price,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final String? price;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: enabled ? AppColors.cta : AppColors.cta.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onCta,
                    ),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.onCta,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: RyvoTypography.button(
                            fontSize: 15,
                            color: AppColors.onCta,
                          ),
                        ),
                      ],
                    ),
                    if (price != null)
                      Positioned(
                        right: 16,
                        child: Row(
                          children: [
                            Container(
                              width: 1,
                              height: 16,
                              color: AppColors.onCta.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              price!,
                              style: RyvoTypography.price(
                                fontSize: 15,
                                color: AppColors.onCta,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.modal,
      elevation: 0,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidian.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
              color: AppColors.textPrimary,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RouteStop(
                    marker: const _PickupDot(),
                    label: pickup,
                    onTap: onPickup,
                  ),
                  const _RouteConnector(),
                  _RouteStop(
                    marker: const _DropoffMark(),
                    label: dropoff,
                    onTap: onDropoff,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.marker,
    required this.label,
    required this.onTap,
  });

  final Widget marker;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: Center(child: marker)),
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
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Center(
              child: SizedBox(
                width: 1.5,
                height: 12,
                child: ColoredBox(color: AppColors.divider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupDot extends StatelessWidget {
  const _PickupDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DropoffMark extends StatelessWidget {
  const _DropoffMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
