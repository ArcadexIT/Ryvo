import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripMarkerSet {
  const TripMarkerSet({
    required this.pickup,
    required this.dropoff,
    required this.car,
  });

  final BitmapDescriptor pickup;
  final BitmapDescriptor dropoff;
  final BitmapDescriptor car;
}

/// Compact ride-hailing markers. Bitmaps are drawn at 3× and shown at the
/// logical sizes below so they stay small on every screen density.
class TripMarkers {
  TripMarkers._();

  static const Color _pickupColor = Color(0xFF16A34A);
  static const Color _dropoffColor = Color(0xFF111827);
  static const Color _carColor = Color(0xFF111827);
  static const double _scale = 3.0;

  static TripMarkerSet? _cache;

  static const Offset dropoffAnchor = Offset(0.5, 1.0);
  static const Offset pickupAnchor = Offset(0.5, 0.5);
  static const Offset carAnchor = Offset(0.5, 0.5);

  static Future<TripMarkerSet> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final set = TripMarkerSet(
      pickup: await _buildDot(),
      dropoff: await _buildPin(),
      car: await _buildCar(),
    );
    _cache = set;
    return set;
  }

  static Future<BitmapDescriptor> _buildDot() async {
    const size = 14.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_scale);
    const center = Offset(size / 2, size / 2);
    final paint = Paint()..isAntiAlias = true;

    paint.color = const Color(0x33000000);
    canvas.drawCircle(center.translate(0, 0.6), 6.2, paint);
    paint.color = Colors.white;
    canvas.drawCircle(center, 6.2, paint);
    paint.color = _pickupColor;
    canvas.drawCircle(center, 4.2, paint);

    return _toBitmap(recorder, size, size);
  }

  static Future<BitmapDescriptor> _buildPin() async {
    const width = 18.0;
    const height = 24.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_scale);
    final paint = Paint()..isAntiAlias = true;
    const cx = width / 2;
    const headCy = 8.0;
    const headR = 6.4;

    paint.color = const Color(0x33000000);
    canvas.drawCircle(const Offset(cx, height - 1.6), 2, paint);

    final tail = Path()
      ..moveTo(cx, height - 0.4)
      ..lineTo(cx - headR * 0.8, headCy + headR * 0.5)
      ..lineTo(cx + headR * 0.8, headCy + headR * 0.5)
      ..close();
    paint.color = _dropoffColor;
    canvas.drawPath(tail, paint);
    canvas.drawCircle(const Offset(cx, headCy), headR, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(cx, headCy), 2.4, paint);

    return _toBitmap(recorder, width, height);
  }

  static Future<BitmapDescriptor> _buildCar() async {
    const width = 22.0;
    const height = 32.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_scale);
    const cx = width / 2;
    const cy = height / 2;
    final paint = Paint()..isAntiAlias = true;

    paint.color = const Color(0x33000000);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy + 1), width: 15, height: 23),
      paint,
    );

    final outline = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(cx, cy), width: 15.2, height: 25.2),
      const Radius.circular(5),
    );
    paint.color = Colors.white;
    canvas.drawRRect(outline, paint);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(cx, cy), width: 13.2, height: 23.2),
      const Radius.circular(4),
    );
    paint.color = _carColor;
    canvas.drawRRect(body, paint);

    paint.color = const Color(0xFFD1D5DB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy - 5.2), width: 8.4, height: 5.4),
        const Radius.circular(1.4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy + 5.6), width: 8.4, height: 4.6),
        const Radius.circular(1.4),
      ),
      paint,
    );

    return _toBitmap(recorder, width, height);
  }

  static Future<BitmapDescriptor> _toBitmap(
    ui.PictureRecorder recorder,
    double width,
    double height,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * _scale).round(),
      (height * _scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: _scale,
      width: width,
      height: height,
    );
  }
}
