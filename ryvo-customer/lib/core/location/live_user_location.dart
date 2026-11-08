import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../shared/providers/app_providers.dart';

/// Device GPS for the current-location marker. Emits the last known fix,
/// then a fresh high-accuracy lock, then movement. The map selects the
/// coordinate so a tick does not rebuild the page.
final liveUserLocationProvider = StreamProvider<LatLng>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.watchLatLng().map((fix) => LatLng(fix.lat, fix.lng));
});
