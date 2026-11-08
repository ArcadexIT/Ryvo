import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

class TripMarkerSet {
  const TripMarkerSet({
    required this.pickup,
    required this.dropoff,
  });

  final BitmapDescriptor pickup;
  final BitmapDescriptor dropoff;
}

/// Compact ride-hailing stop markers. Bitmaps are drawn at the device pixel
/// ratio and handed to the map with the same `imagePixelRatio`, so they keep
/// the logical sizes below on every screen density.
///
/// Driver vehicles are not drawn here; see `DriverMarkerRenderer`.
class TripMarkers {
  TripMarkers._();

  static const Color _pickupColor = AppColors.obsidian;
  static const Color _dropoffColor = AppColors.obsidian;

  static TripMarkerSet? _cache;
  static double? _cachedRatio;

  static const Offset dropoffAnchor = Offset(0.5, 1.0);
  static const Offset pickupAnchor = Offset(0.5, 0.5);

  /// Device pixel ratio of the first view, with a sane fallback for tests.
  static double get _devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 3.0 : views.first.devicePixelRatio;
  }

  /// Builds the set once per pixel ratio. Await this before inserting any
  /// marker so the map never falls back to a stock pin.
  static Future<TripMarkerSet> load({double? devicePixelRatio}) async {
    final ratio = devicePixelRatio ?? _devicePixelRatio;
    final cached = _cache;
    if (cached != null && _cachedRatio == ratio) return cached;
    final set = TripMarkerSet(
      pickup: await _buildDot(ratio),
      dropoff: await _buildPin(ratio),
    );
    _cache = set;
    _cachedRatio = ratio;
    return set;
  }

  static Color get _shadow => AppColors.obsidian.withValues(alpha: 0.2);

  static Future<BitmapDescriptor> _buildDot(double ratio) async {
    const size = 14.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    const center = Offset(size / 2, size / 2);
    final paint = Paint()..isAntiAlias = true;

    paint.color = _shadow;
    canvas.drawCircle(center.translate(0, 0.6), 6.2, paint);
    paint.color = AppColors.white;
    canvas.drawCircle(center, 6.2, paint);
    paint.color = _pickupColor;
    canvas.drawCircle(center, 4.2, paint);

    return _toBitmap(recorder, size, size, ratio);
  }

  static Future<BitmapDescriptor> _buildPin(double ratio) async {
    const width = 18.0;
    const height = 24.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    final paint = Paint()..isAntiAlias = true;
    const cx = width / 2;
    const headCy = 8.0;
    const headR = 6.4;

    paint.color = _shadow;
    canvas.drawCircle(const Offset(cx, height - 1.6), 2, paint);

    final tail = Path()
      ..moveTo(cx, height - 0.4)
      ..lineTo(cx - headR * 0.8, headCy + headR * 0.5)
      ..lineTo(cx + headR * 0.8, headCy + headR * 0.5)
      ..close();
    // White keyline keeps the obsidian pin readable on the dark basemap.
    paint
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(tail, paint);
    canvas.drawCircle(const Offset(cx, headCy), headR, paint);
    paint.style = PaintingStyle.fill;
    paint.color = _dropoffColor;
    canvas.drawPath(tail, paint);
    canvas.drawCircle(const Offset(cx, headCy), headR, paint);
    paint.color = AppColors.white;
    canvas.drawCircle(const Offset(cx, headCy), 2.4, paint);

    return _toBitmap(recorder, width, height, ratio);
  }

  static Future<BitmapDescriptor> _toBitmap(
    ui.PictureRecorder recorder,
    double width,
    double height,
    double ratio,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * ratio).round(),
      (height * ratio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
  }
}
