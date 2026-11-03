import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/live_user_location.dart';
import '../theme/app_colors.dart';

/// Live user dot drawn above the map. The pulse is a [CustomPainter] driven by
/// an [AnimationController], so frames do not rebuild [GoogleMap].
class RyvoLiveLocationPulse extends ConsumerStatefulWidget {
  const RyvoLiveLocationPulse({
    super.key,
    required this.camera,
    this.padding = EdgeInsets.zero,
  });

  /// Current map camera. Updated from `onCameraMove` without `setState`.
  final ValueNotifier<CameraPosition> camera;
  final EdgeInsets padding;

  @override
  ConsumerState<RyvoLiveLocationPulse> createState() =>
      _RyvoLiveLocationPulseState();
}

class _RyvoLiveLocationPulseState extends ConsumerState<RyvoLiveLocationPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = ref.watch(
      liveUserLocationProvider.select((async) => async.valueOrNull),
    );
    if (point == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LivePulsePainter(
            repaint: Listenable.merge([_pulse, widget.camera]),
            pulse: _pulse,
            camera: widget.camera,
            point: point,
            padding: widget.padding,
            fill: AppColors.primary,
            stroke: AppColors.white,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LivePulsePainter extends CustomPainter {
  _LivePulsePainter({
    required Listenable repaint,
    required this.pulse,
    required this.camera,
    required this.point,
    required this.padding,
    required this.fill,
    required this.stroke,
  }) : super(repaint: repaint);

  final Animation<double> pulse;
  final ValueNotifier<CameraPosition> camera;
  final LatLng point;
  final EdgeInsets padding;
  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = projectLatLng(
      point: point,
      camera: camera.value,
      size: size,
      padding: padding,
    );
    if (center.dx < -80 ||
        center.dy < -80 ||
        center.dx > size.width + 80 ||
        center.dy > size.height + 80) {
      return;
    }

    final t = Curves.easeOutCubic.transform(pulse.value);
    final ringRadius = 12 + t * 36;
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = fill.withValues(alpha: (1 - t) * 0.55),
    );

    canvas.drawCircle(center, 6.5, Paint()..color = fill);
    canvas.drawCircle(
      center,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LivePulsePainter oldDelegate) {
    return oldDelegate.point != point ||
        oldDelegate.padding != padding ||
        oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke;
  }
}

/// Projects a coordinate into the map widget, matching Google Maps' web
/// mercator camera. [padding] is the same inset passed to [GoogleMap].
Offset projectLatLng({
  required LatLng point,
  required CameraPosition camera,
  required Size size,
  required EdgeInsets padding,
}) {
  final scale = 256.0 * math.pow(2, camera.zoom);
  Offset world(LatLng ll) {
    final sine = math.sin(ll.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    final x = (ll.longitude + 180) / 360 * scale;
    final y = (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * scale;
    return Offset(x, y);
  }

  final origin = world(camera.target);
  final target = world(point);
  var dx = target.dx - origin.dx;
  if (dx > scale / 2) dx -= scale;
  if (dx < -scale / 2) dx += scale;
  final dy = target.dy - origin.dy;

  final bearing = camera.bearing * math.pi / 180;
  final cosB = math.cos(bearing);
  final sinB = math.sin(bearing);
  final rx = dx * cosB + dy * sinB;
  final ry = -dx * sinB + dy * cosB;

  final center = Offset(
    padding.left + (size.width - padding.horizontal) / 2,
    padding.top + (size.height - padding.vertical) / 2,
  );
  return center + Offset(rx, ry);
}
