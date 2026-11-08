import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/models/models.dart';
import '../widgets/ryvo_map_canvas.dart';
import 'driver_marker_renderer.dart';

/// Turns a nearby-providers response into poses for [RyvoMapCanvas.fleet].
///
/// Icons come from [DriverMarkerRenderer], so a repeat refresh reuses the
/// cached bitmaps and only the positions change.
Future<Map<String, DriverPose>> buildNearbyFleet(
  List<NearbyProvider> providers,
) async {
  final plotted =
      providers.where((p) => p.lat != null && p.lng != null).toList();
  final icons = await Future.wait(
    plotted.map((p) => DriverMarkerRenderer.load(imageUrl: p.vehicleImageUrl)),
  );
  return {
    for (var i = 0; i < plotted.length; i++)
      plotted[i].id: DriverPose(
        position: LatLng(plotted[i].lat!, plotted[i].lng!),
        bearing: plotted[i].heading,
        icon: icons[i],
      ),
  };
}
