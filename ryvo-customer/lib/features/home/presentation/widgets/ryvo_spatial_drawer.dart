import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// iOS-style spatial reveal. The [drawer] stays on the back layer. [child]
/// (the map scaffold) scales, rounds, and slides right without rebuilding.
class RyvoSpatialDrawerController extends StatefulWidget {
  const RyvoSpatialDrawerController({
    super.key,
    required this.drawer,
    required this.child,
  });

  final Widget drawer;
  final Widget child;

  static RyvoSpatialDrawerControllerState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<RyvoSpatialDrawerControllerState>();
  }

  @override
  State<RyvoSpatialDrawerController> createState() =>
      RyvoSpatialDrawerControllerState();
}

class RyvoSpatialDrawerControllerState
    extends State<RyvoSpatialDrawerController>
    with SingleTickerProviderStateMixin {
  static const double _travelFraction = 0.60;
  static const double _openScale = 0.92;
  static const double _openRadius = 32;
  static const double _edgeWidth = 72;
  static const double _snapThreshold = 0.2;
  static const double _flickVelocity = 350;

  late final AnimationController _motion;
  bool _edgeDrag = false;
  bool _cardDrag = false;
  bool _playedThresholdHaptic = false;

  bool get isOpen => _motion.value >= _snapThreshold;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      lowerBound: -0.2,
      upperBound: 1.2,
      duration: const Duration(milliseconds: 420),
      value: 0,
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> open() => _snap(1);

  Future<void> close() => _snap(0);

  Future<void> toggle() => isOpen ? close() : open();

  double get _travel {
    final width = MediaQuery.sizeOf(context).width;
    return width * _travelFraction;
  }

  void _beginEdgeDrag() {
    _edgeDrag = true;
    _playedThresholdHaptic = false;
    _motion.stop();
  }

  void _beginCardDrag() {
    _cardDrag = true;
    _playedThresholdHaptic = false;
    _motion.stop();
  }

  void _nudge(double delta) {
    final travel = _travel;
    if (travel <= 0) return;
    final previous = _motion.value;
    final next = (previous + delta / travel).clamp(0.0, 1.0);
    final wasOpen = previous >= _snapThreshold;
    final nowOpen = next >= _snapThreshold;
    if (wasOpen != nowOpen) {
      _playedThresholdHaptic = true;
      HapticFeedback.lightImpact();
    }
    _motion.value = next;
  }

  void _finishDrag(double velocity) {
    if (!_edgeDrag && !_cardDrag) return;
    _edgeDrag = false;
    _cardDrag = false;
    final shouldOpen = velocity > _flickVelocity ||
        (velocity >= -_flickVelocity && _motion.value >= _snapThreshold);
    _snap(shouldOpen ? 1 : 0);
  }

  Future<void> _snap(double target) {
    if (!mounted) return Future<void>.value();
    final from = _motion.value;
    final crosses = (from < _snapThreshold && target >= _snapThreshold) ||
        (from >= _snapThreshold && target < _snapThreshold);
    if (crosses && !_playedThresholdHaptic) {
      HapticFeedback.lightImpact();
    }
    _playedThresholdHaptic = false;
    final distance = (target - from).abs().clamp(0.0, 1.2);
    return _motion.animateTo(
      target,
      duration: Duration(milliseconds: (220 + 200 * distance).round()),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ColoredBox(color: AppColors.background),
        RepaintBoundary(child: widget.drawer),
        AnimatedBuilder(
          animation: _motion,
          child: RepaintBoundary(
            child: _EdgeDragSurface(
              edgeWidth: _edgeWidth,
              enabled: () => _motion.value < 0.04 && !_cardDrag,
              onStart: _beginEdgeDrag,
              onUpdate: _nudge,
              onEnd: _finishDrag,
              child: widget.child,
            ),
          ),
          builder: (context, child) {
            final t = _motion.value;
            final width = MediaQuery.sizeOf(context).width;
            final interactive = _cardDrag || t > 0.04;
            final radius = _openRadius * t.clamp(0.0, 1.08);
            final scale = 1 - (1 - _openScale) * t;
            return Transform.translate(
              offset: Offset(width * _travelFraction * t, 0),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: interactive
                      ? HitTestBehavior.opaque
                      : HitTestBehavior.deferToChild,
                  onTap: interactive ? close : null,
                  onHorizontalDragStart:
                      interactive ? (_) => _beginCardDrag() : null,
                  onHorizontalDragUpdate: interactive
                      ? (details) => _nudge(details.primaryDelta ?? 0)
                      : null,
                  onHorizontalDragEnd: interactive
                      ? (details) => _finishDrag(details.primaryVelocity ?? 0)
                      : null,
                  onHorizontalDragCancel:
                      interactive ? () => _finishDrag(0) : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.obsidian.withValues(
                            alpha: 0.32 * t.clamp(0.0, 1.0),
                          ),
                          blurRadius: 28,
                          offset: Offset(-8 * t.clamp(0.0, 1.0), 0),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          top: MediaQuery.paddingOf(context).top + 64,
          bottom: 0,
          width: _edgeWidth,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final armed = _edgeDrag || _motion.value < 0.02;
              return IgnorePointer(
                ignoring: !armed,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onHorizontalDragStart: (_) => _beginEdgeDrag(),
                  onHorizontalDragUpdate: (details) =>
                      _nudge(details.primaryDelta ?? 0),
                  onHorizontalDragEnd: (details) =>
                      _finishDrag(details.primaryVelocity ?? 0),
                  onHorizontalDragCancel: () => _finishDrag(0),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Claims a left-to-right drag that starts in the edge gutter without
/// taking taps away from the profile button or the map.
class _EdgeDragSurface extends StatelessWidget {
  const _EdgeDragSurface({
    required this.edgeWidth,
    required this.enabled,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  final double edgeWidth;
  final bool Function() enabled;
  final VoidCallback onStart;
  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        _RevealEdgeRecognizer:
            GestureRecognizerFactoryWithHandlers<_RevealEdgeRecognizer>(
          () => _RevealEdgeRecognizer(edgeWidth: edgeWidth, enabled: enabled),
          (_RevealEdgeRecognizer instance) {
            instance.onStart = (_) => onStart();
            instance.onUpdate =
                (details) => onUpdate(details.primaryDelta ?? 0);
            instance.onEnd = (details) => onEnd(details.primaryVelocity ?? 0);
            instance.onCancel = () => onEnd(0);
          },
        ),
      },
      child: child,
    );
  }
}

class _RevealEdgeRecognizer extends HorizontalDragGestureRecognizer {
  _RevealEdgeRecognizer({
    required this.edgeWidth,
    required this.enabled,
  });

  final double edgeWidth;
  final bool Function() enabled;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!enabled() || event.localPosition.dx > edgeWidth) return;
    super.addAllowedPointer(event);
  }
}
