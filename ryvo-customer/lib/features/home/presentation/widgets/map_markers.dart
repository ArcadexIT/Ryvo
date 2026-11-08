import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// Which route stop a [MapMarkers.buildStopLabel] marker represents.
enum MapStopKind { pickup, dropoff }

class MapMarkers {
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
