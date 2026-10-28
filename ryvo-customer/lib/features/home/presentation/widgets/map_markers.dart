import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Scale factor: render bitmaps at 2× logical size — medium size on
/// high-DPI (2×/3×) Android/iOS screens.
const double _kScale = 2.0;

class MapMarkers {
  // ─── "You" marker ────────────────────────────────────────────────────────
  // Blue pulsing rings  +  white/blue dot  +  "You" speech bubble above
  static Future<BitmapDescriptor> buildYouMarker() async {
    // Logical canvas size
    const double lw = 160;
    const double lh = 160;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_kScale);

    final paint = Paint();
    const cx = lw / 2;
    const cy = lh / 2 + 16;

    // Outermost pulse ring
    paint
      ..color = const Color(0x194285F4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), 64, paint);

    // Middle pulse ring
    paint.color = const Color(0x334285F4);
    canvas.drawCircle(const Offset(cx, cy), 46, paint);

    // Inner pulse ring
    paint.color = const Color(0x554285F4);
    canvas.drawCircle(const Offset(cx, cy), 30, paint);

    // White ring
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(cx, cy), 19, paint);

    // Blue filled dot
    paint.color = const Color(0xFF4285F4);
    canvas.drawCircle(const Offset(cx, cy), 13, paint);

    // White centre
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(cx, cy), 5, paint);

    // Speech bubble
    final bubblePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 28, cy - 80, 56, 30),
        const Radius.circular(15),
      ),
      bubblePaint,
    );

    // Bubble caret
    final caret = Path()
      ..moveTo(cx - 7, cy - 50)
      ..lineTo(cx + 7, cy - 50)
      ..lineTo(cx, cy - 40)
      ..close();
    canvas.drawPath(caret, bubblePaint);

    // "You" text
    final tp = TextPainter(
      text: const TextSpan(
        text: 'You',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - 77));

    return _toDescriptor(recorder, lw, lh);
  }

  // ─── Provider marker ─────────────────────────────────────────────────────
  // Large 🚗 emoji  +  floating white pill above with ETA + distance
  static Future<BitmapDescriptor> buildProviderMarker(
      String eta, String dist) async {
    // Logical dimensions
    const double lw = 160;
    const double pillH = 46.0;
    const double caretH = 12.0;
    const double glowR = 36.0;
    const double carLogical = 54.0; // font size
    const double carAreaH = 64.0;  // total height of car + glow zone
    const double lh = pillH + caretH + carAreaH + 4;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_kScale);

    final paint = Paint();
    final cx = lw / 2;

    // ── Pill drop shadow ────────────────────────────────────────────
    paint
      ..color = const Color(0x30000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 4, lw - 20, pillH),
        const Radius.circular(pillH / 2),
      ),
      paint,
    );
    paint.maskFilter = null;

    // ── Pill background ─────────────────────────────────────────────
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 2, lw - 16, pillH),
        const Radius.circular(pillH / 2),
      ),
      paint,
    );

    // ── Caret ───────────────────────────────────────────────────────
    final caretPath = Path()
      ..moveTo(cx - 9, 2 + pillH)
      ..lineTo(cx + 9, 2 + pillH)
      ..lineTo(cx, 2 + pillH + caretH)
      ..close();
    paint.color = Colors.white;
    canvas.drawPath(caretPath, paint);

    // ── ETA text (bold, dark) ───────────────────────────────────────
    final etaTp = TextPainter(
      text: TextSpan(
        text: eta,
        style: const TextStyle(
          color: Color(0xFF0D0D0D),
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // ── Separator dot ───────────────────────────────────────────────
    final dotTp = TextPainter(
      text: const TextSpan(
        text: ' · ',
        style: TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // ── Distance text (grey) ────────────────────────────────────────
    final distTp = TextPainter(
      text: TextSpan(
        text: dist,
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centre the three pieces inside the pill
    final totalW = etaTp.width + dotTp.width + distTp.width;
    final startX = cx - totalW / 2;
    final textY = 2 + (pillH - etaTp.height) / 2;
    etaTp.paint(canvas, Offset(startX, textY));
    dotTp.paint(canvas, Offset(startX + etaTp.width, textY + 1.5));
    distTp.paint(canvas, Offset(startX + etaTp.width + dotTp.width, textY + 1));

    // ── Amber glow behind car emoji ─────────────────────────────────
    final glowTop = 2 + pillH + caretH;
    final carCenterY = glowTop + carAreaH / 2;
    paint
      ..color = const Color(0x44F59E0B)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset(cx, carCenterY + 4), glowR, paint);
    paint.maskFilter = null;

    // Subtle amber circle (solid, lighter)
    paint.color = const Color(0x1AF59E0B);
    canvas.drawCircle(Offset(cx, carCenterY + 4), glowR - 6, paint);

    // ── Car emoji ───────────────────────────────────────────────────
    final carTp = TextPainter(
      text: TextSpan(
        text: '🚗',
        style: TextStyle(fontSize: carLogical),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    carTp.paint(
      canvas,
      Offset(cx - carTp.width / 2, glowTop + (carAreaH - carTp.height) / 2),
    );

    return _toDescriptor(recorder, lw, lh);
  }

  /// Pill label that sits on a route stop, with the pin at the bottom center.
  static Future<BitmapDescriptor> buildStopLabel({
    required String title,
    required String subtitle,
    required Color color,
  }) async {
    const double lw = 148;
    const double lh = 78;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_kScale);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: lw - 24);
    final subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: lw - 24);

    final textWidth = math.max(titlePainter.width, subtitlePainter.width);
    final pillWidth = textWidth + 28;
    final pillLeft = (lw - pillWidth) / 2;
    const pillTop = 4.0;
    const pillHeight = 46.0;
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
        const Radius.circular(12),
      ),
      paint,
    );
    final caret = Path()
      ..moveTo(lw / 2 - 7, pillTop + pillHeight)
      ..lineTo(lw / 2 + 7, pillTop + pillHeight)
      ..lineTo(lw / 2, pillTop + pillHeight + 8)
      ..close();
    canvas.drawPath(caret, paint);
    titlePainter.paint(canvas, Offset((lw - titlePainter.width) / 2, 10));
    subtitlePainter.paint(canvas, Offset((lw - subtitlePainter.width) / 2, 28));
    canvas.drawCircle(const Offset(lw / 2, 70), 5, Paint()..color = color);
    canvas.drawCircle(const Offset(lw / 2, 70), 2.5, Paint()..color = Colors.white);

    return _toDescriptor(recorder, lw, lh);
  }

  // ─── Shared helper ────────────────────────────────────────────────────────
  // Canvas is pre-scaled by _kScale, so the image dimensions are lw×lh × _kScale.
  // google_maps_flutter renders BitmapDescriptor.fromBytes at the image's raw
  // pixel size divided by the device's screen density, giving the correct
  // logical size on both 2× and 3× screens.
  static Future<BitmapDescriptor> _toDescriptor(
      ui.PictureRecorder recorder, double lw, double lh) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (lw * _kScale).toInt(),
      (lh * _kScale).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}
