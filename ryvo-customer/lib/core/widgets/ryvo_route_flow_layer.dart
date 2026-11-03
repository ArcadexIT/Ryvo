import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/route_flow.dart';
import '../theme/app_colors.dart';

/// Reveals a route pickup → dropoff, then runs a pulse along it, drawn in
/// Flutter above the map.
///
/// Painting here instead of updating `GoogleMap.polylines` means an animation
/// frame costs no platform-channel message: the map keeps its channel free for
/// camera moves and gestures, and the layer follows the camera through
/// [camera], which `RyvoMapCanvas` feeds from `onCameraMove`.
///
/// Timeline for one [RouteFlow.generation]:
/// * 0–550ms: casing + line grow along the road (`fastOutSlowIn`). Progress is
///   measured in cumulative distance along the road, not in vertex count, so
///   dense curves and long straights are drawn at the same visual speed. A
///   bright head leads the line.
/// * 550ms: [onDrawn] fires so the canvas can show the static native
///   polylines; the layer keeps painting the line for [_handoff] to cover the
///   swap, then paints only the pulse.
/// * afterwards: a segment 25% of the route long loops every 2.2s.
class RyvoRouteFlowLayer extends StatefulWidget {
  const RyvoRouteFlowLayer({
    super.key,
    required this.flow,
    required this.camera,
    required this.onDrawn,
    this.padding = EdgeInsets.zero,
    this.paddingListenable,
  });

  final RouteFlow? flow;
  final ValueListenable<CameraPosition> camera;
  final ValueChanged<int> onDrawn;
  final EdgeInsets padding;

  /// Same inset the map was given; overrides [padding] when present.
  final ValueListenable<EdgeInsets>? paddingListenable;

  @override
  State<RyvoRouteFlowLayer> createState() => _RyvoRouteFlowLayerState();
}

