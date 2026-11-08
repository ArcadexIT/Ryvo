import 'package:flutter/painting.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// A route to reveal and animate on top of the map.
///
/// The map itself only ever receives the two static polylines from
/// [RouteStyle.polylines]. The reveal and the moving pulse are painted by
/// `RyvoRouteFlowLayer`, so no animation frame crosses the platform channel.
/// A new [generation] restarts the draw-in.
class RouteFlow {
  const RouteFlow({required this.points, required this.generation});

  final List<LatLng> points;
  final int generation;

  /// True when [a] and [b] describe the same road, so a repeat publish does
  /// not restart the animation.
  static bool sameRoute(List<LatLng>? a, List<LatLng>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length || a.isEmpty) return false;
    final mid = a.length ~/ 2;
    return a.first == b.first && a.last == b.last && a[mid] == b[mid];
  }

  @override
  bool operator ==(Object other) =>
      other is RouteFlow &&
      other.generation == generation &&
      identical(other.points, points);

  @override
  int get hashCode => Object.hash(generation, points);
}

/// Ride-hailing route colors: a solid obsidian line with a white casing on the
/// light map, inverted on the dark map. Emerald is reserved for the moving
/// pulse so the route reads as one calm line with a single accent.
class RouteStyle {
  RouteStyle._();

  static const double casingWidth = 9;
  static const double baseWidth = 5;

  static const PolylineId casingId = PolylineId('route-casing');
  static const PolylineId baseId = PolylineId('route');

  static Color get casing =>
      AppColors.isDark ? AppColors.obsidian : AppColors.white;

  static Color get base =>
      AppColors.isDark ? AppColors.white : AppColors.obsidian;

  static Color get pulse => AppColors.primary;

  /// Static casing + line handed to [GoogleMap]. Published once per route.
  static Set<Polyline> polylines(List<LatLng> points) {
    if (points.length < 2) return const {};
    return {
      Polyline(
        polylineId: casingId,
        points: points,
        color: casing,
        width: casingWidth.round(),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
      Polyline(
        polylineId: baseId,
        points: points,
        color: base,
        width: baseWidth.round(),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
      ),
    };
  }
}
