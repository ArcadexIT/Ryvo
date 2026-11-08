import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Thumb slider that commits only after a full swipe.
///
/// Drag updates write straight to an [AnimationController] so the thumb tracks
/// the finger on the display refresh (120Hz included) without [State.setState].
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.busy = false,
  });

  final String label;

  /// Return false to spring the thumb back (validation or request failed).
  final Future<bool> Function() onConfirmed;
  final bool enabled;
  final bool busy;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

const double _kSwipeHeight = 64;
const double _kSwipeThumb = 56;
const double _kSwipeInset = 4;

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 0.85;

  late final AnimationController _motion;
  bool _dragging = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didUpdateWidget(SwipeToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled && _completed) {
      _completed = false;
      _motion.animateTo(0, curve: Curves.fastOutSlowIn);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    if (!widget.enabled || _completed) return;
    _dragging = true;
    _motion.stop();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxTravel) {
    if (!_dragging || !widget.enabled || _completed || maxTravel <= 0) return;
    _motion.value =
        (_motion.value + details.delta.dx / maxTravel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final flung = (details.primaryVelocity ?? 0) > 900 && _motion.value > 0.4;
    if (_motion.value >= _threshold || flung) {
      _commit();
      return;
    }
    _motion.animateTo(0, curve: Curves.fastOutSlowIn);
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    if (!_completed) {
      _motion.animateTo(0, curve: Curves.fastOutSlowIn);
    }
  }

  Future<void> _commit() async {
    if (!widget.enabled || _completed) return;
    _completed = true;
    try {
      await _motion.animateTo(
        1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.fastOutSlowIn,
      );
    } catch (_) {
      return;
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final accepted = await widget.onConfirmed();
    if (!mounted) return;
    if (!accepted) {
      _completed = false;
      try {
        await _motion.animateTo(0, curve: Curves.fastOutSlowIn);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: widget.label,
        onTap: widget.enabled && !_completed ? _commit : null,
        child: SizedBox(
          height: _kSwipeHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxTravel =
                  (constraints.maxWidth - _kSwipeThumb - _kSwipeInset * 2)
                      .clamp(0.0, double.infinity);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: (details) =>
                    _onDragUpdate(details, maxTravel),
                onHorizontalDragEnd: _onDragEnd,
                onHorizontalDragCancel: _onDragCancel,
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) {
                    final t = _motion.value;
                    final fade = (1 - t * 1.15).clamp(0.0, 1.0);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.enabled
                            ? AppColors.lime
                            : AppColors.lime.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(_kSwipeHeight / 2),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 72, right: 16),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.obsidian.withValues(
                                        alpha: widget.enabled ? fade : 0.55),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(
                                _kSwipeInset + maxTravel * t, _kSwipeInset),
                            child: _SwipeThumb(
                                busy: widget.busy,
                                done: t >= 0.98 && _completed),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SwipeThumb extends StatelessWidget {
  const _SwipeThumb({required this.busy, required this.done});

  final bool busy;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSwipeThumb,
      height: _kSwipeThumb,
      decoration: BoxDecoration(
        color: AppColors.lime,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.obsidian, width: 1.5),
      ),
      alignment: Alignment.center,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: AppColors.obsidian),
            )
          : Icon(
              done
                  ? Icons.check_rounded
                  : Icons.keyboard_double_arrow_right_rounded,
              color: AppColors.obsidian,
              size: 28,
            ),
    );
  }
}
