import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Thumb slider that commits only after a full swipe.
///
/// Drag updates write straight to an [AnimationController] so the thumb tracks
/// the finger on the display refresh (120Hz included) without [State.setState].
/// A second controller nudges the thumb and walks the chevrons while it is idle.
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

const double _kSwipeHeight = 60;
const double _kSwipeThumb = 52;
const double _kSwipeInset = 4;

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with TickerProviderStateMixin {
  static const double _threshold = 0.85;

  late final AnimationController _motion;
  late final AnimationController _hint;
  bool _dragging = false;
  bool _completed = false;
  bool _midHaptic = false;

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
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _resumeHint();
  }

  @override
  void didUpdateWidget(SwipeToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled && _completed) {
      _completed = false;
      _motion.animateTo(0, curve: Curves.fastOutSlowIn).whenComplete(_resumeHint);
    }
    if (widget.busy || !widget.enabled) {
      _pauseHint();
    } else if (!_dragging && !_completed && _motion.value == 0) {
      _resumeHint();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _pauseHint() {
    if (!_hint.isAnimating && _hint.value == 0) return;
    _hint.stop();
    _hint.value = 0;
  }

  void _resumeHint() {
    if (!mounted || !widget.enabled || widget.busy || _completed || _dragging) {
      return;
    }
    if (_motion.value > 0) return;
    if (!_hint.isAnimating) _hint.repeat();
  }

  void _onDragStart(DragStartDetails _) {
    if (!widget.enabled || _completed) return;
    _dragging = true;
    _midHaptic = false;
    _motion.stop();
    _pauseHint();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxTravel) {
    if (!_dragging || !widget.enabled || _completed || maxTravel <= 0) return;
    final next =
        (_motion.value + details.delta.dx / maxTravel).clamp(0.0, 1.0);
    if (!_midHaptic && next >= 0.5 && _motion.value < 0.5) {
      _midHaptic = true;
      HapticFeedback.selectionClick();
    }
    if (next < 0.4) _midHaptic = false;
    _motion.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final flung = (details.primaryVelocity ?? 0) > 900 && _motion.value > 0.4;
    if (_motion.value >= _threshold || flung) {
      _commit();
      return;
    }
    _motion.animateTo(0, curve: Curves.fastOutSlowIn).whenComplete(_resumeHint);
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    if (!_completed) {
      _motion.animateTo(0, curve: Curves.fastOutSlowIn).whenComplete(_resumeHint);
    }
  }

  Future<void> _commit() async {
    if (!widget.enabled || _completed) return;
    _completed = true;
    _pauseHint();
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
      _resumeHint();
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
                  animation: Listenable.merge([_motion, _hint]),
                  builder: (context, _) {
                    final t = _motion.value;
                    final idle = !_dragging &&
                        t == 0 &&
                        widget.enabled &&
                        !widget.busy &&
                        !_completed;
                    final wave = math.sin(_hint.value * math.pi);
                    final nudge = idle ? 12 * wave : 0.0;
                    final fade = (1 - t * 1.2).clamp(0.0, 1.0);
                    final filled = t >= 0.98 && _completed;
                    final fillWidth = filled
                        ? constraints.maxWidth
                        : _kSwipeInset +
                            _kSwipeThumb * 0.55 +
                            maxTravel * t +
                            nudge;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.obsidian,
                        borderRadius: BorderRadius.circular(_kSwipeHeight / 2),
                        border: Border.all(
                          color: widget.enabled
                              ? AppColors.lime.withValues(alpha: 0.45)
                              : AppColors.divider,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(_kSwipeHeight / 2),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: fillWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.lime.withValues(
                                    alpha: filled ? 1 : 0.22 + 0.35 * t,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 68,
                                  right: 16,
                                ),
                                child: Opacity(
                                  opacity: widget.enabled ? fade : 0.45,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.label,
                                          maxLines: 1,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: AppColors.white,
                                          ),
                                        ),
                                        if (idle) ...[
                                          const SizedBox(width: 2),
                                          _HintChevrons(phase: _hint.value),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(
                                _kSwipeInset + maxTravel * t + nudge,
                                _kSwipeInset,
                              ),
                              child: _SwipeThumb(
                                busy: widget.busy,
                                done: filled,
                                emphasized: idle && wave > 0.65,
                              ),
                            ),
                          ],
                        ),
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

class _HintChevrons extends StatelessWidget {
  const _HintChevrons({required this.phase});

  final double phase;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final local = (phase + index * 0.18) % 1.0;
        final opacity = local < 0.55 ? local / 0.55 : (1 - local) / 0.45;
        return Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: AppColors.lime.withValues(alpha: 0.2 + 0.8 * opacity),
        );
      }),
    );
  }
}

class _SwipeThumb extends StatelessWidget {
  const _SwipeThumb({
    required this.busy,
    required this.done,
    required this.emphasized,
  });

  final bool busy;
  final bool done;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final fill = done ? AppColors.obsidian : AppColors.lime;
    final ink = done ? AppColors.lime : AppColors.obsidian;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.fastOutSlowIn,
      width: _kSwipeThumb,
      height: _kSwipeThumb,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: emphasized ? 0.45 : 0.18),
            blurRadius: emphasized ? 16 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: ink),
            )
          : Icon(
              done
                  ? Icons.check_rounded
                  : Icons.keyboard_double_arrow_right_rounded,
              color: ink,
              size: 26,
            ),
    );
  }
}
