import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../shared/providers/app_providers.dart';

/// Device location for the live map pulse. Emits the last known fix first,
/// then GPS updates. Overlay widgets should `.select()` the coordinate so a
/// tick never rebuilds the map.
final liveUserLocationProvider = StreamProvider<LatLng>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.watchLatLng().map((fix) => LatLng(fix.lat, fix.lng));
});
