import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/location/route_flow.dart';
import '../../../core/widgets/ryvo_map_canvas.dart';

/// One map channel per trip screen so a location tick on live tracking
/// cannot repaint the request or searching map.
enum TripMapScope { request, searching, live, progress }

final tripMarkersProvider =
    StateProvider.family<Set<Marker>, TripMapScope>((ref, scope) => const {});

final tripPolylinesProvider = StateProvider.family<Set<Polyline>, TripMapScope>(
  (ref, scope) => const {},
);

/// Route the canvas reveals and pulses. The static polylines still travel
/// through [tripPolylinesProvider]; this one only drives the overlay.
final tripRouteFlowProvider =
    StateProvider.family<RouteFlow?, TripMapScope>((ref, scope) => null);

final tripCirclesProvider =
    StateProvider.family<Set<Circle>, TripMapScope>((ref, scope) => const {});

final tripCameraProvider = StateProvider.family<RyvoMapCamera, TripMapScope>(
  (ref, scope) => const RyvoMapCamera(target: LatLng(52.48, -1.89), zoom: 14),
);

final tripDriverProvider =
    StateProvider.family<DriverPose?, TripMapScope>((ref, scope) => null);

/// Nearby drivers keyed by provider id, for screens that show idle cars.
final tripFleetProvider =
    StateProvider.family<Map<String, DriverPose>, TripMapScope>(
  (ref, scope) => const {},
);

class TripRouteMeta {
  const TripRouteMeta({this.minutes, this.km});

  final int? minutes;
  final double? km;
}

final tripRouteMetaProvider = StateProvider.family<TripRouteMeta, TripMapScope>(
  (ref, scope) => const TripRouteMeta(),
);

/// Camera that frames [points]. [generation] forces a repeat of the same frame.
RyvoMapCamera cameraForPoints(
  List<LatLng> points, {
  required int generation,
  double zoom = 15,
  LatLng fallback = const LatLng(52.48, -1.89),
}) {
  if (points.isEmpty) {
    return RyvoMapCamera(target: fallback, zoom: zoom, generation: generation);
  }
  if (points.length == 1) {
    return RyvoMapCamera(
      target: points.first,
      zoom: zoom,
      generation: generation,
    );
  }
  var south = points.first.latitude;
  var north = points.first.latitude;
  var west = points.first.longitude;
  var east = points.first.longitude;
  for (final point in points) {
    if (point.latitude < south) south = point.latitude;
    if (point.latitude > north) north = point.latitude;
    if (point.longitude < west) west = point.longitude;
    if (point.longitude > east) east = point.longitude;
  }
  if (south == north) {
    south -= 0.002;
    north += 0.002;
  }
  if (west == east) {
    west -= 0.002;
    east += 0.002;
  }
  return RyvoMapCamera(
    target: LatLng((south + north) / 2, (west + east) / 2),
    zoom: zoom,
    bounds: LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    ),
    generation: generation,
  );
}
