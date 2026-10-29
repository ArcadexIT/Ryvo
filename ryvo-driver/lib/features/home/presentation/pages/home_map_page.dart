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
import '../../../../core/utils/responsive.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/providers/verification_sync.dart';
import '../../../../shared/providers/notifiers/job_notifier.dart';
import '../../../../shared/providers/notifiers/location_notifier.dart';
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
  MapMarkerAsset? _dropoffMarker;
  Offset? _providerAnchor;
  Offset? _customerAnchor;
  Offset? _dropoffAnchor;

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

  double? _loadedMarkerScale;
  bool _loadedAsJob = false;
  bool _loadedDropoff = false;

  Future<void> _loadMarkers() async {
    final scale = _markerScale;
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    final asJob = incoming != null;
    final hasDrop = asJob &&
        incoming.dropoffLat != null &&
        incoming.dropoffLng != null &&
        incoming.dropoffLat != 0 &&
        incoming.dropoffLng != 0;
    if (_providerMarker != null &&
        _loadedMarkerScale == scale &&
        _loadedAsJob == asJob &&
        _loadedDropoff == hasDrop) {
      return;
    }
    final provider = asJob
        ? await MapMarkers.buildProviderCarMarker(markerScale: scale)
        : await MapMarkers.buildProviderLocationMarker(markerScale: scale);
    final customer = asJob
        ? await MapMarkers.buildCustomerJobMarker(
            'Pickup',
            markerScale: scale,
            pinColor: const Color(0xFF22C55E),
          )
        : null;
    final dropoff = hasDrop
        ? await MapMarkers.buildCustomerJobMarker('Drop off', markerScale: scale)
        : null;
    if (!mounted) return;
    setState(() {
      _providerMarker = provider;
      _customerMarker = customer;
      _dropoffMarker = dropoff;
      _providerAnchor = provider.anchor;
      _customerAnchor = customer?.anchor;
      _dropoffAnchor = dropoff?.anchor;
      _loadedMarkerScale = scale;
      _loadedAsJob = asJob;
      _loadedDropoff = hasDrop;
    });
  }

  void _fitJobBounds(BuildContext context) {
    final pad = R.w(context, 72).clamp(56.0, 96.0);
    final liveLoc = ref.read(locationStreamProvider).valueOrNull;
    final providerPos = liveLoc != null ? LatLng(liveLoc.latitude, liveLoc.longitude) : _providerPos;
    final points = _routePoints(providerPos);
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
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
        zIndexInt: 2,
      ),
    };
    if (showJob) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerPosFor(providerPos),
          icon: _customerMarker?.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: _customerAnchor ?? const Offset(0.5, 0.94),
          zIndexInt: 1,
        ),
      );
      final dropoff = _dropoffPos();
      if (dropoff != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('dropoff'),
            position: dropoff,
            icon: _dropoffMarker?.icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            anchor: _dropoffAnchor ?? const Offset(0.5, 0.94),
            zIndexInt: 1,
          ),
        );
      }
    }
    return markers;
  }

  LatLng? _dropoffPos() {
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    final lat = incoming?.dropoffLat;
    final lng = incoming?.dropoffLng;
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  List<LatLng> _routePoints(LatLng providerPos) {
    final pickup = _customerPosFor(providerPos);
    final dropoff = _dropoffPos();
    if (dropoff == null) return [providerPos, pickup];
    return [providerPos, pickup, dropoff];
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
    final tripScreenOpen = ref.watch(tripScreenCoveringHomeProvider);
    final showJob = isOnline && ref.watch(showIncomingJobProvider) && !tripScreenOpen;
    final activeJob = ref.watch(activeJobProvider);
    final locationAsync = ref.watch(locationStreamProvider);
    final liveLoc = locationAsync.valueOrNull;
    final providerPos = liveLoc != null ? LatLng(liveLoc.latitude, liveLoc.longitude) : _providerPos;
    final incoming = ref.watch(jobNotifierProvider).value?.incomingJob;
    final offer = showJob
        ? (incoming != null
            ? mockJobFromEntity(
                incoming,
                providerLat: liveLoc?.latitude,
                providerLng: liveLoc?.longitude,
              )
            : mockIncomingJob)
        : null;
    final showDock = activeJob != null &&
        !showJob &&
        (routeForActiveJob(activeJob.status) != null || activeJob.status == JobStatusEntity.paymentPending);
    final topInset = MediaQuery.paddingOf(context).top;
    final mapTopPad = showJob ? topInset + 240 : topInset + 76;
    final mapBottomPad = showJob ? 108.0 : (showDock ? 140.0 : 28.0);
    final controlsBottom = showJob ? 96.0 : (showDock ? 128.0 : 16.0);

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
      final onTrip = active?.status == JobStatusEntity.inProgress;
      if (active != null && !onTrip) {
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
      backgroundColor: const Color(0xFF0E1626),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: providerPos, zoom: 15),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            padding: EdgeInsets.only(top: mapTopPad, bottom: mapBottomPad),
            markers: _buildMarkers(showJob, providerPos),
            polylines: showJob
                ? {
                    Polyline(
                      polylineId: const PolylineId('route_preview'),
                      points: _routePoints(providerPos),
                      color: const Color(0xFF5B9DFF),
                      width: 5,
                      jointType: JointType.round,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                    ),
                  }
                : {},
            onCameraMoveStarted: () {
              if (_followLocation) {
                setState(() => _followLocation = false);
              }
            },
            style: MockData.darkMapStyle,
            onMapCreated: (c) {
              _mapController = c;
              if (liveLoc != null && !_hasInitialCentered) {
                _hasInitialCentered = true;
                _centerOnProvider(LatLng(liveLoc.latitude, liveLoc.longitude));
              }
            },
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x990E1626), Color(0x000E1626)],
                  stops: [0, 0.22],
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: isOnline ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: isOnline,
              child: OfflineOverlay(onGoOnline: () => _onOnlineChanged(true)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeTopBar(
                    isOnline: isOnline,
                    onMenu: _openMenu,
                    onToggleOnline: () => _onOnlineChanged(!isOnline),
                    onNotifications: () => context.push('/notifications'),
                  ),
                  if (showJob) ...[
                    const SizedBox(height: 10),
                    const IncomingJobSheet(),
                  ] else if (isOnline) ...[
                    const SizedBox(height: 10),
                    MapLocationStatusChip(
                      hasFix: liveLoc != null,
                      isLoading: locationAsync.isLoading || _locating,
                      hasError: locationAsync.hasError,
                      areaLabel: _areaLabel,
                    ),
                  ],
                  const Expanded(child: IgnorePointer(child: SizedBox.expand())),
                  if (offer != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 58),
                      child: _NavigationChip(
                        eta: offer.eta,
                        distance: offer.distance,
                        onTap: () => _fitJobBounds(context),
                      ),
                    )
                  else if (!showDock && isOnline)
                    const Padding(
                      padding: EdgeInsets.only(right: 58),
                      child: _WaitingChip(),
                    ),
                  if (showDock) ...[
                    const SizedBox(height: 10),
                    ActiveJobBanner(job: activeJob),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: controlsBottom,
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
        ],
      ),
    );
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141C2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _MenuTile(icon: Icons.person_outline, label: l10n.profile, onTap: () { Navigator.pop(ctx); context.go('/profile'); }),
                _MenuTile(icon: Icons.account_balance_wallet_outlined, label: l10n.wallet, onTap: () { Navigator.pop(ctx); context.push('/wallet'); }),
                _MenuTile(icon: Icons.bar_chart_rounded, label: l10n.earnings, onTap: () { Navigator.pop(ctx); context.go('/earnings'); }),
                _MenuTile(icon: Icons.history, label: l10n.history, onTap: () { Navigator.pop(ctx); context.go('/history'); }),
                _MenuTile(icon: Icons.notifications_outlined, label: l10n.notifications, onTap: () { Navigator.pop(ctx); context.push('/notifications'); }),
                _MenuTile(icon: Icons.help_outline, label: l10n.helpSupport, onTap: () { Navigator.pop(ctx); context.push('/help'); }),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _glass = Color(0xE6141C2B);
