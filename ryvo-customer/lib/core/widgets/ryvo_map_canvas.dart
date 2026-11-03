import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/map_style_utils.dart';
import 'ryvo_live_location_pulse.dart';

/// A driver pin the map eases toward. Location ticks update this target;
/// the canvas interpolates position and bearing so the page does not rebuild.
class DriverPose {
  const DriverPose({
    required this.position,
    this.bearing = 0,
    this.icon,
  });

  final LatLng position;
  final double bearing;
  final BitmapDescriptor? icon;

  @override
  bool operator ==(Object other) {
    return other is DriverPose &&
        other.position == position &&
        other.bearing == bearing &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(position, bearing, icon);
}

/// Where the isolated map should point. [generation] lets a caller repeat the
/// same target (for example, "recenter") and still animate.
class RyvoMapCamera {
  const RyvoMapCamera({
    required this.target,
    this.zoom = 15,
    this.bounds,
    this.generation = 0,
  });

  final LatLng target;
  final double zoom;
  final LatLngBounds? bounds;
  final int generation;

  @override
  bool operator ==(Object other) {
    return other is RyvoMapCamera &&
        other.target == target &&
        other.zoom == zoom &&
        other.bounds == bounds &&
        other.generation == generation;
  }

  @override
  int get hashCode => Object.hash(target, zoom, bounds, generation);
}

/// Full-screen map isolated from overlay rebuilds.
///
/// Subscribes only to [markers], [polylines], and [camera], each through
/// `.select()`. Overlay state (draft text, notifications, profile) must not
/// be watched here.
class RyvoMapCanvas extends ConsumerStatefulWidget {
  const RyvoMapCanvas({
    super.key,
    required this.markers,
    required this.polylines,
    required this.camera,
    this.circles,
    this.driver,
    this.onMapCreated,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.showLiveLocation = false,
    this.boundsPadding = 48,
  });

  final ProviderListenable<Set<Marker>> markers;
  final ProviderListenable<Set<Polyline>> polylines;
  final ProviderListenable<RyvoMapCamera> camera;
  final ProviderListenable<Set<Circle>>? circles;
  final ProviderListenable<DriverPose?>? driver;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final ArgumentCallback<LatLng>? onTap;
  final EdgeInsets padding;

  /// Draws [RyvoLiveLocationPulse] for the device location. The platform blue
  /// dot stays off so the painter is the only current-location mark.
  final bool showLiveLocation;
  final double boundsPadding;

