import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/location/driving_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/map_style_utils.dart';
import '../../../../data/models/app_config.dart';
import '../../../../data/models/models.dart';
import '../../../home/presentation/widgets/map_markers.dart';
import '../../../payment/presentation/widgets/payment_sheet.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';

class ServiceRequestSheetPage extends ConsumerStatefulWidget {
  const ServiceRequestSheetPage({super.key});

  @override
  ConsumerState<ServiceRequestSheetPage> createState() => _ServiceRequestSheetPageState();
}

class _ServiceRequestSheetPageState extends ConsumerState<ServiceRequestSheetPage> {
  GoogleMapController? _mapController;
  final Map<String, FareEstimate> _quotes = {};
  final DrivingRouteService _routes = DrivingRouteService();
  String? _quoteKey;
  String? _routeKey;
  bool _quoting = false;
  bool _confirming = false;
  ServiceCategory? _selected;
  String? _payment;
  String _sort = 'recommended';
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  String _parcelSize = 'small';
  double? _offerPrice;
  List<LatLng> _routePoints = const [];
  int _routeMinutes = 0;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  static const _mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"simplified"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
    {"featureType":"landscape","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"water","stylers":[{"color":"#c9e8f5"}]}
  ]''';

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
      final services = ref.read(serviceCategoriesProvider).valueOrNull;
      if (services != null && services.isNotEmpty) {
        _quote(services);
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    super.dispose();
  }

  void _initPayment() {
    final config = ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
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
    if (draft.dropoffLat == null || draft.dropoffLng == null || services.isEmpty) return;
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
    _fitRoute();
  }

  Future<void> _loadRoute() async {
    final draft = ref.read(jobDraftProvider);
    if (draft.dropoffLat == null || draft.dropoffLng == null) return;
    final key = '${draft.pickupLat.toStringAsFixed(5)},${draft.pickupLng.toStringAsFixed(5)}|'
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
    final arrival = DateTime.now().add(Duration(minutes: minutes == 0 ? 1 : minutes));
    final pickupIcon = await MapMarkers.buildStopLabel(
      title: 'Pickup',
      subtitle: 'Now',
      color: const Color(0xFF32BB78),
    );
    final dropoffIcon = await MapMarkers.buildStopLabel(
      title: 'Dropoff',
      subtitle: DateFormat('h:mm a').format(arrival),
      color: const Color(0xFF1F2937),
    );
    if (!mounted || _routeKey != key) return;
    setState(() {
      _routePoints = route?.points ?? const [];
      _routeMinutes = minutes;
      _pickupIcon = pickupIcon;
      _dropoffIcon = dropoffIcon;
    });
    _fitRoute();
  }

  Future<void> _editPickup() async {
    final applied = await showPickupLocationPicker(context: context, autofocusSearch: true);
    if (!applied || !mounted) return;
    _quoteKey = null;
    final services = ref.read(serviceCategoriesProvider).valueOrNull ?? const <ServiceCategory>[];
    await _quote(services);
    _fitRoute();
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
    final services = ref.read(serviceCategoriesProvider).valueOrNull ?? const <ServiceCategory>[];
    await _quote(services);
    _fitRoute();
  }

  void _fitRoute() {
    final draft = ref.read(jobDraftProvider);
    final controller = _mapController;
    if (controller == null || draft.dropoffLat == null || draft.dropoffLng == null) return;
    final points = _routePoints.isNotEmpty
        ? _routePoints
        : [
            LatLng(draft.pickupLat, draft.pickupLng),
            LatLng(draft.dropoffLat!, draft.dropoffLng!),
          ];
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
    if ((north - south).abs() < 0.0001 && (east - west).abs() < 0.0001) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(draft.pickupLat, draft.pickupLng), 15));
      return;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        72,
      ),
    );
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
        (_recipientName.text.trim().isEmpty || _recipientPhone.text.trim().isEmpty)) {
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
      ref.read(jobDraftProvider.notifier).state = ref.read(jobDraftProvider).copyWith(
            serviceCategory: selected,
            estimate: estimate,
            paymentMethod: _payment!,
            offeredPrice: draft.jobType == 'bidding' ? (_offerPrice ?? estimate.estimatedFare) : null,
            recipientName: _recipientName.text.trim(),
            recipientPhone: _recipientPhone.text.trim(),
            parcelSize: _parcelSize,
          );
      if (!mounted) return;
      context.push('/payment');
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
    final config = ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final methods = _enabledMethods(config);
    ref.listen<AsyncValue<List<ServiceCategory>>>(serviceCategoriesProvider, (_, next) {
      next.whenData(_quote);
    });

    final pickup = LatLng(draft.pickupLat, draft.pickupLng);
    final dropoff = draft.dropoffLat == null || draft.dropoffLng == null
        ? null
        : LatLng(draft.dropoffLat!, draft.dropoffLng!);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            GoogleMap(
              padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * 0.50),
              initialCameraPosition: CameraPosition(target: pickup, zoom: 13),
              onMapCreated: (controller) async {
                _mapController = controller;
                await applyMapStyle(controller, _mapStyle);
                _fitRoute();
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: pickup,
                  icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  anchor: _pickupIcon == null ? const Offset(0.5, 1) : const Offset(0.5, 1),
                ),
                if (dropoff != null)
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: dropoff,
                    icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    anchor: const Offset(0.5, 1),
                  ),
              },
              polylines: {
                if (dropoff != null) ...{
                  Polyline(
                    polylineId: const PolylineId('route-casing'),
                    points: _routePoints.length > 1 ? _routePoints : [pickup, dropoff],
                    color: Colors.white,
                    width: 10,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                    zIndex: 1,
                  ),
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: _routePoints.length > 1 ? _routePoints : [pickup, dropoff],
                    color: const Color(0xFF32BB78),
                    width: 6,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                    zIndex: 2,
                  ),
                },
              },
            ),
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
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.58),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -4))],
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
                        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        error: (_, __) => Center(
                          child: TextButton(
                            onPressed: () => ref.invalidate(serviceCategoriesProvider),
                            child: Text(AppLocalizations.of(context).couldNotLoadServicesTapToRetry),
                          ),
                        ),
                        data: (services) {
                          final shown = _sortedServices(services);
                          return Column(
                            children: [
                              _SortBar(
                                value: _sort,
                                onChanged: (value) => setState(() => _sort = value),
                              ),
                              Expanded(
                                child: _RideList(
                                  services: shown,
                                  quotes: _quotes,
                                  quoting: _quoting,
                                  routeMinutes: _routeMinutes,
                                  selectedId: _selected?.id,
                                  recommendedId: services.isEmpty ? null : services.first.id,
                                  showRecommended: _sort == 'recommended',
                                  onSelect: (service) => setState(() => _selected = service),
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
                              decoration: const InputDecoration(labelText: 'Recipient name'),
                            ),
                            TextField(
                              controller: _recipientPhone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Recipient phone'),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Parcel size', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final size in const ['small', 'medium', 'large'])
                                  ChoiceChip(
                                    label: Text(size[0].toUpperCase() + size.substring(1)),
                                    selected: _parcelSize == size,
                                    onSelected: (_) => setState(() => _parcelSize = size),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (draft.jobType == 'bidding' && _selected != null && _quotes[_selected!.id] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Builder(builder: (context) {
                          final suggested = _quotes[_selected!.id]!.estimatedFare;
                          final config = ref.read(appConfigProvider).valueOrNull ?? AppConfig.fallback;
                          final min = suggested * config.bidMinFareRatio;
                          final max = suggested * config.bidMaxFareRatio;
                          final value = (_offerPrice ?? suggested).clamp(min, max);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your offer: ${value.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              Slider(
                                min: min,
                                max: max <= min ? min + 1 : max,
                                value: value,
                                onChanged: (v) => setState(() => _offerPrice = v),
                              ),
                            ],
                          );
                        }),
                      ),
                    if (methods.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          AppLocalizations.of(context).noPaymentMethodsAreCurrentlyAvailablePleaseConta,
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
                        ),
                      )
                    else
                      InkWell(
                        onTap: _confirming ? null : () => _pickPayment(methods),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                          child: Row(
                            children: [
                              Icon(_paymentIcon(_payment), size: 22, color: AppColors.textPrimary),
                              const SizedBox(width: 10),
                              Text(
                                _payment == null
                                    ? AppLocalizations.of(context).choosePaymentMethod
                                    : _paymentLabel(context, _payment!),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, color: AppColors.grey500),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SafeArea(
                        top: false,
                        child: RyvoButton(
                          label: _confirming || _quoting
                              ? AppLocalizations.of(context).gettingEstimate
                              : 'Select ${_selected?.name ?? 'ride'}',
                          onPressed: _confirming || _quoting || _selected == null || _payment == null
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

  List<ServiceCategory> _sortedServices(List<ServiceCategory> services) {
    if (_sort != 'cheaper') return services;
    final copy = [...services];
    copy.sort((a, b) {
      final left = _quotes[a.id]?.estimatedFare ?? double.infinity;
      final right = _quotes[b.id]?.estimatedFare ?? double.infinity;
      return left.compareTo(right);
    });
    return copy;
  }

  Future<void> _pickPayment(List<String> methods) async {
    final picked = await showRyvoPaymentSheet(
      context,
      selected: _payment,
      methods: methods,
    );
    if (picked != null && mounted) setState(() => _payment = picked);
  }

  IconData _paymentIcon(String? method) {
    return switch (method) {
      'wallet' => Icons.account_balance_wallet_outlined,
      'cash' => Icons.payments_outlined,
      'google_pay' => Icons.account_balance_wallet,
      'apple_pay' => Icons.apple,
      _ => Icons.credit_card,
    };
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

class _RideList extends StatelessWidget {
  const _RideList({
    required this.services,
    required this.quotes,
    required this.quoting,
    required this.routeMinutes,
    required this.selectedId,
    required this.recommendedId,
    required this.showRecommended,
    required this.onSelect,
    required this.onRetry,
  });

  final List<ServiceCategory> services;
  final Map<String, FareEstimate> quotes;
  final bool quoting;
  final int routeMinutes;
  final String? selectedId;
  final String? recommendedId;
  final bool showRecommended;
  final ValueChanged<ServiceCategory> onSelect;
  final VoidCallback onRetry;

  int _seats(String? slug) => slug == 'xl' ? 6 : 4;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Text(
          'No rides are available right now',
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      itemCount: services.length + (quoting ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (quoting && index == 0) {
          return const LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
          );
        }
        final serviceIndex = quoting ? index - 1 : index;
        final service = services[serviceIndex];
        final estimate = quotes[service.id];
        final selected = service.id == selectedId;
        final minutes = routeMinutes > 0 ? routeMinutes : (estimate?.durationMin ?? 0);
        final description = (service.description ?? '').trim();
        final recommended = showRecommended && selected && service.id == recommendedId;
        return Material(
          color: selected ? const Color(0xFFF3FBF6) : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: estimate == null && !quoting ? null : () => onSelect(service),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? const Color(0xFF32BB78) : const Color(0xFFE6E8EC),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(serviceIcon(service.slug, service.icon), color: AppColors.navy, size: 32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (minutes > 0)
                              Text(
                                '$minutes min',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            if (minutes > 0) const SizedBox(width: 8),
                            const Icon(Icons.person_outline, size: 14, color: AppColors.grey500),
                            Text(
                              ' ${_seats(service.slug)}',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        if (recommended) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF32BB78),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (estimate != null)
                    Text(
                      formatMoney(estimate.estimatedFare),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    )
                  else if (quoting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).retry)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _SortPill(
            label: 'Recommended',
            selected: value == 'recommended',
            onTap: () => onChanged('recommended'),
          ),
          const SizedBox(width: 8),
          _SortPill(
            label: 'Cheaper',
            icon: Icons.sell_outlined,
            selected: value == 'cheaper',
            onTap: () => onChanged('cheaper'),
          ),
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3FBF6) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFF32BB78) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? const Color(0xFF24965F) : AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF24965F) : AppColors.textSecondary,
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
      color: AppColors.card,
      elevation: 3,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
              color: AppColors.textPrimary,
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onPickup,
                      child: Text(
                        pickup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 16, color: AppColors.grey500),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onTap: onDropoff,
                      child: Text(
                        dropoff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
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
