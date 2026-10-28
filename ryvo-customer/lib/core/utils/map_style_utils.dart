import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Applies a JSON map style after the native map view is ready.
///
/// On iOS, styling too early can leave a blank map (location dot only).
Future<void> applyMapStyle(GoogleMapController controller, String style) async {
  if (Platform.isIOS) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  try {
    await controller.setMapStyle(style);
  } catch (e) {
    if (kDebugMode) debugPrint('Google Map style failed: $e');
  }
}
