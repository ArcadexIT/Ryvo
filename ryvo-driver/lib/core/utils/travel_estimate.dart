import 'dart:math' as math;

class TravelEstimate {
  final String distance;
  final String eta;

  const TravelEstimate({required this.distance, required this.eta});

  static const unknown = TravelEstimate(distance: '—', eta: '—');
}

bool _hasPosition(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat == 0 && lng == 0) return false;
  return lat.abs() <= 90 && lng.abs() <= 180;
}

/// Straight-line kilometres between two WGS84 points.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRad(double deg) => deg * math.pi / 180;

String formatDistanceKm(double km) {
  if (km < 0.1) {
    final meters = (km * 1000).round();
    return '$meters m';
  }
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.toStringAsFixed(0)} km';
}

String formatEtaMinutes(int minutes) {
  final mins = minutes < 1 ? 1 : minutes;
  return mins == 1 ? '1 min' : '$mins mins';
}

/// Minutes at a typical urban speed of 40 km/h, matching the API estimate.
int etaMinutesForKm(double km) => math.max(1, (km / 40 * 60).round());

/// Distance and arrival time from the provider to the customer pickup.
/// Live GPS wins over the server estimate. A stored trip distance of 0
/// (services with no drop-off) is treated as unknown.
TravelEstimate travelEstimateFor({
  double? pickupLat,
  double? pickupLng,
  double? providerLat,
  double? providerLng,
  double? serverDistanceKm,
  int? serverEtaMinutes,
}) {
  double? km;
  if (_hasPosition(pickupLat, pickupLng) && _hasPosition(providerLat, providerLng)) {
    km = haversineKm(providerLat!, providerLng!, pickupLat!, pickupLng!);
  } else if (serverDistanceKm != null && serverDistanceKm > 0) {
    km = serverDistanceKm;
  }

  if (km == null) {
    if (serverEtaMinutes != null && serverEtaMinutes > 0) {
      return TravelEstimate(distance: '—', eta: formatEtaMinutes(serverEtaMinutes));
    }
    return TravelEstimate.unknown;
  }

  return TravelEstimate(
    distance: formatDistanceKm(km),
    eta: formatEtaMinutes(etaMinutesForKm(km)),
  );
}