  /// Quiet light basemap. Roads stay neutral so a route polyline and markers
  /// remain the only saturated elements.
  static const String lightStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f8fafc"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f8fafc"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"landscape.man_made","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#e7eee9"}]},
  {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#f1f5f9"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e2e8f0"}]},
  {"featureType":"road.highway","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#d7e4ee"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

  /// True Carbon basemap. Geometry stays in the app's dark ramp.
  static const String darkStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#090a0d"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#090a0d"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"landscape.man_made","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#12151b"}]},
  {"featureType":"poi.park","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1a1e26"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#262b36"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#323846"}]},
  {"featureType":"road.highway","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1720"}]},
  {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
]
''';

  static String styleFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkStyle : lightStyle;
  }

  @override
  ConsumerState<RyvoMapCanvas> createState() => _RyvoMapCanvasState();
}

class _RyvoMapCanvasState extends ConsumerState<RyvoMapCanvas>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  RyvoMapCamera? _pendingCamera;
  late final CameraPosition _initialCamera;
  late final ValueNotifier<CameraPosition> _viewCamera;
  AnimationController? _driverAnim;
  LatLng? _driverFrom;
  LatLng? _driverTo;
  double _bearingFrom = 0;
  double _bearingTo = 0;
  LatLng? _driverShown;
  double _bearingShown = 0;
  BitmapDescriptor? _driverIcon;

  @override
  void initState() {
    super.initState();
    final camera = ref.read(widget.camera);
    _initialCamera = CameraPosition(target: camera.target, zoom: camera.zoom);
    _viewCamera = ValueNotifier(_initialCamera);
    final driver = widget.driver;
    if (driver != null) {
      final pose = ref.read(driver);
      _driverShown = pose?.position;
      _bearingShown = pose?.bearing ?? 0;
      _driverIcon = pose?.icon;
    }
  }

  @override
  void dispose() {
    _viewCamera.dispose();
    _driverAnim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = ref.watch(widget.markers.select((value) => value));
    final polylines = ref.watch(widget.polylines.select((value) => value));
    final circles = widget.circles == null
        ? const <Circle>{}
        : ref.watch(widget.circles!.select((value) => value));
    ref.listen<RyvoMapCamera>(
      widget.camera.select((value) => value),
      (previous, next) => _moveCamera(next),
    );
    final driver = widget.driver;
    if (driver != null) {
      ref.listen<DriverPose?>(driver, (previous, next) => _onDriver(next));
    }

    // Theme.of registers a dependency, so a light/dark flip rebuilds only this
    // State and hands GoogleMap a new `style`. The platform view, camera,
    // markers, and polylines are updated in place, never recreated.
    final style = RyvoMapCanvas.styleFor(Theme.of(context).brightness);
    final shown = _driverShown;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: GoogleMap(
            initialCameraPosition: _initialCamera,
            style: style,
            onMapCreated: _onMapCreated,
            onCameraMove: (position) => _viewCamera.value = position,
            mapType: MapType.normal,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: false,
            tiltGesturesEnabled: false,
            padding: widget.padding,
            markers: {
              ...markers,
              if (shown != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: shown,
                  icon: _driverIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                  anchor: const Offset(0.5, 0.5),
                  flat: true,
                  rotation: _bearingShown,
                  zIndexInt: 4,
                ),
            },
            polylines: polylines,
            circles: circles,
            onTap: widget.onTap,
          ),
        ),
        if (widget.showLiveLocation)
          RyvoLiveLocationPulse(
            camera: _viewCamera,
            padding: widget.padding,
          ),
      ],
    );
  }

  void _onDriver(DriverPose? next) {
    if (!mounted) return;
    if (next == null) {
      _driverAnim?.stop();
      setState(() {
        _driverShown = null;
        _driverIcon = null;
      });
      return;
    }
    _driverIcon = next.icon;
    final current = _driverShown;
    if (current == null) {
      setState(() {
        _driverShown = next.position;
        _bearingShown = next.bearing;
      });
      return;
    }
    final sameSpot = (current.latitude - next.position.latitude).abs() < 1e-7 &&
        (current.longitude - next.position.longitude).abs() < 1e-7 &&
        (_bearingShown - next.bearing).abs() < 0.5;
    if (sameSpot) {
      setState(() {});
      return;
    }
    _driverFrom = current;
    _bearingFrom = _bearingShown;
    _driverTo = next.position;
    _bearingTo = next.bearing;
    _driverAnim ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_tickDriver);
    _driverAnim!.forward(from: 0);
  }

  void _tickDriver() {
    final from = _driverFrom;
    final to = _driverTo;
    final controller = _driverAnim;
    if (!mounted || from == null || to == null || controller == null) return;
    final t = Curves.easeOut.transform(controller.value);
    setState(() {
      _driverShown = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      _bearingShown = _lerpBearing(_bearingFrom, _bearingTo, t);
    });
  }

  double _lerpBearing(double from, double to, double t) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final bearing = from + delta * t;
    final wrapped = bearing % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    widget.onMapCreated?.call(controller);
    if (!mounted) return;
    var active = true;
    assert(() {
      active = (context as Element).debugIsActive;
      return true;
    }());
    if (!active) return;
    final applied = Theme.of(context).brightness;
    await applyMapStyle(controller, RyvoMapCanvas.styleFor(applied));
    if (!mounted) return;
    // Theme flipped while the style was being applied (iOS delays it 300ms).
    final latest = Theme.of(context).brightness;
    if (latest != applied) {
      await applyMapStyle(controller, RyvoMapCanvas.styleFor(latest));
      if (!mounted) return;
    }
    final pending = _pendingCamera;
    if (pending != null) _moveCamera(pending);
  }

  void _moveCamera(RyvoMapCamera camera) {
    final controller = _controller;
    if (controller == null) {
      _pendingCamera = camera;
      return;
    }
    _pendingCamera = null;
    final update = camera.bounds != null
        ? CameraUpdate.newLatLngBounds(camera.bounds!, widget.boundsPadding)
        : CameraUpdate.newLatLngZoom(camera.target, camera.zoom);
    unawaited(
      controller.animateCamera(update).catchError((Object _) {}),
    );
  }
}
