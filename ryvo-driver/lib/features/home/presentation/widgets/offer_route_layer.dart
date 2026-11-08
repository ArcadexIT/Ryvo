import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// Road geometry to reveal on the offer map.
///
/// A new [generation] restarts the draw. The same point list does not.
class OfferRouteFlow {
  const OfferRouteFlow({required this.points, required this.generation});

  final List<LatLng> points;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is OfferRouteFlow &&
      other.generation == generation &&
      identical(other.points, points);

  @override
  int get hashCode => Object.hash(generation, points);
}

/// Static casing and line handed to the map once the draw finishes.
///
/// The reveal itself is painted by [OfferRouteLayer], so animation frames
/// never cross the platform channel.
class OfferRouteStyle {
  OfferRouteStyle._();

  static const double casingWidth = 9;
  static const double baseWidth = 5;

  static const Color casing = AppColors.navy;
  static const Color base = AppColors.white;
  static const Color pulse = AppColors.primary;

  static Set<Polyline> polylines(List<LatLng> points) {
    if (points.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('route-casing'),
        points: points,
        color: casing,
        width: casingWidth.round(),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        geodesic: false,
        zIndex: 1,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: base,
        width: baseWidth.round(),
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        geodesic: false,
        zIndex: 2,
      ),
    };
  }
}

/// Draws the offer route along the road, then runs a short pulse down it.
///
/// [camera] must be the map's live camera. [padding] must match `GoogleMap.padding`
/// so the line stays locked to the road while the camera eases in.
class OfferRouteLayer extends StatefulWidget {
  const OfferRouteLayer({
    super.key,
    required this.flow,
    required this.camera,
    required this.padding,
    required this.onDrawn,
  });

  final OfferRouteFlow? flow;
  final ValueListenable<CameraPosition> camera;
  final EdgeInsets padding;
  final ValueChanged<int> onDrawn;

  @override
  State<OfferRouteLayer> createState() => _OfferRouteLayerState();
}

class _OfferRouteLayerState extends State<OfferRouteLayer> with TickerProviderStateMixin {
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
  late final ValueNotifier<EdgeInsets> _padding = ValueNotifier(widget.padding);
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
  void didUpdateWidget(covariant OfferRouteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.padding != _padding.value) _padding.value = widget.padding;
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
    _padding.dispose();
    _lineVisible.dispose();
    super.dispose();
  }

  void _begin(OfferRouteFlow? flow) {
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
      if (_draw.value == 1) _draw.value = 0;
      _draw.value = 1;
      return;
    }
    _draw.forward(from: 0);
  }

  void _onDrawStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _geometry == null) return;
    final generation = _generation;
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
    if (geometry == null) return const IgnorePointer(child: SizedBox.expand());
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RoutePainter(
            repaint: Listenable.merge([_draw, _loop, widget.camera, _padding, _lineVisible]),
            geometry: geometry,
            draw: _draw,
            loop: _loop,
            camera: widget.camera,
            padding: _padding,
            lineVisible: _lineVisible,
            pulseEnabled: !_reduceMotion,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

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
  double get total => cumulative.isEmpty ? 0 : cumulative.last;

  static Offset unitOf(LatLng point) {
    final sine = math.sin(point.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
    return Offset(
      (point.longitude + 180) / 360,
      0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi),
    );
  }

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

  Offset at(double d) {
    if (length == 0) return Offset.zero;
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

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required Listenable repaint,
    required this.geometry,
    required this.draw,
    required this.loop,
    required this.camera,
    required this.padding,
    required this.lineVisible,
    required this.pulseEnabled,
  }) : super(repaint: repaint);

  static const double pulseFraction = 0.22;

  final _RouteGeometry geometry;
  final Animation<double> draw;
  final Animation<double> loop;
  final ValueListenable<CameraPosition> camera;
  final ValueListenable<EdgeInsets> padding;
  final ValueListenable<bool> lineVisible;
  final bool pulseEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || geometry.total <= 0) return;
    final projector = _Projector(camera.value, size, padding.value);
    final total = geometry.total;
    final drawing = draw.status != AnimationStatus.completed;
    final revealed = drawing ? Curves.fastOutSlowIn.transform(draw.value).clamp(0.0, 1.0) : 1.0;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (drawing || lineVisible.value) {
      final line = _slice(projector, 0, revealed * total);
      if (line != null) {
        canvas.drawPath(line, _stroke(OfferRouteStyle.casing, OfferRouteStyle.casingWidth));
        canvas.drawPath(line, _stroke(OfferRouteStyle.base, OfferRouteStyle.baseWidth));
      }
    }

    if (drawing) {
      _paintPulse(
        canvas,
        projector,
        tail: math.max(0.0, revealed - pulseFraction),
        head: revealed,
      );
    } else if (pulseEnabled) {
      final head = Curves.easeInOutSine.transform(loop.value) * (1 + pulseFraction);
      _paintPulse(
        canvas,
        projector,
        tail: (head - pulseFraction).clamp(0.0, 1.0),
        head: head.clamp(0.0, 1.0),
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
    final path = _slice(projector, tail * geometry.total, head * geometry.total);
    if (path == null) return;
    canvas.drawPath(path, _stroke(OfferRouteStyle.pulse, OfferRouteStyle.baseWidth));
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

  Path? _slice(_Projector projector, double from, double to) {
    if (to - from <= 1e-12 || geometry.length < 2) return null;
    final path = Path();
    final start = geometry.at(from);
    path.moveTo(projector.x(start.dx, start.dy), projector.y(start.dx, start.dy));
    var i = geometry.upperIndex(from);
    while (i < geometry.length && geometry.cumulative[i] < to) {
      path.lineTo(projector.x(geometry.xs[i], geometry.ys[i]), projector.y(geometry.xs[i], geometry.ys[i]));
      i++;
    }
    final end = geometry.at(to);
    path.lineTo(projector.x(end.dx, end.dy), projector.y(end.dx, end.dy));
    return path;
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.geometry != geometry || oldDelegate.pulseEnabled != pulseEnabled;
  }
}
