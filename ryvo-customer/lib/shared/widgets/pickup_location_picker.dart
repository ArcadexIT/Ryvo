import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../core/location/location_service.dart';
import '../../core/location/uk_places_search.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';

/// Opens the location page. Returns true when the pickup draft was updated.
Future<bool> showPickupLocationPicker({
  required BuildContext context,
  bool autofocusSearch = false,
  bool forDropoff = false,
}) async {
  final result = await Navigator.of(context).push<bool>(
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

  final bool autofocusSearch;
  final bool forDropoff;

  @override
  ConsumerState<PickupLocationPicker> createState() => _PickupLocationPickerState();
}

class _PickupLocationPickerState extends ConsumerState<PickupLocationPicker> {
  static const _mapStyle = '''[
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","stylers":[{"visibility":"simplified"}]}
  ]''';

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _movingPin = ValueNotifier<bool>(false);
  final _locatingPin = ValueNotifier<bool>(false);
  final _addressText = ValueNotifier<String>('');
  final _regionText = ValueNotifier<String?>(null);
  final _errorText = ValueNotifier<String?>(null);

  GoogleMapController? _mapController;
  late final Widget _mapLayer;

  late double _lat;
  late double _lng;
  bool _searching = false;
  bool _suggesting = false;
  bool _suggestSettled = false;
  bool _suppressSuggest = false;
  bool _skipIdle = true;
  int _resolveToken = 0;
  int _suggestToken = 0;
  LatLng? _mapCenter;
  Timer? _suggestTimer;
  String _sessionToken = newPlacesSessionToken();
  List<UkAddressSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(jobDraftProvider);
    if (widget.forDropoff && draft.dropoffLat != null && draft.dropoffLng != null) {
      _lat = draft.dropoffLat!;
      _lng = draft.dropoffLng!;
      _addressText.value = draft.dropoffAddress;
    } else {
      _lat = draft.pickupLat;
      _lng = draft.pickupLng;
      _addressText.value = widget.forDropoff ? '' : draft.pickupAddress;
      _regionText.value = widget.forDropoff ? null : draft.pickupRegion;
    }
    _mapLayer = _StableLocationMap(
      initialTarget: LatLng(_lat, _lng),
      mapStyle: _mapStyle,
      moving: _movingPin,
      onCreated: (controller) => _mapController = controller,
      onMove: (target) {
        _mapCenter = target;
        if (!_movingPin.value) _movingPin.value = true;
      },
      onIdle: _onCameraIdle,
    );
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _movingPin.dispose();
    _locatingPin.dispose();
    _addressText.dispose();
    _regionText.dispose();
    _errorText.dispose();
    super.dispose();
  }

  ({double lat, double lng}) _bias() {
    final draft = ref.read(jobDraftProvider);
    final pinMoved = (_lat - draft.pickupLat).abs() > 0.0001 || (_lng - draft.pickupLng).abs() > 0.0001;
    return UkSearchBias.resolve(
      lat: _lat,
      lng: _lng,
      locationResolved: draft.locationResolved || pinMoved,
    );
  }

  void _onQueryChanged(String value) {
    if (_suppressSuggest) return;
    _suggestTimer?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _suggesting = false;
        _suggestSettled = false;
      });
      return;
    }
    setState(() => _suggestSettled = false);
    _suggestTimer = Timer(const Duration(milliseconds: 300), () => _loadSuggestions(query));
  }

  Future<void> _loadSuggestions(String query) async {
    final token = ++_suggestToken;
    setState(() => _suggesting = true);
    final bias = _bias();
    try {
      final results = await ref.read(ukPlacesSearchProvider).suggest(
            query: query,
            biasLat: bias.lat,
            biasLng: bias.lng,
            sessionToken: _sessionToken,
          );
      if (!mounted || token != _suggestToken || _searchController.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _suggesting = false;
        _suggestSettled = true;
      });
    } catch (_) {
      if (!mounted || token != _suggestToken) return;
      setState(() {
        _suggestions = const [];
        _suggesting = false;
        _suggestSettled = true;
      });
    }
  }

  Future<void> _selectSuggestion(UkAddressSuggestion suggestion) async {
    if (_searching) return;
    _suggestTimer?.cancel();
    _searchFocus.unfocus();
    _suppressSuggest = true;
    _searchController.text = suggestion.description.isNotEmpty ? suggestion.description : suggestion.primaryText;
    _searchController.selection = TextSelection.collapsed(offset: _searchController.text.length);
    _suppressSuggest = false;
    setState(() {
      _searching = true;
      _suggestions = const [];
      _suggesting = false;
      _suggestSettled = false;
    });
    _errorText.value = null;
    try {
      final resolved = await ref.read(ukPlacesSearchProvider).detailsFor(
            suggestion,
            sessionToken: _sessionToken,
          );
      if (!mounted) return;
      _sessionToken = newPlacesSessionToken();
      _applyResolved(resolved, moveCamera: true);
    } on LocationFailure catch (e) {
      if (mounted) _errorText.value = e.message;
    } on PlacesLookupException catch (e) {
      if (mounted) _errorText.value = e.message;
    } catch (_) {
      if (mounted) _errorText.value = 'Could not find that address. Try a more specific one.';
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching) return;
    if (_suggestions.isNotEmpty) {
      await _selectSuggestion(_suggestions.first);
      return;
    }
    _searchFocus.unfocus();
    setState(() => _searching = true);
    _errorText.value = null;
    final bias = _bias();
    try {
      final resolved = await ref.read(ukPlacesSearchProvider).resolve(
            query: query,
            biasLat: bias.lat,
            biasLng: bias.lng,
            sessionToken: _sessionToken,
          );
      if (!mounted) return;
      _sessionToken = newPlacesSessionToken();
      _applyResolved(resolved, moveCamera: true);
    } on LocationFailure catch (e) {
      if (mounted) _errorText.value = e.message;
    } on PlacesLookupException catch (e) {
      if (mounted) _errorText.value = e.message;
    } catch (_) {
      if (mounted) _errorText.value = 'Could not find that address. Try a more specific one.';
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locatingPin.value) return;
    _searchFocus.unfocus();
    _locatingPin.value = true;
    _errorText.value = null;
    try {
      final resolved = await ref.read(locationServiceProvider).getCurrentLocation();
      if (!mounted) return;
      _applyResolved(resolved, moveCamera: true);
    } on LocationFailure catch (e) {
      if (mounted) _errorText.value = e.message;
    } catch (_) {
      if (mounted) _errorText.value = 'Could not determine your location. Please try again.';
    } finally {
      if (mounted) _locatingPin.value = false;
    }
  }

  void _applyResolved(ResolvedLocation resolved, {required bool moveCamera}) {
    _resolveToken++;
    _skipIdle = true;
    _lat = resolved.lat;
    _lng = resolved.lng;
    _addressText.value = resolved.address ?? resolved.shortAddress ?? _addressText.value;
    _regionText.value = resolved.region;
    _errorText.value = null;
    _movingPin.value = false;
    if (moveCamera) {
      _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(resolved.lat, resolved.lng), 16),
      );
    }
  }

  Future<void> _onCameraIdle() async {
    _movingPin.value = false;
    if (_skipIdle) {
      _skipIdle = false;
      return;
    }
    final center = _mapCenter;
    if (center == null) return;
    final token = ++_resolveToken;
    _locatingPin.value = true;
    _errorText.value = null;
    try {
      final resolved = await ref.read(locationServiceProvider).reverseGeocode(center.latitude, center.longitude);
      if (!mounted || token != _resolveToken) return;
      _lat = center.latitude;
      _lng = center.longitude;
      _addressText.value = resolved.address ??
          resolved.shortAddress ??
          '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}';
      _regionText.value = resolved.region;
    } catch (_) {
      if (!mounted || token != _resolveToken) return;
      _lat = center.latitude;
      _lng = center.longitude;
      _addressText.value = '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}';
      _regionText.value = null;
    } finally {
      if (mounted && token == _resolveToken) _locatingPin.value = false;
    }
  }

  void _confirm() {
    final address = _addressText.value.trim();
    if (address.isEmpty || address == 'Locating your position…' || _locatingPin.value || _searching) {
      return;
    }
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
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _mapLayer),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.setYourLocation,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: AppColors.surface,
                      elevation: 6,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        autofocus: widget.autofocusSearch,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        onSubmitted: (_) => _search(),
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: l10n.searchUkAddress,
                          hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textHint),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
                          suffixIcon: _searching || _suggesting
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                                )
                              : IconButton(
                                  onPressed: _search,
                                  icon: const Icon(Icons.arrow_forward, color: AppColors.primary, size: 20),
                                ),
                          filled: true,
                          fillColor: AppColors.surface,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                          ),
                        ),
                      ),
                    ),
                    if (_suggestions.isNotEmpty ||
                        (_suggestSettled && _searchController.text.trim().length >= 2 && !_suggesting && !_searching))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Material(
                          color: AppColors.surface,
                          elevation: 8,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: _suggestions.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Text(
                                    l10n.noMatchingUkAddresses,
                                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                )
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 280),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: _suggestions.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                                    itemBuilder: (context, index) {
                                      final suggestion = _suggestions[index];
                                      final distance = suggestion.distanceMeters;
                                      return InkWell(
                                        onTap: _searching ? null : () => _selectSuggestion(suggestion),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      suggestion.primaryText,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    if (suggestion.secondaryText.isNotEmpty)
                                                      Text(
                                                        suggestion.secondaryText,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (distance != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  formatUkDistance(distance),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
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
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 220 + bottomInset,
            child: ValueListenableBuilder<bool>(
              valueListenable: _locatingPin,
              builder: (_, locating, __) {
                return _RoundIconButton(
                  icon: Icons.my_location,
                  iconColor: AppColors.primary,
                  busy: locating,
                  onTap: locating || _searching ? null : _useCurrentLocation,
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: _LocationConfirmCard(
                address: _addressText,
                region: _regionText,
                error: _errorText,
                locating: _locatingPin,
                searching: _searching,
                onConfirm: _confirm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationConfirmCard extends StatelessWidget {
  const _LocationConfirmCard({
    required this.address,
    required this.region,
    required this.error,
    required this.locating,
    required this.searching,
    required this.onConfirm,
  });

  final ValueNotifier<String> address;
  final ValueNotifier<String?> region;
  final ValueNotifier<String?> error;
  final ValueNotifier<bool> locating;
  final bool searching;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: ValueListenableBuilder<bool>(
        valueListenable: locating,
        builder: (_, isLocating, __) {
          return ValueListenableBuilder<String>(
            valueListenable: address,
            builder: (_, addressText, __) {
              return ValueListenableBuilder<String?>(
                valueListenable: region,
                builder: (_, regionText, __) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: error,
                    builder: (_, errorText, __) {
                      final busy = isLocating || searching;
                      final canConfirm = !busy &&
                          addressText.trim().isNotEmpty &&
                          addressText != 'Locating your position…';
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.grey600,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isLocating ? l10n.resolvingAddress : addressText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (regionText != null && !isLocating)
                                      Text(
                                        regionText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              errorText,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.error),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: canConfirm ? onConfirm : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                l10n.confirmThisLocation,
                                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
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
      ),
    );
  }
}

/// The platform map is built once. Camera moves only update the pin notifier,
/// so dragging does not rebuild the map view.
class _StableLocationMap extends StatefulWidget {
  const _StableLocationMap({
    required this.initialTarget,
    required this.mapStyle,
    required this.moving,
    required this.onCreated,
    required this.onMove,
    required this.onIdle,
  });

  final LatLng initialTarget;
  final String mapStyle;
  final ValueNotifier<bool> moving;
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<LatLng> onMove;
  final VoidCallback onIdle;

  @override
  State<_StableLocationMap> createState() => _StableLocationMapState();
}

class _StableLocationMapState extends State<_StableLocationMap> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.initialTarget, zoom: 16),
          style: widget.mapStyle,
          onMapCreated: widget.onCreated,
          onCameraMove: (position) => widget.onMove(position.target),
          onCameraIdle: widget.onIdle,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          buildingsEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          liteModeEnabled: false,
        ),
        IgnorePointer(
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.moving,
              builder: (_, moving, __) {
                return Transform.translate(
                  offset: const Offset(0, -40),
                  child: SizedBox(
                    width: 56,
                    height: 80,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: moving ? 14 : 8,
                            height: moving ? 6 : 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: moving ? 0.28 : 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          bottom: moving ? 16 : 2,
                          child: const Icon(Icons.location_on, color: AppColors.primary, size: 46),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}