class _RyvoRouteFlowLayerState extends State<RyvoRouteFlowLayer>
    with TickerProviderStateMixin {
  static const Duration _drawDuration = Duration(milliseconds: 550);
  static const Duration _loopDuration = Duration(milliseconds: 2200);
  static const Duration _handoff = Duration(milliseconds: 160);

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: _drawDuration,
  )..addStatusListener(_onDrawStatus);
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _loopDuration,
  );
  late final ValueNotifier<EdgeInsets> _staticPadding =
      ValueNotifier(widget.padding);
  final ValueNotifier<bool> _lineVisible = ValueNotifier(true);

  _RouteGeometry? _geometry;
  int _generation = -1;
  bool _reduceMotion = false;
  Timer? _handoffTimer;

  @override
  void initState() {
    super.initState();
    _begin(widget.flow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _loop.stop();
      if (_geometry != null && !_draw.isCompleted) _draw.value = 1;
    } else if (_draw.isCompleted && _geometry != null) {
      _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RyvoRouteFlowLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _staticPadding.value = widget.padding;
    if (widget.flow?.generation != oldWidget.flow?.generation ||
        !identical(widget.flow?.points, oldWidget.flow?.points)) {
      _begin(widget.flow);
    }
  }

  @override
  void dispose() {
    _handoffTimer?.cancel();
    _draw.dispose();
    _loop.dispose();
    _staticPadding.dispose();
    _lineVisible.dispose();
    super.dispose();
  }

  void _begin(RouteFlow? flow) {
    _handoffTimer?.cancel();
    _draw.stop();
    _loop.stop();
    if (flow == null || flow.points.length < 2) {
      _geometry = null;
      return;
    }
    _geometry = _RouteGeometry.of(flow.points);
    _generation = flow.generation;
    _lineVisible.value = true;
    if (_reduceMotion) {
      _draw.value = 1;
      return;
    }
    _draw.forward(from: 0);
  }

  void _onDrawStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _geometry == null) return;
    final generation = _generation;
    // Never call back into the canvas while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDrawn(generation);
    });
    _handoffTimer?.cancel();
    _handoffTimer = Timer(_handoff, () {
      if (mounted) _lineVisible.value = false;
    });
    if (!_reduceMotion) _loop.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    if (geometry == null) return const SizedBox.shrink();
    final padding = widget.paddingListenable ?? _staticPadding;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RouteFlowPainter(
            repaint: Listenable.merge(
              [_draw, _loop, widget.camera, padding, _lineVisible],
            ),
            geometry: geometry,
            draw: _draw,
            loop: _loop,
            camera: widget.camera,
            padding: padding,
            lineVisible: _lineVisible,
            pulseEnabled: !_reduceMotion,
            dark: AppColors.isDark,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Route vertices in normalized web-mercator space (0..1) with cumulative
/// length, built once per route so a frame only multiplies and adds.
class _RouteGeometry {
  _RouteGeometry._(this.xs, this.ys, this.cumulative);

  factory _RouteGeometry.of(List<LatLng> points) {
    final n = points.length;
    final xs = Float64List(n);
    final ys = Float64List(n);
    final cumulative = Float64List(n);
    for (var i = 0; i < n; i++) {
      final unit = unitOf(points[i]);
      xs[i] = unit.dx;
      ys[i] = unit.dy;
      if (i > 0) {
        final dx = xs[i] - xs[i - 1];
        final dy = ys[i] - ys[i - 1];
        cumulative[i] = cumulative[i - 1] + math.sqrt(dx * dx + dy * dy);
      }
    }
    return _RouteGeometry._(xs, ys, cumulative);
  }

  final Float64List xs;
  final Float64List ys;
  final Float64List cumulative;

  int get length => xs.length;
  double get total => cumulative.last;

  static Offset unitOf(LatLng point) {
    final sine =
        math.sin(point.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    return Offset(
      (point.longitude + 180) / 360,
      0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi),
    );
  }

  /// First index whose cumulative distance is greater than [d].
  int upperIndex(double d) {
    var lo = 0;
    var hi = length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cumulative[mid] > d) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Unit-space point at route distance [d].
  Offset at(double d) {
    if (d <= 0) return Offset(xs.first, ys.first);
    if (d >= total) return Offset(xs.last, ys.last);
    final i = upperIndex(d);
    final span = cumulative[i] - cumulative[i - 1];
    final t = span <= 0 ? 0.0 : (d - cumulative[i - 1]) / span;
    return Offset(
      xs[i - 1] + (xs[i] - xs[i - 1]) * t,
      ys[i - 1] + (ys[i] - ys[i - 1]) * t,
    );
  }
}

/// Unit space → widget pixels, matching Google Maps' camera: 256 * 2^zoom
/// logical pixels for the world, centered in the area left by the map padding.
class _Projector {
  _Projector(CameraPosition camera, Size size, EdgeInsets padding)
      : scale = 256.0 * math.pow(2, camera.zoom),
        cosB = math.cos(camera.bearing * math.pi / 180),
        sinB = math.sin(camera.bearing * math.pi / 180),
        cx = padding.left + (size.width - padding.horizontal) / 2,
        cy = padding.top + (size.height - padding.vertical) / 2 {
    final origin = _RouteGeometry.unitOf(camera.target);
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

  double x(double ux, double uy) {
    final dx = (ux - ox) * scale;
    final dy = (uy - oy) * scale;
    return cx + dx * cosB + dy * sinB;
  }

  double y(double ux, double uy) {
    final dx = (ux - ox) * scale;
    final dy = (uy - oy) * scale;
    return cy - dx * sinB + dy * cosB;
  }

  Offset offset(Offset unit) => Offset(x(unit.dx, unit.dy), y(unit.dx, unit.dy));
}

class _RouteFlowPainter extends CustomPainter {
  _RouteFlowPainter({
    required Listenable repaint,
    required this.geometry,
    required this.draw,
    required this.loop,
    required this.camera,
    required this.padding,
    required this.lineVisible,
    required this.pulseEnabled,
    required this.dark,
  }) : super(repaint: repaint);

  /// Share of the route covered by the moving pulse.
  static const double pulseFraction = 0.25;

  final _RouteGeometry geometry;
  final Animation<double> draw;
  final Animation<double> loop;
  final ValueListenable<CameraPosition> camera;
  final ValueListenable<EdgeInsets> padding;
  final ValueListenable<bool> lineVisible;
  final bool pulseEnabled;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || geometry.total <= 0) return;
    final projector = _Projector(camera.value, size, padding.value);
    final total = geometry.total;
    final drawing = draw.status != AnimationStatus.completed;
    final revealed = drawing
        ? Curves.fastOutSlowIn.transform(draw.value).clamp(0.0, 1.0).toDouble()
        : 1.0;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (drawing || lineVisible.value) {
      final line = _slice(projector, 0, revealed * total);
      if (line != null) {
        canvas.drawPath(
          line,
          _stroke(RouteStyle.casing, RouteStyle.casingWidth),
        );
        canvas.drawPath(
          line,
          _stroke(RouteStyle.base, RouteStyle.baseWidth),
        );
      }
    }

    if (drawing) {
      // The head of the reveal glows while the line is being laid down.
      _paintPulse(
        canvas,
        projector,
        tail: math.max(0.0, revealed - pulseFraction).toDouble(),
        head: revealed,
      );
    } else if (pulseEnabled) {
      // Enters at the pickup and fully leaves past the dropoff.
      final head =
          Curves.easeInOutSine.transform(loop.value) * (1 + pulseFraction);
      _paintPulse(
        canvas,
        projector,
        tail: (head - pulseFraction).clamp(0.0, 1.0).toDouble(),
        head: head.clamp(0.0, 1.0).toDouble(),
      );
    }

    canvas.restore();
  }

  void _paintPulse(
    Canvas canvas,
    _Projector projector, {
    required double tail,
    required double head,
  }) {
    if (head - tail < 0.002) return;
    final total = geometry.total;
    final path = _slice(projector, tail * total, head * total);
    if (path == null) return;
    final from = projector.offset(geometry.at(tail * total));
    final to = projector.offset(geometry.at(head * total));
    final paint = _stroke(RouteStyle.pulse, RouteStyle.baseWidth);
    if ((to - from).distance > 1) {
      paint.shader = ui.Gradient.linear(
        from,
        to,
        [RouteStyle.pulse.withValues(alpha: 0), RouteStyle.pulse],
      );
    }
    canvas.drawPath(path, paint);
  }

  Paint _stroke(Color color, double width) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = width
      ..color = color;
  }

  /// Screen-space path for the stretch between route distances [from], [to].
  Path? _slice(_Projector projector, double from, double to) {
    if (to - from <= 1e-12) return null;
    final path = Path();
    final start = geometry.at(from);
    path.moveTo(projector.x(start.dx, start.dy), projector.y(start.dx, start.dy));
    var i = geometry.upperIndex(from);
    while (i < geometry.length && geometry.cumulative[i] < to) {
      path.lineTo(
        projector.x(geometry.xs[i], geometry.ys[i]),
        projector.y(geometry.xs[i], geometry.ys[i]),
      );
      i++;
    }
    final end = geometry.at(to);
    path.lineTo(projector.x(end.dx, end.dy), projector.y(end.dx, end.dy));
    return path;
  }

  @override
  bool shouldRepaint(covariant _RouteFlowPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.dark != dark ||
        oldDelegate.pulseEnabled != pulseEnabled;
  }
}
