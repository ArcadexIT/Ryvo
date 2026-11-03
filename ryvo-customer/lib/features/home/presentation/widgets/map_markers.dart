import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// Scale factor for the provider marker: rendered at 2× and shown at the
/// device pixel ratio, which keeps it a medium size on 2×/3× screens.
const double _kScale = 2.0;

/// Which route stop a [MapMarkers.buildStopLabel] marker represents.
enum MapStopKind { pickup, dropoff }

class MapMarkers {
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
    const cx = lw / 2;

    // ── Pill drop shadow ────────────────────────────────────────────
    paint
      ..color = const Color(0x30000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 4, lw - 20, pillH),
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
        const Rect.fromLTWH(8, 2, lw - 16, pillH),
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
    const glowTop = 2 + pillH + caretH;
    const carCenterY = glowTop + carAreaH / 2;
    paint
      ..color = const Color(0x44F59E0B)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(const Offset(cx, carCenterY + 4), glowR, paint);
    paint.maskFilter = null;

    // Subtle amber circle (solid, lighter)
    paint.color = const Color(0x1AF59E0B);
    canvas.drawCircle(const Offset(cx, carCenterY + 4), glowR - 6, paint);

    // ── Car emoji ───────────────────────────────────────────────────
    final carTp = TextPainter(
      text: const TextSpan(
        text: '🚗',
        style: TextStyle(fontSize: carLogical),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    carTp.paint(
      canvas,
      Offset(cx - carTp.width / 2, glowTop + (carAreaH - carTp.height) / 2),
    );

    return _toDescriptor(recorder, lw, lh, _kScale, _devicePixelRatio);
  }

  // ─── Stop nodes (pure geometry, no street names) ──────────────────────────
  //
  // Pickup: round bullseye. Dropoff: square bullseye, optionally topped by a
  // numeric ETA chip ("12 min"). The image is always symmetric around the
  // node, so [stopAnchor] is the exact centre and the node sits dead-centre on
  // the route's start or end vertex.
  static const double _nodeSize = 32;
  static const double _haloR = 14;
  static const double _ringR = 9.5;
  static const double _chipH = 20;
  static const double _chipGap = 4;

  /// Anchor for [buildStopNode]: the node centre is the image centre.
  static const Offset stopAnchor = Offset(0.5, 0.5);

  static final Map<String, BitmapDescriptor> _stopCache = {};

  static double get _devicePixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 3.0 : views.first.devicePixelRatio;
  }

  /// A geometric stop marker. [badge] is a short numeric label such as
  /// "12 min" and only applies to the dropoff; it is never an address.
  /// Results are cached per (kind, badge, ratio).
  static Future<BitmapDescriptor> buildStopNode({
    required MapStopKind kind,
    String? badge,
    double? devicePixelRatio,
  }) async {
    final ratio = devicePixelRatio ?? _devicePixelRatio;
    final isPickup = kind == MapStopKind.pickup;
    final label = isPickup || (badge ?? '').isEmpty ? null : badge;
    final key = '${kind.name}|${label ?? ''}|$ratio';
    final cached = _stopCache[key];
    if (cached != null) return cached;

    TextPainter? badgePainter;
    var chipW = 0.0;
    if (label != null) {
      badgePainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 11,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      chipW = badgePainter.width + 16;
    }

    // Symmetric canvas: the chip's height is mirrored below the node so the
    // node centre is the image centre.
    final reserve = label == null ? 0.0 : _chipH + _chipGap;
    final width = math.max(_nodeSize, chipW).ceilToDouble();
    final height = _nodeSize + reserve * 2;
    final center = Offset(width / 2, height / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    final paint = Paint()..isAntiAlias = true;

    if (badgePainter != null) {
      final chipLeft = (width - chipW) / 2;
      paint.color = AppColors.primaryDark;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chipLeft, 0, chipW, _chipH),
          const Radius.circular(_chipH / 2),
        ),
        paint,
      );
      badgePainter.paint(
        canvas,
        Offset(chipLeft + 8, (_chipH - badgePainter.height) / 2),
      );
    }

    RRect square(double half, double radius) => RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: half * 2, height: half * 2),
          Radius.circular(radius),
        );

    if (isPickup) {
      paint.color = AppColors.primary.withValues(alpha: 0.22);
      canvas.drawCircle(center, _haloR, paint);
      paint.color = AppColors.white;
      canvas.drawCircle(center, _ringR + 1.5, paint);
      paint.color = AppColors.obsidian;
      canvas.drawCircle(center, _ringR, paint);
      paint.color = AppColors.white;
      canvas.drawCircle(center, 3.6, paint);
    } else {
      paint.color = AppColors.obsidian.withValues(alpha: 0.14);
      canvas.drawRRect(square(_haloR, 4), paint);
      paint.color = AppColors.white;
      canvas.drawRRect(square(_ringR + 1.5, 3), paint);
      paint.color = AppColors.obsidian;
      canvas.drawRRect(square(_ringR, 2), paint);
      paint.color = AppColors.white;
      canvas.drawRRect(square(3.4, 0.8), paint);
    }

    final descriptor = await _toDescriptor(
      recorder,
      width,
      height,
      ratio,
      ratio,
    );
    if (_stopCache.length >= 24) _stopCache.remove(_stopCache.keys.first);
    _stopCache[key] = descriptor;
    return descriptor;
  }

  // ─── Shared helper ────────────────────────────────────────────────────────
  // The canvas is pre-scaled by [renderScale], so the image is
  // lw×lh × renderScale pixels. [imagePixelRatio] tells the map how many of
  // those pixels make up one logical pixel, which fixes the on-screen size on
  // every density.
  static Future<BitmapDescriptor> _toDescriptor(
    ui.PictureRecorder recorder,
    double lw,
    double lh,
    double renderScale,
    double imagePixelRatio,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (lw * renderScale).ceil(),
      (lh * renderScale).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: imagePixelRatio,
    );
  }
}
