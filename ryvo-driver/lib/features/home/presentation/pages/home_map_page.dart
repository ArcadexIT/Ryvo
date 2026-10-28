import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/mock_data.dart';
import '../../../../core/services/job_alert_sound.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/travel_estimate.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/providers/verification_sync.dart';
import '../../../../shared/providers/notifiers/job_notifier.dart';
import '../../../../shared/providers/notifiers/location_notifier.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/active_job_banner.dart';
import '../widgets/incoming_job_sheet.dart';
import '../widgets/map_control_panel.dart';
import '../widgets/map_markers.dart';
import '../widgets/offline_overlay.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class HomeMapPage extends ConsumerStatefulWidget {
  const HomeMapPage({super.key});

  @override
  ConsumerState<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends ConsumerState<HomeMapPage> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  static const _providerPos = LatLng(40.7138, -74.0040);
  static const _customerPos = LatLng(40.7188, -73.9980);

  MapMarkerAsset? _providerMarker;
  MapMarkerAsset? _customerMarker;
  Offset? _providerAnchor;
  Offset? _customerAnchor;

  Timer? _jobTimer;
  double _markerScale = 1.0;
  bool _followLocation = true;
  bool _locating = false;
  bool _hasInitialCentered = false;
  String? _areaLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(earningsNotifierProvider.notifier).load();
      if (ref.read(activeJobProvider) == null) {
        restoreActiveJobSession(ProviderScope.containerOf(context, listen: false));
      }
      await _ensureApproved();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureApproved();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextScale = R.scaleOf(context);
    if (_providerMarker == null || (_markerScale - nextScale).abs() > 0.03) {
      _markerScale = nextScale;
      _loadMarkers();
    }
  }

  String? _loadedDistanceLabel;
  double? _loadedMarkerScale;

  String _incomingDistanceLabel() {
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    if (incoming == null) return AppLocalizations.of(context).nearby;
    final live = ref.read(locationStreamProvider).valueOrNull;
    final travel = travelEstimateFor(
      pickupLat: incoming.customerLat,
      pickupLng: incoming.customerLng,
      providerLat: live?.latitude,
      providerLng: live?.longitude,
      serverDistanceKm: incoming.providerDistanceKm,
      serverEtaMinutes: incoming.etaMinutes,
    );
    if (travel.distance == '—') return AppLocalizations.of(context).nearby;
    return '${travel.distance} away';
  }

  Future<void> _loadMarkers() async {
    final scale = _markerScale;
    final label = _incomingDistanceLabel();
    if (_providerMarker != null && _loadedDistanceLabel == label && _loadedMarkerScale == scale) {
      return;
    }
    final provider = await MapMarkers.buildProviderLocationMarker(markerScale: scale);
    final customer = await MapMarkers.buildCustomerJobMarker(
      label,
      markerScale: scale,
    );
    if (!mounted) return;
    setState(() {
      _providerMarker = provider;
      _customerMarker = customer;
      _providerAnchor = provider.anchor;
      _customerAnchor = customer.anchor;
      _loadedDistanceLabel = label;
      _loadedMarkerScale = scale;
    });
  }

  void _fitJobBounds(BuildContext context) {
    final pad = R.w(context, 32).clamp(24.0, 48.0);
    final liveLoc = ref.read(locationStreamProvider).valueOrNull;
    final providerPos = liveLoc != null ? LatLng(liveLoc.latitude, liveLoc.longitude) : _providerPos;
    final customerPos = _customerPosFor(providerPos);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            providerPos.latitude < customerPos.latitude ? providerPos.latitude : customerPos.latitude,
            providerPos.longitude < customerPos.longitude ? providerPos.longitude : customerPos.longitude,
          ),
          northeast: LatLng(
            providerPos.latitude > customerPos.latitude ? providerPos.latitude : customerPos.latitude,
            providerPos.longitude > customerPos.longitude ? providerPos.longitude : customerPos.longitude,
          ),
        ),
        pad,
      ),
    );
  }

  Future<void> _centerOnProvider(LatLng pos, {double zoom = 16}) async {
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)),
    );
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    final liveLoc = ref.read(locationStreamProvider).valueOrNull;
    if (liveLoc != null) {
      await _centerOnProvider(LatLng(liveLoc.latitude, liveLoc.longitude));
      if (mounted) setState(() {
        _followLocation = true;
        _locating = false;
      });
      return;
    }

    final result = await ref.read(locationRepositoryProvider).getCurrentLocation();
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _locating = false);
        final msg = failure.message.toLowerCase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('denied') || msg.contains('disabled')
                  ? AppLocalizations.of(context).enableLocationPermissionToUseTheMap
                  : AppLocalizations.of(context).couldNotGetYourLocation,
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.error,
            action: SnackBarAction(
              label: AppLocalizations.of(context).settings,
              textColor: Colors.white,
              onPressed: () {
                if (msg.contains('disabled')) {
                  Geolocator.openLocationSettings();
                } else {
                  Geolocator.openAppSettings();
                }
              },
            ),
          ),
        );
      },
      (loc) async {
        await _centerOnProvider(LatLng(loc.latitude, loc.longitude));
        if (mounted) setState(() {
          _followLocation = true;
          _locating = false;
        });
      },
    );
  }

  Future<void> _resolveAreaLabel(double lat, double lng) async {
    try {
      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty || !mounted) return;
      final p = places.first;
      final parts = [p.locality, p.administrativeArea].where((e) => e != null && e.isNotEmpty).toList();
      if (parts.isNotEmpty) setState(() => _areaLabel = parts.join(', '));
    } catch (_) {}
  }

  void _onZoomIn() => _mapController?.animateCamera(CameraUpdate.zoomIn());
  void _onZoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());

  void _toggleFollow() {
    if (_followLocation) {
      setState(() => _followLocation = false);
      return;
    }
    _goToMyLocation();
  }

  Future<void> _ensureApproved() async {
    final container = ProviderScope.containerOf(context, listen: false);
    await syncProviderVerification(container);
    if (!mounted) return;
    if (ref.read(isKycApprovedProvider)) return;
    if (ref.read(isOnlineProvider)) {
      ref.read(isOnlineProvider.notifier).state = false;
      await ref.read(availabilityNotifierProvider.notifier).setOnline(false);
    }
    if (!mounted) return;
    context.go('/kyc');
  }

  Future<void> _onOnlineChanged(bool online) async {
    if (online) {
      await _ensureApproved();
      if (!mounted) return;
      if (!ref.read(isKycApprovedProvider)) {
        ref.read(isOnlineProvider.notifier).state = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).completeOnboardingApprovalBeforeGoingOnline)),
        );
        return;
      }
    }

    if (online) {
      try {
        await ref.read(providerSocketProvider).connect();
      } catch (_) {}
      ref.read(locationNotifierProvider);

      // Seed Redis geo index before going online so the first customer request
      // can match immediately (socket auth can fail when switching apps).
      final liveLoc = ref.read(locationStreamProvider).valueOrNull;
      var forcedOffline = false;
      if (liveLoc != null) {
        final sent = await ref.read(locationRepositoryProvider).broadcastLocation(liveLoc);
        forcedOffline = sent.fold((_) => false, (forced) => forced);
      } else {
        final result = await ref.read(locationRepositoryProvider).getCurrentLocation();
        await result.fold((_) async {}, (loc) async {
          final sent = await ref.read(locationRepositoryProvider).broadcastLocation(loc);
          forcedOffline = sent.fold((_) => false, (forced) => forced);
        });
      }
      if (forcedOffline) {
        ref.read(isOnlineProvider.notifier).state = false;
        await _showOutOfArea(liveLoc?.latitude, liveLoc?.longitude);
        return;
      }

      final error = await ref.read(availabilityNotifierProvider.notifier).setOnline(true);
      if (!mounted) return;
      if (error != null) {
        ref.read(isOnlineProvider.notifier).state = false;
        await _handleOnlineError(error);
        return;
      }
      ref.read(isOnlineProvider.notifier).state = true;
      ref.read(jobNotifierProvider);
    } else {
      ref.read(isOnlineProvider.notifier).state = false;
      await ref.read(availabilityNotifierProvider.notifier).setOnline(online);
      JobAlertSound.stop();
      ref.read(showIncomingJobProvider.notifier).state = false;
      final liveLoc = ref.read(locationStreamProvider).valueOrNull;
      final target = liveLoc != null ? LatLng(liveLoc.latitude, liveLoc.longitude) : _providerPos;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
      );
    }
  }

  Set<Marker> _buildMarkers(bool showJob, LatLng providerPos) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('provider'),
        position: providerPos,
        icon: _providerMarker?.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: _providerAnchor ?? const Offset(0.5, 0.5),
        zIndex: 2,
      ),
    };
    if (showJob) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerPosFor(providerPos),
          icon: _customerMarker?.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: _customerAnchor ?? const Offset(0.5, 0.94),
          zIndex: 1,
        ),
      );
    }
    return markers;
  }

  LatLng _customerPosFor(LatLng fallback) {
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    if (incoming?.customerLat != null && incoming?.customerLng != null &&
        incoming!.customerLat != 0 && incoming.customerLng != 0) {
      return LatLng(incoming.customerLat!, incoming.customerLng!);
    }
    return _customerPos;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jobTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleOnlineError(String error) async {
    final lower = error.toLowerCase();
    if (lower.contains('out_of_area') || lower.contains('unavailable in the current area')) {
      final live = ref.read(locationStreamProvider).valueOrNull;
      await _showOutOfArea(live?.latitude, live?.longitude);
      return;
    }
    if (lower.contains('agreement')) {
      if (mounted) context.push('/compliance');
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _showOutOfArea(double? lat, double? lng) async {
    final notify = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Service unavailable'),
        content: const Text('RYVO is unavailable in the current area'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Notify me')),
        ],
      ),
    );
    if (notify != true || !mounted || lat == null || lng == null) return;
    try {
      await ref.read(dioClientProvider).dio.post('/provider/coverage/notify', data: {
        'lat': lat,
        'lng': lng,
        'addressLabel': _areaLabel,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We will notify you when RYVO is available here.')),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final showJob = isOnline && ref.watch(showIncomingJobProvider);
    final activeJob = ref.watch(activeJobProvider);
    final locationAsync = ref.watch(locationStreamProvider);
    final liveLoc = locationAsync.valueOrNull;
    final providerPos = liveLoc != null ? LatLng(liveLoc.latitude, liveLoc.longitude) : _providerPos;
    final sheetHeight = showJob ? R.jobSheetHeight(context) : 0.0;
    final mapBottomPad = sheetHeight + (showJob ? 8 : 0) + R.h(context, 88);
    final mapTopPad = showJob ? 8.0 : R.h(context, 72);

    ref.listen(coverageNoticeProvider, (prev, next) {
      if (next == null) return;
      ref.read(isOnlineProvider.notifier).state = false;
      ref.read(coverageNoticeProvider.notifier).state = null;
      final live = ref.read(locationStreamProvider).valueOrNull;
      _showOutOfArea(live?.latitude, live?.longitude);
    });

    ref.listen(locationStreamProvider, (prev, next) {
      next.whenData((loc) {
        final pos = LatLng(loc.latitude, loc.longitude);
        if (!_hasInitialCentered && _mapController != null) {
          _hasInitialCentered = true;
          _centerOnProvider(pos);
          _resolveAreaLabel(loc.latitude, loc.longitude);
        } else if (_followLocation && !showJob) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
        }
        if (_areaLabel == null) _resolveAreaLabel(loc.latitude, loc.longitude);
        if (ref.read(jobNotifierProvider).value?.incomingJob != null) {
          _loadMarkers();
        }
      });
    });

    ref.listen<bool>(showIncomingJobProvider, (prev, next) {
      if (next && isOnline) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitJobBounds(context);
        });
      }
    });

    // Surface a real incoming offer coming from the matching engine.
    ref.listen<AsyncValue<JobUiState>>(jobNotifierProvider, (prev, next) {
      final incoming = next.value?.incomingJob;
      if (incoming?.id != prev?.value?.incomingJob?.id) {
        _loadMarkers();
      }
      final dismissed = ref.read(dismissedIncomingOfferIdProvider);
      final show = ref.read(isOnlineProvider) && incomingOfferIsOpen(incoming, dismissed);
      final active = next.value?.activeJob;
      if (active != null) {
        ref.read(showIncomingJobProvider.notifier).state = false;
      } else if (ref.read(showIncomingJobProvider) != show) {
        ref.read(showIncomingJobProvider.notifier).state = show;
      }
    });

    ref.listen<MockJob?>(activeJobProvider, (previous, next) {
      if (!mounted || next == null) return;
      final route = routeForActiveJob(next.status);
      if (route == null) return;
      final becameActive = previous?.status != next.status &&
          (next.status == JobStatusEntity.accepted || next.status == JobStatusEntity.navigating);
      if (becameActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.push(route);
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: providerPos, zoom: 15),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            padding: EdgeInsets.only(top: mapTopPad, bottom: mapBottomPad),
            markers: _buildMarkers(showJob, providerPos),
            polylines: showJob
                ? {
                    Polyline(
                      polylineId: const PolylineId('route_preview'),
                      points: [providerPos, _customerPosFor(providerPos)],
                      color: AppColors.primary,
                      width: 3,
                      patterns: [PatternItem.dash(16), PatternItem.gap(8)],
                    ),
                  }
                : {},
            onCameraMoveStarted: () {
              if (_followLocation) {
                setState(() => _followLocation = false);
              }
            },
            onMapCreated: (c) {
              _mapController = c;
              _mapController?.setMapStyle(MockData.mapStyle);
              if (liveLoc != null && !_hasInitialCentered) {
                _hasInitialCentered = true;
                _centerOnProvider(LatLng(liveLoc.latitude, liveLoc.longitude));
              }
            },
          ),
          AnimatedOpacity(
            opacity: isOnline ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: isOnline,
              child: OfflineOverlay(onGoOnline: () => _onOnlineChanged(true)),
            ),
          ),
          if (!showJob)
            SafeArea(
              child: Padding(
                padding: R.pagePadding(context).copyWith(top: 8, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _EarningsPill()),
                        SizedBox(width: R.w(context, 8)),
                        Expanded(
                          child: OnlineToggle(
                            isOnline: isOnline,
                            enabled: ref.watch(isKycApprovedProvider),
                            onChanged: _onOnlineChanged,
                          ),
                        ),
                        SizedBox(width: R.w(context, 8)),
                        GestureDetector(
                          onTap: () => context.push('/notifications'),
                          child: Container(
                            width: R.w(context, 44).clamp(40, 48),
                            height: OnlineToggle.pillHeight,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: R.sp(context, 22)),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isOnline) ...[
                      SizedBox(height: R.h(context, 8)),
                      MapLocationStatusChip(
                        hasFix: liveLoc != null,
                        isLoading: locationAsync.isLoading || _locating,
                        hasError: locationAsync.hasError,
                        areaLabel: _areaLabel,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Positioned(
            right: R.w(context, 16),
            bottom: mapBottomPad - R.h(context, 72),
            child: MapControlPanel(
              onMyLocation: _goToMyLocation,
              onZoomIn: _onZoomIn,
              onZoomOut: _onZoomOut,
              followEnabled: _followLocation,
              onToggleFollow: _toggleFollow,
              locating: _locating,
              showFitRoute: showJob,
              onFitRoute: showJob ? () => _fitJobBounds(context) : null,
            ),
          ),
          if (showJob)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: Offset.zero,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: const IncomingJobSheet(),
              ),
            ),
          if (activeJob != null &&
              !showJob &&
              (routeForActiveJob(activeJob.status) != null ||
                  activeJob.status == JobStatusEntity.paymentPending))
            Positioned(
              left: R.w(context, 16),
              right: R.w(context, 16),
              bottom: mapBottomPad,
              child: ActiveJobBanner(job: activeJob),
            ),
        ],
      ),
    );
  }
}

class _EarningsPill extends ConsumerWidget {
  const _EarningsPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(earningsNotifierProvider).value?.earnings;
    final total = earnings?.weeklyTotal ?? 0;
    return Container(
      height: OnlineToggle.pillHeight,
      padding: EdgeInsets.symmetric(horizontal: R.w(context, 12)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: AppColors.primary, size: R.sp(context, 18)),
          SizedBox(width: R.w(context, 8)),
          Expanded(
            child: Text(
              '${formatMoney(total)} this week',
              style: GoogleFonts.poppins(
                fontSize: R.sp(context, 13),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
