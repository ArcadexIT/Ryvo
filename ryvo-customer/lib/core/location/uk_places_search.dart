import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'location_service.dart';

/// One UK address suggestion, already ranked near the customer's position.
class UkAddressSuggestion {
  const UkAddressSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.description,
    this.distanceMeters,
    this.resolved,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String description;
  final int? distanceMeters;

  /// Set when this row came from the geocoder fallback and already has a point.
  final ResolvedLocation? resolved;
}

class PlacesLookupException implements Exception {
  PlacesLookupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// UK-only Places autocomplete, biased to a point, with a geocoder fallback.
class UkPlacesSearch {
  UkPlacesSearch({
    Dio? dio,
    LocationService? geocoder,
    String? apiKey,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            )),
        _geocoder = geocoder ?? LocationService(),
        _apiKey = apiKey ?? AppConstants.googleMapsApiKey;

  final Dio _dio;
  final LocationService _geocoder;
  final String _apiKey;

  static const _autocompleteUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';

  /// Empty when [query] is shorter than 2 characters or nothing in the UK matches.
  /// A failed Places call falls back to one nearby UK geocode result.
  Future<List<UkAddressSuggestion>> suggest({
    required String query,
    required double biasLat,
    required double biasLng,
    required String sessionToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];
    final places = await _tryAutocomplete(
      query: trimmed,
      biasLat: biasLat,
      biasLng: biasLng,
      sessionToken: sessionToken,
    );
    if (places != null) return places;
    return _fallbackSuggestion(trimmed, biasLat, biasLng);
  }

  /// Resolves a typed query to a precise UK point: top suggestion, or geocoder.
  Future<ResolvedLocation> resolve({
    required String query,
    required double biasLat,
    required double biasLng,
    required String sessionToken,
  }) async {
    final suggestions = await suggest(
      query: query,
      biasLat: biasLat,
      biasLng: biasLng,
      sessionToken: sessionToken,
    );
    if (suggestions.isNotEmpty) {
      return detailsFor(suggestions.first, sessionToken: sessionToken);
    }
    return _geocoder.forwardGeocode(query, biasLat: biasLat, biasLng: biasLng);
  }

  Future<ResolvedLocation> detailsFor(
    UkAddressSuggestion suggestion, {
    String? sessionToken,
  }) async {
    if (suggestion.resolved != null) return suggestion.resolved!;
    if (suggestion.placeId.isEmpty) {
      throw PlacesLookupException('Could not find that UK address.');
    }
    try {
      final response = await _dio.get<dynamic>(
        _detailsUrl,
        queryParameters: {
          'place_id': suggestion.placeId,
          'fields': 'geometry,formatted_address,name,address_components',
          'language': 'en-GB',
          if (sessionToken != null && sessionToken.isNotEmpty) 'sessiontoken': sessionToken,
          'key': _apiKey,
        },
      );
      final data = response.data;
      if (data is Map) {
        final resolved = parsePlaceDetails(Map<String, dynamic>.from(data));
        if (resolved != null) return resolved;
      }
    } catch (e) {
      if (e is PlacesLookupException) rethrow;
    }
    throw PlacesLookupException('Could not find that UK address. Try a more specific one.');
  }

  Future<List<UkAddressSuggestion>?> _tryAutocomplete({
    required String query,
    required double biasLat,
    required double biasLng,
    required String sessionToken,
  }) async {
    if (_apiKey.trim().isEmpty) return null;
    try {
      final response = await _dio.get<dynamic>(
        _autocompleteUrl,
        queryParameters: {
          'input': query,
          'components': 'country:gb',
          'language': 'en-GB',
          'location': '$biasLat,$biasLng',
          'radius': '50000',
          'origin': '$biasLat,$biasLng',
          'sessiontoken': sessionToken,
          'key': _apiKey,
        },
      );
      final data = response.data;
      if (data is! Map) return null;
      final json = Map<String, dynamic>.from(data);
      final status = json['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') return null;
      return parsePlaceAutocomplete(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<UkAddressSuggestion>> _fallbackSuggestion(
    String query,
    double biasLat,
    double biasLng,
  ) async {
    try {
      final resolved = await _geocoder.forwardGeocode(query, biasLat: biasLat, biasLng: biasLng);
      final meters = distanceMetersBetween(biasLat, biasLng, resolved.lat, resolved.lng);
      return [
        UkAddressSuggestion(
          placeId: '',
          primaryText: resolved.shortAddress ?? resolved.address ?? query,
          secondaryText: resolved.region ?? '',
          description: resolved.address ?? query,
          distanceMeters: meters.round(),
          resolved: resolved,
        ),
      ];
    } catch (_) {
      return [];
    }
  }
}

double distanceMetersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLng = _toRadians(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

List<UkAddressSuggestion> parsePlaceAutocomplete(Map<String, dynamic> json) {
  final predictions = json['predictions'];
  if (predictions is! List) return [];
  final suggestions = <UkAddressSuggestion>[];
  for (final raw in predictions) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final formatting = map['structured_formatting'];
    final structured = formatting is Map ? Map<String, dynamic>.from(formatting) : null;
    final placeId = map['place_id'] as String? ?? '';
    final description = map['description'] as String? ?? '';
    final primary = (structured?['main_text'] as String?)?.trim();
    final secondary = (structured?['secondary_text'] as String?)?.trim() ?? '';
    if (placeId.isEmpty) continue;
    suggestions.add(UkAddressSuggestion(
      placeId: placeId,
      primaryText: (primary == null || primary.isEmpty) ? description : primary,
      secondaryText: secondary,
      description: description,
      distanceMeters: (map['distance_meters'] as num?)?.round(),
    ));
  }
  return suggestions;
}

ResolvedLocation? parsePlaceDetails(Map<String, dynamic> json) {
  if (json['status'] != 'OK') return null;
  final result = json['result'];
  if (result is! Map) return null;
  final map = Map<String, dynamic>.from(result);
  final geometry = map['geometry'];
  if (geometry is! Map) return null;
  final location = geometry['location'];
  if (location is! Map) return null;
  final lat = (location['lat'] as num?)?.toDouble();
  final lng = (location['lng'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;

  final components = map['address_components'];
  String? streetNumber;
  String? route;
  String? town;
  String? postcode;
  if (components is List) {
    for (final raw in components) {
      if (raw is! Map) continue;
      final component = Map<String, dynamic>.from(raw);
      final types = component['types'];
      final typeList = types is List ? types.map((e) => '$e').toList() : const <String>[];
      final longName = (component['long_name'] as String?)?.trim() ?? '';
      if (longName.isEmpty) continue;
      if (typeList.contains('street_number')) streetNumber = longName;
      if (typeList.contains('route')) route = longName;
      if (town == null && (typeList.contains('postal_town') || typeList.contains('locality'))) {
        town = longName;
      }
      if (typeList.contains('postal_code')) postcode = longName;
    }
  }

  final street = [streetNumber, route].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  final region = [town, postcode].whereType<String>().where((part) => part.isNotEmpty).join(', ');
  final formatted = (map['formatted_address'] as String?)?.trim();
  final name = (map['name'] as String?)?.trim();
  final short = street.isNotEmpty ? street : (name ?? formatted);
  return ResolvedLocation(
    lat: lat,
    lng: lng,
    address: (formatted != null && formatted.isNotEmpty) ? formatted : short,
    shortAddress: short,
    region: region.isNotEmpty ? region : null,
  );
}

String formatUkDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

String newPlacesSessionToken() {
  final random = math.Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
