import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/driver_marker_renderer.dart';
import '../location/driver_motion.dart';
import '../location/live_user_location.dart';
import '../location/route_flow.dart';
import '../location/user_location_marker.dart';
import 'ryvo_radar_pulse.dart';
import 'ryvo_route_flow_layer.dart';

/// A driver pin the map eases toward. Location ticks update this target;
/// the canvas interpolates position and bearing so the page does not rebuild.
class DriverPose {
  const DriverPose({
    required this.position,
    this.bearing,
    this.icon,
  });

  final LatLng position;

  /// Heading in degrees. Null means "unknown": the canvas keeps the current
  /// heading, or derives one from the direction of travel.
  final double? bearing;
  final DriverMarkerIcon? icon;

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
    this.fleet,
    this.routeFlow,
    this.radarAnchor,
    this.onMapCreated,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.paddingListenable,
    this.showLiveLocation = false,
    this.boundsPadding = 48,
    this.initialTarget,
    this.initialZoom = 16,
  });

  final ProviderListenable<Set<Marker>> markers;
  final ProviderListenable<Set<Polyline>> polylines;
  final ProviderListenable<RyvoMapCamera> camera;
  final ProviderListenable<Set<Circle>>? circles;
  final ProviderListenable<DriverPose?>? driver;

  /// Nearby drivers keyed by provider id. Each one glides to its next
  /// position and turns along the shortest arc, like [driver].
  final ProviderListenable<Map<String, DriverPose>>? fleet;

  /// Route to reveal and pulse. It is painted by [RyvoRouteFlowLayer] above
  /// the map, so animation frames never reach the platform channel. While a
  /// route is being revealed the static [polylines] are held back and
  /// handed to the map when the reveal ends.
  final ProviderListenable<RouteFlow?>? routeFlow;

  /// Pickup the searching radar expands from. Painted in Flutter, so pulse
  /// frames never update [circles] or rebuild the platform map.
  final ValueListenable<LatLng>? radarAnchor;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final ArgumentCallback<LatLng>? onTap;
  final EdgeInsets padding;

  /// Overrides [padding] and updates it without rebuilding the page. A bottom
  /// sheet publishes its settled height here so the camera keeps the route
  /// centered in the visible part of the map.
  final ValueListenable<EdgeInsets>? paddingListenable;

  /// Places a flat marker on the device GPS coordinate. The platform blue
  /// dot stays off so this marker is the only current-location mark.
  final bool showLiveLocation;
  final double boundsPadding;

  /// Where the platform map is created. Pass the real pickup when [camera]
  /// may still hold a placeholder, so the first frame is that coordinate.
  /// Later [camera] updates still move the map. [GoogleMap.padding] shifts
  /// this target into the visible area above a bottom sheet.
  final LatLng? initialTarget;

  /// Zoom used with [initialTarget].
  final double initialZoom;

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
  BitmapDescriptor? _youIcon;
  late final CameraPosition _initialCamera;
  late final ValueNotifier<CameraPosition> _viewCamera;
  AnimationController? _motion;
  int _drawnGeneration = -1;

  /// Every driver on the map, keyed by marker id. One controller drives all
  /// of them so a refresh of 20 cars is still one tick and one rebuild.
  final Map<String, _DriverTrack> _tracks = {};

  static const String _driverKey = 'driver';
  static const String _fleetPrefix = 'driver-';

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialTarget;
    if (seeded != null) {
      _initialCamera = CameraPosition(target: seeded, zoom: widget.initialZoom);
    } else {
      final camera = ref.read(widget.camera);
      _initialCamera = CameraPosition(target: camera.target, zoom: camera.zoom);
    }
    _viewCamera = ValueNotifier(_initialCamera);
    final driver = widget.driver;
    if (driver != null) _seedTrack(_driverKey, ref.read(driver));
    final fleet = widget.fleet;
    if (fleet != null) {
      ref.read(fleet).forEach((id, pose) => _seedTrack('$_fleetPrefix$id', pose));
    }
    if (widget.showLiveLocation) {
      unawaited(_loadYouIcon());
    }
  }

  Future<void> _loadYouIcon() async {
    final icon = await UserLocationMarker.load();
    if (!mounted) return;
    setState(() => _youIcon = icon);
  }

  @override
  void dispose() {
    _viewCamera.dispose();
    _motion?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = ref.watch(widget.markers.select((value) => value));
    final flow = widget.routeFlow == null
        ? null
        : ref.watch(widget.routeFlow!.select((value) => value));
    final allPolylines =
        ref.watch(widget.polylines.select((value) => value));
    // The native line waits for the reveal so it does not pop in first.
    final polylines = flow != null && flow.generation != _drawnGeneration
        ? const <Polyline>{}
        : allPolylines;
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
    final fleet = widget.fleet;
    if (fleet != null) {
      ref.listen<Map<String, DriverPose>>(
        fleet,
        (previous, next) => _onFleet(next),
      );
    }

    // Theme.of registers a dependency, so a light/dark flip rebuilds only this
    // State and hands GoogleMap a new `style`. The platform view, camera,
    // markers, and polylines are updated in place, never recreated.
    final style = RyvoMapCanvas.styleFor(Theme.of(context).brightness);
    final driverMarkers = _driverMarkers();
    final you = widget.showLiveLocation
        ? ref.watch(
            liveUserLocationProvider.select((async) => async.valueOrNull),
          )
        : null;
    final youIcon = _youIcon;

    Widget buildMap(EdgeInsets padding) {
      return GoogleMap(
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
        padding: padding,
        markers: {
          ...markers,
          ...driverMarkers,
          if (you != null && youIcon != null)
            Marker(
              markerId: UserLocationMarker.id,
              position: you,
              icon: youIcon,
              anchor: UserLocationMarker.anchor,
              flat: true,
              zIndexInt: 5,
            ),
        },
        polylines: polylines,
        circles: circles,
        onTap: widget.onTap,
      );
    }

    final paddingListenable = widget.paddingListenable;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: paddingListenable == null
              ? buildMap(widget.padding)
              : ValueListenableBuilder<EdgeInsets>(
                  valueListenable: paddingListenable,
                  builder: (context, padding, _) => buildMap(padding),
                ),
        ),
        if (widget.routeFlow != null)
          RyvoRouteFlowLayer(
            flow: flow,
            camera: _viewCamera,
            padding: widget.padding,
            paddingListenable: paddingListenable,
            onDrawn: (generation) {
              if (!mounted || _drawnGeneration == generation) return;
              setState(() => _drawnGeneration = generation);
            },
          ),
        if (widget.radarAnchor != null)
          RyvoRadarPulse(
            anchor: widget.radarAnchor!,
            camera: _viewCamera,
            padding: widget.padding,
            paddingListenable: paddingListenable,
          ),
      ],
    );
  }

  /// Driver markers for this frame. A track is drawn only once its bitmap
  /// exists, so a stock pin never flashes in first.
  List<Marker> _driverMarkers() {
    final markers = <Marker>[];
    _tracks.forEach((key, track) {
      final icon = track.icon;
      if (icon == null) return;
      markers.add(
        Marker(
          markerId: MarkerId(key),
          position: track.shown,
          icon: icon.descriptor,
          anchor: DriverMarkerRenderer.anchor,
          flat: true,
          rotation: icon.rotates ? track.bearing : 0,
          zIndexInt: key == _driverKey ? 4 : 3,
        ),
      );
    });
    return markers;
  }

  void _seedTrack(String key, DriverPose? pose) {
    if (pose == null) return;
    _tracks[key] = _DriverTrack(
      position: pose.position,
      bearing: pose.bearing ?? 0,
      icon: pose.icon,
    );
  }

  void _onDriver(DriverPose? next) {
    if (!mounted) return;
    if (next == null) {
      _tracks.remove(_driverKey);
      setState(() {});
      return;
    }
    final moving = _retarget(_driverKey, next);
    setState(() {});
    if (moving) _startMotion();
  }

  void _onFleet(Map<String, DriverPose> next) {
    if (!mounted) return;
    final wanted = {for (final id in next.keys) '$_fleetPrefix$id'};
    _tracks.removeWhere(
      (key, _) => key.startsWith(_fleetPrefix) && !wanted.contains(key),
    );
    var moving = false;
    next.forEach((id, pose) {
      if (_retarget('$_fleetPrefix$id', pose)) moving = true;
    });
    setState(() {});
    if (moving) _startMotion();
  }

  /// Points [key]'s track at [pose]. Returns true when it has to travel.
  bool _retarget(String key, DriverPose pose) {
    final track = _tracks[key];
    if (track == null) {
      _seedTrack(key, pose);
      return false;
    }
    track.icon = pose.icon;
    // A tween already in flight resumes from where the marker is drawn now.
    final from = track.shown;
    final to = pose.position;
    final travelled = approxMeters(from, to);
    // Heading wins when reported. Otherwise face the direction of travel, and
    // hold the last heading while the car is (nearly) stationary.
    final bearing = pose.bearing ??
        (travelled > 3 ? bearingBetween(from, to) : track.bearing);
    final turn = shortestAngleDelta(track.bearing, bearing).abs();
    if (travelled < 0.01 && turn < 0.5) {
      track.settle();
      return false;
    }
    track.retarget(to, bearing);
    return true;
  }

  void _startMotion() {
    final controller = _motion ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_tickMotion);
    controller.forward(from: 0);
  }

  void _tickMotion() {
    final controller = _motion;
    if (!mounted || controller == null) return;
    final t = Curves.easeOut.transform(controller.value);
    setState(() {
      for (final track in _tracks.values) {
        track.advance(t);
      }
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    widget.onMapCreated?.call(controller);
    if (!mounted) return;
    // The basemap style is applied through GoogleMap.style in build(), which
    // also follows theme flips, so there is nothing to set on the controller.
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
    // GoogleMap.padding shifts the visual center, so this target lands in the
    // map area above the bottom sheet rather than under the nav bar.
    final update = camera.bounds != null
        ? CameraUpdate.newLatLngBounds(camera.bounds!, widget.boundsPadding)
        : CameraUpdate.newLatLngZoom(camera.target, camera.zoom);
    unawaited(
      controller.animateCamera(update).catchError((Object _) {}),
    );
  }
}

/// Animation state for one driver marker. [advance] maps a 0..1 progress
/// onto the straight line between the two positions and the shortest arc
/// between the two headings.
class _DriverTrack {
  _DriverTrack({
    required LatLng position,
    required double bearing,
    this.icon,
  })  : shown = position,
        bearing = bearing,
        _from = position,
        _to = position,
        _bearingFrom = bearing,
        _bearingTo = bearing;

  DriverMarkerIcon? icon;
  LatLng shown;
  double bearing;

  LatLng _from;
  LatLng _to;
  double _bearingFrom;
  double _bearingTo;

  void retarget(LatLng to, double bearingTo) {
    _from = shown;
    _to = to;
    _bearingFrom = bearing;
    _bearingTo = bearingTo;
  }

  void settle() {
    _from = shown;
    _to = shown;
    _bearingFrom = bearing;
    _bearingTo = bearing;
  }

  void advance(double t) {
    shown = LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );
    bearing = lerpBearing(_bearingFrom, _bearingTo, t);
  }
}
