import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Result of resolving the device's current location.
class ResolvedLocation {
  ResolvedLocation({
    required this.lat,
    required this.lng,
    this.address,
    this.shortAddress,
    this.region,
  });

  final double lat;
  final double lng;

  /// Full single-line address (e.g. "123 Main St, Brooklyn, NY").
  final String? address;

  /// Street / primary line only (e.g. "123 Main St").
  final String? shortAddress;

  /// Locality + region (e.g. "Brooklyn, NY 11201").
  final String? region;
}

/// Raised when we cannot obtain a GPS fix.
class LocationFailure implements Exception {
  LocationFailure(this.message, {this.kind = LocationFailureKind.unknown});

  final String message;
  final LocationFailureKind kind;

  @override
  String toString() => message;
}

enum LocationFailureKind { serviceDisabled, permissionDenied, permissionDeniedForever, unknown }

/// Point used to rank address search. The app's unset pickup is a US
/// coordinate, so that case is biased to central London instead.
class UkSearchBias {
  UkSearchBias._();

  static const londonLat = 51.5074;
  static const londonLng = -0.1278;
  static const fallbackLat = 40.7138;
  static const fallbackLng = -74.0040;

  static ({double lat, double lng}) resolve({
    required double lat,
    required double lng,
    required bool locationResolved,
  }) {
    final isFallback = (lat - fallbackLat).abs() < 0.05 && (lng - fallbackLng).abs() < 0.05;
    if (isFallback) return (lat: londonLat, lng: londonLng);
    if (!locationResolved) return (lat: lat, lng: lng);
    return (lat: lat, lng: lng);
  }
}

String withUnitedKingdomSuffix(String query) {
  final lower = query.toLowerCase();
  if (lower.contains('united kingdom') ||
      lower.endsWith(' uk') ||
      lower.contains(', uk') ||
      lower.contains('great britain')) {
    return query;
  }
  return '$query, United Kingdom';
}

bool isUnitedKingdomPlacemark(Placemark placemark) {
  final code = (placemark.isoCountryCode ?? '').toUpperCase();
  if (code == 'GB') return true;
  final country = (placemark.country ?? '').toLowerCase();
  return country == 'united kingdom' || country == 'uk' || country == 'great britain';
}

/// Keeps the address closest to [lat], [lng].
ResolvedLocation? pickClosestLocation(
  List<ResolvedLocation> options, {
  required double lat,
  required double lng,
}) {
  if (options.isEmpty) return null;
  final ranked = [...options]..sort((a, b) {
      final aMeters = Geolocator.distanceBetween(lat, lng, a.lat, a.lng);
      final bMeters = Geolocator.distanceBetween(lat, lng, b.lat, b.lng);
      return aMeters.compareTo(bMeters);
    });
  return ranked.first;
}

/// Thin wrapper over geolocator + geocoding used by the customer app to
/// resolve the user's pickup location.
class LocationService {
  /// Ensures location services are on and permission is granted, requesting
  /// it when needed. Throws [LocationFailure] otherwise.
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationFailure(
        'Location services are turned off. Please enable them to continue.',
        kind: LocationFailureKind.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationFailure(
        'Location permission denied. Enable it to find nearby drivers.',
        kind: LocationFailureKind.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationFailure(
        'Location permission is permanently denied. Enable it from Settings.',
        kind: LocationFailureKind.permissionDeniedForever,
      );
    }
  }

  /// One-shot current position with reverse-geocoded address.
  Future<ResolvedLocation> getCurrentLocation({bool withAddress = true}) async {
    await ensurePermission();

    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      throw LocationFailure('Could not determine your location. Please try again.');
    }

    if (!withAddress) {
      return ResolvedLocation(lat: position.latitude, lng: position.longitude);
    }

    final resolved = await reverseGeocode(position.latitude, position.longitude);
    return resolved;
  }

  /// Convert coordinates into a human-readable address. Falls back to the
  /// coordinates themselves if geocoding is unavailable.
  Future<ResolvedLocation> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        return _fromPlacemark(lat, lng, placemarks.first);
      }
    } catch (_) {
      // Geocoding can fail offline or on emulators without Google services.
    }
    return ResolvedLocation(lat: lat, lng: lng);
  }

  ResolvedLocation _fromPlacemark(double lat, double lng, Placemark placemark) {
    final street = [placemark.name, placemark.thoroughfare]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toSet()
        .join(' ');
    final locality = [placemark.locality, placemark.administrativeArea, placemark.postalCode]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .join(', ');
    final short = street.isNotEmpty
        ? street
        : (placemark.subLocality ?? placemark.locality ?? 'Current location');
    final full = [short, locality].where((e) => e.trim().isNotEmpty).join(', ');
    return ResolvedLocation(
      lat: lat,
      lng: lng,
      address: full.isNotEmpty ? full : null,
      shortAddress: short,
      region: locality.isNotEmpty ? locality : null,
    );
  }

  /// Convert a typed address into the closest UK match.
  ///
  /// Results outside the United Kingdom are dropped. Among UK matches, the
  /// one nearest [biasLat]/[biasLng] is kept. When no bias is passed, ranking
  /// uses central London so a US hit cannot win.
  Future<ResolvedLocation> forwardGeocode(
    String query, {
    double? biasLat,
    double? biasLng,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw LocationFailure('Enter an address to continue.');
    }
    final nearLat = biasLat ?? UkSearchBias.londonLat;
    final nearLng = biasLng ?? UkSearchBias.londonLng;
    try {
      final locations = await locationFromAddress(withUnitedKingdomSuffix(trimmed));
      if (locations.isEmpty) {
        throw LocationFailure('Could not find that address. Try a more specific one.');
      }
      final ukMatches = <ResolvedLocation>[];
      for (final loc in locations.take(5)) {
        try {
          final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (placemarks.isEmpty || !isUnitedKingdomPlacemark(placemarks.first)) continue;
          ukMatches.add(_fromPlacemark(loc.latitude, loc.longitude, placemarks.first));
        } catch (_) {}
      }
      final closest = pickClosestLocation(ukMatches, lat: nearLat, lng: nearLng);
      if (closest == null) {
        throw LocationFailure('Could not find that UK address. Try a more specific one.');
      }
      return closest;
    } on LocationFailure {
      rethrow;
    } catch (_) {
      throw LocationFailure('Could not find that address. Try a more specific one.');
    }
  }

  /// Continuous position stream (used for live map follow).
  Stream<Position> watchPosition({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
