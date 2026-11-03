import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../core/location/location_service.dart';
import '../../core/location/uk_places_search.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ryvo_live_location_pulse.dart';
import '../../core/widgets/ryvo_map_canvas.dart';
import '../providers/app_providers.dart';
import 'ryvo_button.dart';

/// Opens the location page. Returns true when the pickup draft was updated.
Future<bool> showPickupLocationPicker({
  required BuildContext context,
  bool autofocusSearch = false,
  bool forDropoff = false,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    PageRouteBuilder<bool>(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => PickupLocationPicker(
        autofocusSearch: autofocusSearch,
        forDropoff: forDropoff,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  return result == true;
}

class PickupLocationPicker extends ConsumerStatefulWidget {
  const PickupLocationPicker({
    super.key,
    this.autofocusSearch = false,
    this.forDropoff = false,
  });

  /// Retained for existing call sites. The map is the primary control; typed
  /// search opens from the address pill.
  final bool autofocusSearch;
  final bool forDropoff;

  @override
  ConsumerState<PickupLocationPicker> createState() =>
      _PickupLocationPickerState();
}

class _PickupLocationPickerState extends ConsumerState<PickupLocationPicker> {
  static const _mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"simplified"}]}
  ]''';

  final _dragging = ValueNotifier<bool>(false);
  final _locatingPin = ValueNotifier<bool>(false);
  final _streetText = ValueNotifier<String>('');
  final _addressText = ValueNotifier<String>('');
  final _regionText = ValueNotifier<String?>(null);
  final _errorText = ValueNotifier<String?>(null);

  GoogleMapController? _mapController;
  late final Widget _mapLayer;
  late final ValueNotifier<CameraPosition> _viewCamera;

  late double _lat;
  late double _lng;
  bool _skipIdle = true;
  int _resolveToken = 0;
  LatLng? _mapCenter;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(jobDraftProvider);
    if (widget.forDropoff &&
        draft.dropoffLat != null &&
        draft.dropoffLng != null) {
      _lat = draft.dropoffLat!;
      _lng = draft.dropoffLng!;
      _addressText.value = draft.dropoffAddress;
    } else {
      _lat = draft.pickupLat;
      _lng = draft.pickupLng;
      _addressText.value = widget.forDropoff ? '' : draft.pickupAddress;
      _regionText.value = widget.forDropoff ? null : draft.pickupRegion;
    }
    _streetText.value = _streetLine(_addressText.value);
    if (_addressText.value.trim().isEmpty) {
      _locatingPin.value = true;
      Future.microtask(_resolveInitialPin);
    }
    _viewCamera = ValueNotifier(
      CameraPosition(target: LatLng(_lat, _lng), zoom: 16),
    );
    _mapLayer = _StableLocationMap(
      initialTarget: LatLng(_lat, _lng),
      mapStyle: _mapStyle,
      onCreated: (controller) => _mapController = controller,
      onMoveStarted: () {
        if (!_dragging.value) _dragging.value = true;
      },
      onMove: (target) => _mapCenter = target,
      onView: (position) => _viewCamera.value = position,
      onIdle: _onCameraIdle,
    );
  }

  @override
  void dispose() {
    _dragging.dispose();
    _locatingPin.dispose();
    _streetText.dispose();
    _addressText.dispose();
    _regionText.dispose();
    _errorText.dispose();
    _viewCamera.dispose();
    super.dispose();
  }

  ({double lat, double lng}) _bias() {
    final draft = ref.read(jobDraftProvider);
    final pinMoved = (_lat - draft.pickupLat).abs() > 0.0001 ||
        (_lng - draft.pickupLng).abs() > 0.0001;
    return UkSearchBias.resolve(
      lat: _lat,
      lng: _lng,
      locationResolved: draft.locationResolved || pinMoved,
    );
  }

  Future<void> _openSearch() async {
    final bias = _bias();
    final resolved = await Navigator.of(context).push<ResolvedLocation>(
      PageRouteBuilder<ResolvedLocation>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => _AddressSearchPage(
          biasLat: bias.lat,
          biasLng: bias.lng,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
    if (!mounted || resolved == null) return;
    _applyResolved(resolved, moveCamera: true);
  }

  Future<void> _resolveInitialPin() async {
    final token = ++_resolveToken;
    _locatingPin.value = true;
    _errorText.value = null;
    try {
      final resolved =
          await ref.read(locationServiceProvider).reverseGeocode(_lat, _lng);
      if (!mounted || token != _resolveToken) return;
      _publishResolved(
        resolved,
        lat: _lat,
        lng: _lng,
      );
    } catch (_) {
      if (!mounted || token != _resolveToken) return;
      if (_addressText.value.trim().isEmpty) {
        _publishCoords(_lat, _lng);
      }
    } finally {
      if (mounted && token == _resolveToken) _locatingPin.value = false;
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locatingPin.value) return;
    _locatingPin.value = true;
    _errorText.value = null;
    try {
      final resolved =
          await ref.read(locationServiceProvider).getCurrentLocation();
      if (!mounted) return;
      _applyResolved(resolved, moveCamera: true);
    } on LocationFailure catch (e) {
      if (mounted) _errorText.value = e.message;
    } catch (_) {
      if (mounted) {
        _errorText.value =
            'Could not determine your location. Please try again.';
      }
    } finally {
      if (mounted) _locatingPin.value = false;
    }
  }

  void _applyResolved(ResolvedLocation resolved, {required bool moveCamera}) {
    _resolveToken++;
    _skipIdle = true;
    _publishResolved(resolved, lat: resolved.lat, lng: resolved.lng);
    _errorText.value = null;
    _dragging.value = false;
    if (moveCamera) {
      _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(resolved.lat, resolved.lng), 16),
      );
    }
  }

  void _publishResolved(
    ResolvedLocation resolved, {
    required double lat,
    required double lng,
  }) {
    _lat = lat;
    _lng = lng;
    final full = resolved.address ??
        resolved.shortAddress ??
        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    _addressText.value = full;
    _streetText.value = _streetLine(full, short: resolved.shortAddress);
    _regionText.value = resolved.region;
  }

  void _publishCoords(double lat, double lng) {
    _lat = lat;
    _lng = lng;
    final coords = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    _addressText.value = coords;
    _streetText.value = coords;
    _regionText.value = null;
  }

  Future<void> _onCameraIdle() async {
    _dragging.value = false;
    if (_skipIdle) {
      _skipIdle = false;
      return;
    }
    final center = _mapCenter;
    if (center == null) return;
    HapticFeedback.mediumImpact();
    final token = ++_resolveToken;
    _locatingPin.value = true;
    _errorText.value = null;
    try {
      final resolved = await ref
          .read(locationServiceProvider)
          .reverseGeocode(center.latitude, center.longitude);
      if (!mounted || token != _resolveToken) return;
      _publishResolved(
        resolved,
        lat: center.latitude,
        lng: center.longitude,
      );
    } catch (_) {
      if (!mounted || token != _resolveToken) return;
      _publishCoords(center.latitude, center.longitude);
    } finally {
      if (mounted && token == _resolveToken) _locatingPin.value = false;
    }
  }

  void _confirm() {
    final address = _addressText.value.trim();
    if (address.isEmpty || _locatingPin.value || _dragging.value) return;
    ref.read(pickupEditGenerationProvider.notifier).state++;
    final latest = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state = widget.forDropoff
        ? latest.copyWith(
            dropoffLat: _lat,
            dropoffLng: _lng,
            dropoffAddress: address,
          )
        : latest.copyWith(
            pickupLat: _lat,
            pickupLng: _lng,
            pickupAddress: address,
            pickupRegion: _regionText.value,
            clearPickupRegion: _regionText.value == null,
            locationResolved: true,
          );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _mapLayer),
          Positioned.fill(
            child: RyvoLiveLocationPulse(camera: _viewCamera),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: RepaintBoundary(
                  child: _AnchoredPin(dragging: _dragging),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SearchAddressPill(onTap: _openSearch),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: _locatingPin,
                  builder: (_, locating, __) {
                    return _RoundIconButton(
                      icon: Icons.my_location,
                      iconColor: AppColors.primary,
                      busy: locating,
                      onTap: locating ? null : _useCurrentLocation,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _LocationConfirmCard(
                  street: _streetText,
                  address: _addressText,
                  region: _regionText,
                  error: _errorText,
                  dragging: _dragging,
                  locating: _locatingPin,
                  onConfirm: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _streetLine(String full, {String? short}) {
  final primary = short?.trim();
  if (primary != null && primary.isNotEmpty) return primary;
  final trimmed = full.trim();
  if (trimmed.isEmpty) return '';
  final first = trimmed.split(',').first.trim();
  return first.isEmpty ? trimmed : first;
}

/// Center-anchored pin. The ground dot stays on the camera target while the
/// head lifts. [ValueNotifier] keeps this off the map widget's rebuild path.
class _AnchoredPin extends StatelessWidget {
  const _AnchoredPin({required this.dragging});

  final ValueNotifier<bool> dragging;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: dragging,
      builder: (_, lifted, __) {
        return FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: SizedBox(
            width: 44,
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: lifted ? 16 : 8,
                  height: lifted ? 6 : 4,
                  decoration: BoxDecoration(
                    color: AppColors.obsidian.withValues(
                      alpha: lifted ? 0.28 : 0.16,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                AnimatedContainer(
                  duration: Duration(milliseconds: lifted ? 180 : 520),
                  curve: lifted ? Curves.easeOut : Curves.elasticOut,
                  transform: Matrix4.translationValues(0, lifted ? -16 : 0, 0),
                  transformAlignment: Alignment.bottomCenter,
                  child: const RyvoFloatingPin(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sleek brand pin. The tip is the bottom of the widget so the anchor math
/// in [_AnchoredPin] lands on the camera target.
class RyvoFloatingPin extends StatelessWidget {
  const RyvoFloatingPin({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(36, 48),
      painter: _RyvoPinPainter(
        fill: AppColors.primary,
        ring: AppColors.white,
        core: AppColors.white,
      ),
    );
  }
}

class _RyvoPinPainter extends CustomPainter {
  const _RyvoPinPainter({
    required this.fill,
    required this.ring,
    required this.core,
  });

  final Color fill;
  final Color ring;
  final Color core;

  @override
  void paint(Canvas canvas, Size size) {
    final head = Offset(size.width / 2, 16);
    final tip = Offset(size.width / 2, size.height - 1);
    final body = Path()
      ..moveTo(head.dx - 8, head.dy + 6)
      ..quadraticBezierTo(head.dx, head.dy + 18, tip.dx, tip.dy)
      ..quadraticBezierTo(head.dx, head.dy + 18, head.dx + 8, head.dy + 6)
      ..close();
    canvas.drawPath(body, Paint()..color = fill);
    canvas.drawCircle(head, 14, Paint()..color = fill);
    canvas.drawCircle(
      head,
      14,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(head, 5, Paint()..color = core);
  }

  @override
  bool shouldRepaint(covariant _RyvoPinPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.ring != ring ||
        oldDelegate.core != core;
  }
}

class _SearchAddressPill extends StatelessWidget {
  const _SearchAddressPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: AppColors.modal.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search address...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationConfirmCard extends StatelessWidget {
  const _LocationConfirmCard({
    required this.street,
    required this.address,
    required this.region,
    required this.error,
    required this.dragging,
    required this.locating,
    required this.onConfirm,
  });

  final ValueNotifier<String> street;
  final ValueNotifier<String> address;
  final ValueNotifier<String?> region;
  final ValueNotifier<String?> error;
  final ValueNotifier<bool> dragging;
  final ValueNotifier<bool> locating;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ValueListenableBuilder<bool>(
          valueListenable: dragging,
          builder: (_, isDragging, __) {
            return ValueListenableBuilder<bool>(
              valueListenable: locating,
              builder: (_, isLocating, __) {
                return ValueListenableBuilder<String>(
                  valueListenable: street,
                  builder: (_, streetText, __) {
                    return ValueListenableBuilder<String>(
                      valueListenable: address,
                      builder: (_, addressText, __) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: region,
                          builder: (_, regionText, __) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: error,
                              builder: (_, errorText, __) {
                                final busy = isDragging || isLocating;
                                final headline = isLocating
                                    ? l10n.resolvingAddress
                                    : (streetText.trim().isEmpty
                                        ? l10n.searchUkAddress
                                        : streetText);
                                final detail = !isLocating &&
                                        addressText.trim().isNotEmpty &&
                                        addressText.trim() != streetText.trim()
                                    ? addressText
                                    : regionText;
                                final canConfirm = !busy &&
                                    addressText.trim().isNotEmpty &&
                                    streetText.trim().isNotEmpty;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      headline,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: RyvoTypography.heading(
                                        fontSize: 18,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    if (detail != null &&
                                        detail.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        detail,
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
                                    if (errorText != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        errorText,
                                        style: RyvoTypography.style(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    AnimatedOpacity(
                                      opacity: isDragging ? 0.4 : 1,
                                      duration:
                                          const Duration(milliseconds: 180),
                                      curve: Curves.easeOut,
                                      child: RyvoButton(
                                        label: l10n.confirmLocation,
                                        isLoading: isLocating,
                                        onPressed:
                                            canConfirm ? onConfirm : null,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The platform map is built once. Camera gestures only notify the pin.
class _StableLocationMap extends StatefulWidget {
  const _StableLocationMap({
    required this.initialTarget,
    required this.mapStyle,
    required this.onCreated,
    required this.onMoveStarted,
    required this.onMove,
    required this.onView,
    required this.onIdle,
  });

  final LatLng initialTarget;
  final String mapStyle;
  final ValueChanged<GoogleMapController> onCreated;
  final VoidCallback onMoveStarted;
  final ValueChanged<LatLng> onMove;
  final ValueChanged<CameraPosition> onView;
  final VoidCallback onIdle;

  @override
  State<_StableLocationMap> createState() => _StableLocationMapState();
}

class _StableLocationMapState extends State<_StableLocationMap> {
  @override
  Widget build(BuildContext context) {
    // Theme.of makes this State follow the app theme: the style is swapped in
    // place on the live map, so the camera and pin position survive.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: widget.initialTarget, zoom: 16),
        style: dark ? RyvoMapCanvas.darkStyle : widget.mapStyle,
        onMapCreated: widget.onCreated,
        onCameraMoveStarted: widget.onMoveStarted,
        onCameraMove: (position) {
          widget.onMove(position.target);
          widget.onView(position);
        },
        onCameraIdle: widget.onIdle,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
        buildingsEnabled: false,
        tiltGesturesEnabled: false,
        rotateGesturesEnabled: false,
      ),
    );
  }
}

class _AddressSearchPage extends ConsumerStatefulWidget {
  const _AddressSearchPage({
    required this.biasLat,
    required this.biasLng,
  });

  final double biasLat;
  final double biasLng;

  @override
  ConsumerState<_AddressSearchPage> createState() => _AddressSearchPageState();
}

class _AddressSearchPageState extends ConsumerState<_AddressSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  final String _sessionToken = newPlacesSessionToken();
  List<UkAddressSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _settled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _loading = false;
        _settled = false;
        _error = null;
      });
      return;
    }
    setState(() => _settled = false);
    _timer = Timer(const Duration(milliseconds: 300), () => _suggest(query));
  }

  Future<void> _suggest(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(ukPlacesSearchProvider).suggest(
            query: query,
            biasLat: widget.biasLat,
            biasLng: widget.biasLng,
            sessionToken: _sessionToken,
          );
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _loading = false;
        _settled = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
        _settled = true;
      });
    }
  }

  Future<void> _choose(UkAddressSuggestion suggestion) async {
    if (_loading) return;
    _focus.unfocus();
    setState(() => _loading = true);
    try {
      final resolved = await ref.read(ukPlacesSearchProvider).detailsFor(
            suggestion,
            sessionToken: _sessionToken,
          );
      if (!mounted) return;
      Navigator.pop(context, resolved);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PlacesLookupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not find that address. Try a more specific one.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _loading) return;
    if (_suggestions.isNotEmpty) {
      await _choose(_suggestions.first);
      return;
    }
    _focus.unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolved = await ref.read(ukPlacesSearchProvider).resolve(
            query: query,
            biasLat: widget.biasLat,
            biasLng: widget.biasLng,
            sessionToken: _sessionToken,
          );
      if (!mounted) return;
      Navigator.pop(context, resolved);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on PlacesLookupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not find that address. Try a more specific one.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _submit(),
                      style: RyvoTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search address...',
                        hintStyle: RyvoTypography.style(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textHint,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.primary, size: 20),
                        suffixIcon: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed: _submit,
                                icon: const Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.focusBorder,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: RyvoTypography.style(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _settled && _suggestions.isEmpty && !_loading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          l10n.noMatchingUkAddresses,
                          style: RyvoTypography.style(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        final distance = suggestion.distanceMeters;
                        return InkWell(
                          onTap: _loading ? null : () => _choose(suggestion),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.primaryText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: RyvoTypography.style(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      if (suggestion.secondaryText.isNotEmpty)
                                        Text(
                                          suggestion.secondaryText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: RyvoTypography.style(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (distance != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    formatUkDistance(distance),
                                    style: RyvoTypography.distance(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
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
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return RyvoPressScale(
      enabled: onTap != null && !busy,
      child: Material(
        color: AppColors.modal,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: AppColors.divider)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: SizedBox(
            width: 48,
            height: 48,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(icon,
                    color: iconColor ?? AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
