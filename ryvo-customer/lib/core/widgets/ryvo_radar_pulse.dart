import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

/// Expanding rings drawn above the map, centered on a pickup coordinate.
///
/// Frames stay in Flutter. The painter listens to the camera and the pulse
/// controller, so a tick never crosses the platform channel or rebuilds
/// [GoogleMap].
///
/// [markerAnchor] is `Offset(0.5, 0.5)`: the ring midpoint sits on the
/// coordinate, the same contract as a stop marker anchored at its centre.
class RyvoRadarPulse extends StatefulWidget {
  const RyvoRadarPulse({
    super.key,
    required this.anchor,
    required this.camera,
    this.padding = EdgeInsets.zero,
    this.paddingListenable,
  });

  static const Offset markerAnchor = Offset(0.5, 0.5);

  final ValueListenable<LatLng> anchor;
  final ValueListenable<CameraPosition> camera;
  final EdgeInsets padding;
  final ValueListenable<EdgeInsets>? paddingListenable;

  @override
  State<RyvoRadarPulse> createState() => _RyvoRadarPulseState();
}

class _RyvoRadarPulseState extends State<RyvoRadarPulse>
    with SingleTickerProviderStateMixin {
  static const Duration _period = Duration(milliseconds: 1500);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _period,
  )..repeat();
  late final ValueNotifier<EdgeInsets> _staticPadding =
      ValueNotifier(widget.padding);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _pulse.stop();
    } else {
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RyvoRadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _staticPadding.value = widget.padding;
  }

  @override
  void dispose() {
    _pulse.dispose();
    _staticPadding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.paddingListenable ?? _staticPadding;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RadarPainter(
            repaint: Listenable.merge([
              _pulse,
              widget.anchor,
              widget.camera,
              padding,
            ]),
            pulse: _pulse,
            anchor: widget.anchor,
            camera: widget.camera,
            padding: padding,
            reduceMotion: _reduceMotion,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required Listenable repaint,
    required this.pulse,
    required this.anchor,
    required this.camera,
    required this.padding,
    required this.reduceMotion,
  }) : super(repaint: repaint);

  static const int _rings = 3;
  static const double _maxRadius = 120;

  final Animation<double> pulse;
  final ValueListenable<LatLng> anchor;
  final ValueListenable<CameraPosition> camera;
  final ValueListenable<EdgeInsets> padding;
  final bool reduceMotion;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..isAntiAlias = true;
  final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final insets = padding.value;
    final projector = _RadarProjector(camera.value, size, insets);
    final at = projector.offset(anchor.value);
    // A marker anchor of (0.5, 0.5) places the ring centre on the coordinate.
    const diameter = _maxRadius * 2;
    final center = at +
        Offset(
          (0.5 - RyvoRadarPulse.markerAnchor.dx) * diameter,
          (0.5 - RyvoRadarPulse.markerAnchor.dy) * diameter,
        );
    if (center.dx < -_maxRadius ||
        center.dy < -_maxRadius ||
        center.dx > size.width + _maxRadius ||
        center.dy > size.height + _maxRadius) {
      return;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    const base = AppColors.primary;
    if (reduceMotion) {
      _ring(canvas, center, 0.45, base, opacity: 0.28);
    } else {
      final t = pulse.value;
      for (var i = 0; i < _rings; i++) {
        final raw = (t + i / _rings) % 1.0;
        final eased = Curves.easeOut.transform(raw);
        _ring(canvas, center, eased, base);
      }
    }
    canvas.restore();
  }

  void _ring(Canvas canvas, Offset center, double eased, Color base,
      {double? opacity}) {
    final radius = eased * _maxRadius;
    if (radius < 0.5) return;
    final alpha = opacity ?? (0.8 * (1 - eased));
    if (alpha < 0.02) return;
    _fill.color = base.withValues(alpha: alpha * 0.16);
    _stroke.color = base.withValues(alpha: alpha);
    canvas.drawCircle(center, radius, _fill);
    canvas.drawCircle(center, radius, _stroke);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.anchor != anchor ||
        oldDelegate.camera != camera ||
        oldDelegate.padding != padding ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}

/// Web-mercator camera math shared with the route overlay: 256 * 2^zoom
/// logical pixels for the world, centered in the area left by map padding.
class _RadarProjector {
  _RadarProjector(CameraPosition camera, Size size, EdgeInsets padding)
      : scale = 256.0 * math.pow(2, camera.zoom).toDouble(),
        cosB = math.cos(camera.bearing * math.pi / 180),
        sinB = math.sin(camera.bearing * math.pi / 180),
        cx = padding.left + (size.width - padding.horizontal) / 2,
        cy = padding.top + (size.height - padding.vertical) / 2 {
    final origin = _unit(camera.target);
    ox = origin.dx;
    oy = origin.dy;
  }

  final double scale;
  final double cosB;
  final double sinB;
  final double cx;
  final double cy;
  late final double ox;
  late final double oy;

  static Offset _unit(LatLng point) {
    final sine =
        math.sin(point.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    return Offset(
      (point.longitude + 180) / 360,
      0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi),
    );
  }

  Offset offset(LatLng point) {
    final unit = _unit(point);
    final dx = (unit.dx - ox) * scale;
    final dy = (unit.dy - oy) * scale;
    return Offset(
      cx + dx * cosB + dy * sinB,
      cy - dx * sinB + dy * cosB,
    );
  }
}
