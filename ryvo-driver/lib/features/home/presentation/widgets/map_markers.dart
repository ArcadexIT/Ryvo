import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerAsset {
  final BitmapDescriptor icon;
  final Offset anchor;

  const MapMarkerAsset({required this.icon, required this.anchor});
}

/// Small, map-friendly marker bitmaps.
class MapMarkers {
  static const double _bitmapScale = 2.0;

  /// Provider location — compact blue dot (home map default).
  static Future<MapMarkerAsset> buildProviderLocationMarker({double markerScale = 1.0}) async {
    final s = (markerScale * 0.72).clamp(0.55, 0.85);
    const base = 36.0;
    final lw = base * s;
    final lh = base * s;
    final cx = lw / 2;
    final cy = lh / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_bitmapScale);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x264285F4);
    canvas.drawCircle(Offset(cx, cy), 14 * s, paint);
    paint.color = const Color(0x444285F4);
    canvas.drawCircle(Offset(cx, cy), 10 * s, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), 7 * s, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawCircle(Offset(cx, cy), 5 * s, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), 2 * s, paint);

    return MapMarkerAsset(
      icon: await _toBitmap(recorder, lw, lh),
      anchor: const Offset(0.5, 0.5),
    );
  }

  /// Tiny car badge on location dot (optional home variant).
  static Future<MapMarkerAsset> buildProviderCarMarker({double markerScale = 1.0}) async {
    final s = (markerScale * 0.68).clamp(0.52, 0.8);
    final lw = 40.0 * s;
    final lh = 44.0 * s;
    final cx = lw / 2;
    final cy = lh * 0.54;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_bitmapScale);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x224285F4);
    canvas.drawCircle(Offset(cx, cy), 16 * s, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), 11 * s, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawCircle(Offset(cx, cy), 9 * s, paint);

    _drawMiniCar(canvas, Offset(cx, cy), 5.5 * s, Colors.white);

    return MapMarkerAsset(
      icon: await _toBitmap(recorder, lw, lh),
      anchor: Offset(0.5, cy / lh),
    );
  }

  /// Small customer pin with compact distance pill.
  static Future<MapMarkerAsset> buildCustomerJobMarker(
    String distanceLabel, {
    double markerScale = 1.0,
    Color pinColor = const Color(0xFFEF4444),
  }) async {
    final s = (markerScale * 0.7).clamp(0.55, 0.85);
    final fontSize = (9.5 * s).clamp(8.0, 11.0);

    final labelTp = TextPainter(
      text: TextSpan(
        text: distanceLabel,
        style: TextStyle(color: pinColor, fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillH = 22.0 * s;
    final caretH = 5.0 * s;
    final pinH = 30.0 * s;
    final lw = (labelTp.width + 18 * s).clamp(72.0 * s, 120.0 * s);
    final lh = pillH + caretH + pinH;
    final cx = lw / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_bitmapScale);

    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(4 * s, 1 * s, lw - 8 * s, pillH), Radius.circular(pillH / 2)),
      paint,
    );

    final caret = Path()
      ..moveTo(cx - 4 * s, 1 * s + pillH)
      ..lineTo(cx + 4 * s, 1 * s + pillH)
      ..lineTo(cx, 1 * s + pillH + caretH)
      ..close();
    canvas.drawPath(caret, paint);

    labelTp.paint(canvas, Offset(cx - labelTp.width / 2, 1 * s + (pillH - labelTp.height) / 2));

    final pinTop = 1 * s + pillH + caretH;
    final pinCy = pinTop + 10 * s;
    paint.color = pinColor;
    canvas.drawCircle(Offset(cx, pinCy), 9 * s, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, pinCy), 3.5 * s, paint);

    final pinPath = Path()
      ..moveTo(cx, pinCy + 11 * s)
      ..lineTo(cx - 6 * s, pinCy + 3 * s)
      ..lineTo(cx + 6 * s, pinCy + 3 * s)
      ..close();
    paint.color = pinColor;
    canvas.drawPath(pinPath, paint);

    final pinTipY = pinCy + 11 * s;

    return MapMarkerAsset(
      icon: await _toBitmap(recorder, lw, lh),
      anchor: Offset(0.5, pinTipY / lh),
    );
  }

  static Future<BitmapDescriptor> buildCustomerMarker({double markerScale = 1.0}) async {
    final asset = await buildCustomerJobMarker('', markerScale: markerScale);
    return asset.icon;
  }

  static void _drawMiniCar(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size * 1.5;
    final h = size * 0.85;
    final left = center.dx - w / 2;
    final top = center.dy - h / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top + h * 0.2, w, h * 0.6), Radius.circular(size * 0.2)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left + w * 0.2, top, w * 0.6, h * 0.5), Radius.circular(size * 0.15)),
      paint,
    );
  }

  static Future<BitmapDescriptor> _toBitmap(ui.PictureRecorder recorder, double w, double h) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage((w * _bitmapScale).toInt(), (h * _bitmapScale).toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
