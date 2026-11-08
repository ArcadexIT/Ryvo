import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Signed shortest rotation from [current] to [target], in degrees, within
/// (-180, 180]. A car facing 350° that is told to face 10° turns +20°, never
/// -340°.
double shortestAngleDelta(double current, double target) {
  return ((target - current + 540) % 360) - 180;
}

/// Interpolates between two headings along the shortest arc, wrapped to
/// [0, 360).
double lerpBearing(double from, double to, double t) {
  final wrapped = (from + shortestAngleDelta(from, to) * t) % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

/// Initial great-circle bearing from [from] to [to], in degrees [0, 360).
double bearingBetween(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final dLng = (to.longitude - from.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Rough ground distance in metres. Good enough to tell "parked" from
/// "moving" when deciding whether a heading can be derived.
double approxMeters(LatLng a, LatLng b) {
  const metersPerDegree = 111320.0;
  final dLat = (b.latitude - a.latitude) * metersPerDegree;
  final dLng = (b.longitude - a.longitude) *
      metersPerDegree *
      math.cos(a.latitude * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}
