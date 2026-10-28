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
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '$originLat,$originLng',
          'destination': '$destinationLat,$destinationLng',
          'mode': 'driving',
          'key': _apiKey,
        },
      );
      final data = response.data;
      if (data == null || data['status'] != 'OK') {
        return _fetchOsrm(
          originLat: originLat,
          originLng: originLng,
          destinationLat: destinationLat,
          destinationLng: destinationLng,
        );
      }
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final route = routes.first;
      if (route is! Map) return null;
      final encoded = route['overview_polyline']?['points'];
      if (encoded is! String || encoded.isEmpty) return null;
      final legs = route['legs'];
      var durationMin = 0;
      var distanceKm = 0.0;
      if (legs is List && legs.isNotEmpty && legs.first is Map) {
        final leg = legs.first as Map;
        final seconds = leg['duration']?['value'];
        final meters = leg['distance']?['value'];
        if (seconds is num) durationMin = (seconds / 60).ceil();
        if (meters is num) distanceKm = meters / 1000;
      }
      final points = decodePolyline(encoded);
      if (points.length < 2) return null;
      return DrivingRoute(points: points, durationMin: durationMin, distanceKm: distanceKm);
    } catch (_) {
      return _fetchOsrm(
        originLat: originLat,
        originLng: originLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );
    }
  }

  /// Public road geometry when Google Directions is unavailable.
  Future<DrivingRoute?> _fetchOsrm({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving/'
        '$originLng,$originLat;$destinationLng,$destinationLat',
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
