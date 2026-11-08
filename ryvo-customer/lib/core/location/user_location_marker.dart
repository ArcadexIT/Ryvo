import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// Geographic current-location dot. The bitmap is centered, so
/// [anchor] `Offset(0.5, 0.5)` sits on the GPS coordinate.
class UserLocationMarker {
  UserLocationMarker._();

  static const MarkerId id = MarkerId('current_location');
  static const Offset anchor = Offset(0.5, 0.5);

  static BitmapDescriptor? _cache;
  static double? _cachedRatio;

  static double get _devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 3.0 : views.first.devicePixelRatio;
  }

  static Future<BitmapDescriptor> load({double? devicePixelRatio}) async {
    final ratio = devicePixelRatio ?? _devicePixelRatio;
    final cached = _cache;
    if (cached != null && _cachedRatio == ratio) return cached;
    final icon = await _build(ratio);
    _cache = icon;
    _cachedRatio = ratio;
    return icon;
  }

  static Future<BitmapDescriptor> _build(double ratio) async {
    const size = 16.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    const center = Offset(size / 2, size / 2);
    final paint = Paint()..isAntiAlias = true;
    paint.color = AppColors.white;
    canvas.drawCircle(center, 7, paint);
    paint.color = AppColors.primary;
    canvas.drawCircle(center, 4.5, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size * ratio).ceil(),
      (size * ratio).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
  }
}