const _glassText = Color(0xFFF8FAFC);
const _glassMuted = Color(0xFF94A3B8);

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.isOnline,
    required this.onMenu,
    required this.onToggleOnline,
    required this.onNotifications,
  });

  final bool isOnline;
  final VoidCallback onMenu;
  final VoidCallback onToggleOnline;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(icon: Icons.menu_rounded, onTap: onMenu),
        const SizedBox(width: 8),
        _OnlinePill(isOnline: isOnline, onTap: onToggleOnline),
        const SizedBox(width: 8),
        const Expanded(child: _EarningsPill()),
        const SizedBox(width: 8),
        _GlassIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          showDot: true,
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap, this.showDot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _glass,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: _glassText, size: 22),
              if (showDot)
                const Positioned(
                  top: 10,
                  right: 11,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.isOnline, required this.onTap});

  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: _glass,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF22C55E) : _glassMuted,
                  shape: BoxShape.circle,
                  boxShadow: isOnline
                      ? const [BoxShadow(color: Color(0x8822C55E), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? l10n.online : l10n.offline,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? const Color(0xFF22C55E) : _glassMuted,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: isOnline ? const Color(0xFF22C55E) : _glassMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsPill extends ConsumerWidget {
  const _EarningsPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(earningsNotifierProvider).value?.earnings;
    final days = earnings?.dailyBreakdown ?? const <double>[];
    final today = days.length >= 7 ? days[6] : (days.isNotEmpty ? days.last : 0);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.go('/earnings'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF111827)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Today's earnings",
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      formatMoney(today.toDouble()),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827), height: 1.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationChip extends StatelessWidget {
  const _NavigationChip({required this.eta, required this.distance, required this.onTap});

  final String eta;
  final String distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = distance == '—' ? eta : '$eta  ·  $distance';
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: _glass,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.navigation_rounded, color: AppColors.navy, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Navigation',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _glassText),
                    ),
                    Text(
                      detail,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: _glassMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: _glassMuted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingChip extends StatelessWidget {
  const _WaitingChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _glass,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Waiting for ride requests',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _glassText),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _glassText),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _glassText)),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
