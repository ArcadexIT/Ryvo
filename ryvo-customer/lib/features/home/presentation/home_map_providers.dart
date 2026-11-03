import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/widgets/ryvo_map_canvas.dart';

/// Marker set for [RyvoMapCanvas] on the home map. Nothing else should write it.
final homeMapMarkersProvider = StateProvider<Set<Marker>>((ref) => const {});

/// Route lines for the home map. Empty until a route is published.
final homeMapPolylinesProvider =
    StateProvider<Set<Polyline>>((ref) => const {});

/// Camera requests for the home map. Bump [RyvoMapCamera.generation] to recenter.
final homeMapCameraProvider = StateProvider<RyvoMapCamera>(
  (ref) => const RyvoMapCamera(target: LatLng(40.7138, -74.0040), zoom: 14.5),
);

/// True while the home pickup pin is being resolved. Overlays read this so the
/// map widget itself does not rebuild for a spinner.
final homeMapLocatingProvider = StateProvider<bool>((ref) => false);
