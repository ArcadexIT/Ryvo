import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/app_constants.dart';

class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.durationMin,
    required this.distanceKm,
  });

  final List<LatLng> points;
  final int durationMin;
  final double distanceKm;
}

/// Driving path from the Google Directions API. Returns null when the road
/// route cannot be loaded, so the map can fall back to a straight line.
class DrivingRouteService {
  DrivingRouteService({Dio? dio, String? apiKey})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            )),
        _apiKey = apiKey ?? AppConstants.googleMapsApiKey;

  final Dio _dio;
  final String _apiKey;

  Future<DrivingRoute?> fetch({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    List<LatLng> via = const [],
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '$originLat,$originLng',
          'destination': '$destinationLat,$destinationLng',
          'mode': 'driving',
          'key': _apiKey,
          if (via.isNotEmpty)
            'waypoints': via.map((stop) => '${stop.latitude},${stop.longitude}').join('|'),
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') {
        return await _fetchOsrm(
          originLat: originLat,
          originLng: originLng,
          destinationLat: destinationLat,
          destinationLng: destinationLng,
          via: via,
        );
      }
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        return await _fetchOsrm(
          originLat: originLat,
          originLng: originLng,
          destinationLat: destinationLat,
          destinationLng: destinationLng,
          via: via,
        );
      }
      final route = routes.first as Map;
      final points = _pointsFromGoogleRoute(route);
      if (points.length < 2) {
        return await _fetchOsrm(
          originLat: originLat,
          originLng: originLng,
          destinationLat: destinationLat,
          destinationLng: destinationLng,
          via: via,
        );
      }
      final legs = route['legs'];
      var secondsTotal = 0.0;
      var metersTotal = 0.0;
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map) continue;
          final seconds = leg['duration']?['value'];
          final meters = leg['distance']?['value'];
          if (seconds is num) secondsTotal += seconds;
          if (meters is num) metersTotal += meters;
        }
      }
      return DrivingRoute(
        points: points,
        durationMin: secondsTotal <= 0 ? 0 : (secondsTotal / 60).ceil(),
        distanceKm: metersTotal / 1000,
      );
    } catch (_) {
      return await _fetchOsrm(
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        via: via,
      );
    }
  }

  /// Public road geometry when Google Directions is unavailable.
  Future<DrivingRoute?> _fetchOsrm({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    List<LatLng> via = const [],
  }) async {
    try {
      final stops = [
        '$originLng,$originLat',
        for (final stop in via) '${stop.longitude},${stop.latitude}',
        '$destinationLng,$destinationLat',
      ].join(';');
      final response = await _dio.get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving/$stops',
        queryParameters: const {
          'overview': 'full',
          'geometries': 'polyline',
        },
      );
      final data = response.data;
      if (data == null || data['code'] != 'Ok') return null;
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
      final route = routes.first as Map;
      final encoded = route['geometry'];
      if (encoded is! String || encoded.isEmpty) return null;
      final points = decodePolyline(encoded);
      if (points.length < 2) return null;
      final seconds = route['duration'];
      final meters = route['distance'];
      return DrivingRoute(
        points: points,
        durationMin: seconds is num ? (seconds / 60).ceil() : 0,
        distanceKm: meters is num ? meters / 1000 : 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Step polylines follow the carriageway. The overview is only a fallback.
List<LatLng> _pointsFromGoogleRoute(Map route) {
  final points = <LatLng>[];
  final legs = route['legs'];
  if (legs is List) {
    for (final leg in legs) {
      if (leg is! Map) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;
      for (final step in steps) {
        if (step is! Map) continue;
        final encoded = step['polyline']?['points'];
        if (encoded is! String || encoded.isEmpty) continue;
        _appendDecoded(points, decodePolyline(encoded));
      }
    }
  }
  if (points.length >= 2) return points;
  final encoded = route['overview_polyline']?['points'];
  if (encoded is String && encoded.isNotEmpty) return decodePolyline(encoded);
  return points;
}

void _appendDecoded(List<LatLng> into, List<LatLng> decoded) {
  if (decoded.isEmpty) return;
  if (into.isEmpty) {
    into.addAll(decoded);
    return;
  }
  final sameStart = into.last.latitude == decoded.first.latitude &&
      into.last.longitude == decoded.first.longitude;
  into.addAll(sameStart ? decoded.skip(1) : decoded);
}

List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += deltaLat;

    shift = 0;
    result = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += deltaLng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
