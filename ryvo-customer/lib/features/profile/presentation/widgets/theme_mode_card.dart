import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// One tactile HUD card of the Appearance screen (Light / Dark / System).
///
/// Selection plays three things at once, all driven by a single controller:
///  - a spring-physics bounce (`Curves.elasticOut`) with a small lift,
///  - a crisp 2px emerald-to-lime border with a soft bloom,
///  - the mode icon's micro-animation (rays spin, moon tilts and sparkles,
///    the system disc flips).
///
/// [onSelected] receives the exact `TapDownDetails.globalPosition` so the
/// theme portal can expand from the finger.
class ThemeModeCard extends StatefulWidget {
  const ThemeModeCard({
    super.key,
    required this.mode,
    required this.label,
    required this.caption,
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode mode;
  final String label;
  final String caption;
  final bool selected;
  final ValueChanged<Offset> onSelected;

  @override
  State<ThemeModeCard> createState() => _ThemeModeCardState();
}

class _ThemeModeCardState extends State<ThemeModeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _select;
  late final CurvedAnimation _spring;
  Offset _tapDown = Offset.zero;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _select = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      reverseDuration: const Duration(milliseconds: 220),
      value: widget.selected ? 1 : 0,
    );
    _spring = CurvedAnimation(
      parent: _select,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(ThemeModeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (widget.selected) {
      _select.forward(from: 0);
    } else {
      _select.reverse();
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    _select.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final iconColors = _IconColors(
      idle: AppColors.textSecondary,
      body: switch (widget.mode) {
        ThemeMode.light => AppColors.sunCore,
        ThemeMode.dark =>
          AppColors.isDark ? AppColors.moonLight : AppColors.moonShade,
        ThemeMode.system => AppColors.textPrimary,
      },
      accent: widget.mode == ThemeMode.light
          ? AppColors.sunRay
          : AppColors.glowEmerald,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          _tapDown = details.globalPosition;
          setState(() => _pressed = true);
        },
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => widget.onSelected(_tapDown),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.fastOutSlowIn,
          child: AnimatedBuilder(
            animation: _spring,
            builder: (context, child) {
              final spring = _spring.value;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(0, -5 * spring, 0, 1)
                  ..scaleByDouble(
                    1 + 0.03 * spring,
                    1 + 0.03 * spring,
                    1,
                    1,
                  ),
                child: child,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.fastOutSlowIn,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? Colors.transparent : AppColors.divider,
                ),
              ),
              child: CustomPaint(
                foregroundPainter: _GlowBorderPainter(progress: _spring),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: const Size.square(56),
                          painter: _ModeIconPainter(
                            mode: widget.mode,
                            progress: _select,
                            colors: iconColors,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.label,
                        maxLines: 1,
                        style: RyvoTypography.style(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RyvoTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textHint,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2px emerald-to-lime ring plus a soft bloom, faded in by the spring.
class _GlowBorderPainter extends CustomPainter {
  _GlowBorderPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  final Paint _bloom = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final amount = progress.value.clamp(0.0, 1.0);
    if (amount < 0.01) return;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(22),
    );
    _bloom.color = AppColors.glowEmerald.withValues(alpha: 0.34 * amount);
    canvas.drawRRect(rrect, _bloom);
    _ring.shader = ui.Gradient.sweep(
      size.center(Offset.zero),
      [
        AppColors.glowEmerald.withValues(alpha: amount),
        AppColors.lime.withValues(alpha: amount),
        AppColors.glowEmerald.withValues(alpha: amount),
      ],
      const [0, 0.5, 1],
      TileMode.clamp,
      math.pi / 4,
      math.pi / 4 + math.pi * 2,
    );
    canvas.drawRRect(rrect, _ring);
  }

  @override
  bool shouldRepaint(_GlowBorderPainter old) => old.progress != progress;
}

class _IconColors {
  const _IconColors({
    required this.idle,
    required this.body,
    required this.accent,
  });

  final Color idle;
  final Color body;
  final Color accent;

  @override
  bool operator ==(Object other) =>
      other is _IconColors &&
      other.idle == idle &&
      other.body == body &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(idle, body, accent);
}

/// Vector icons for the three modes. `progress` (0 idle, 1 selected) drives
/// the micro-animation; colors blend from [_IconColors.idle] as it rises.
class _ModeIconPainter extends CustomPainter {
  _ModeIconPainter({
    required this.mode,
    required this.progress,
    required this.colors,
  }) : super(repaint: progress);

  final ThemeMode mode;
  final Animation<double> progress;
  final _IconColors colors;

  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value.clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final unit = size.shortestSide / 56;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(unit);
    switch (mode) {
      case ThemeMode.light:
        _sun(canvas, p);
      case ThemeMode.dark:
        _moon(canvas, p);
      case ThemeMode.system:
        _system(canvas, p);
    }
    canvas.restore();
  }

  Color _tint(Color active, double p) => Color.lerp(colors.idle, active, p)!;

  void _sun(Canvas canvas, double p) {
    const radius = 10.0;
    final spin = Curves.easeOutBack.transform(p) * math.pi / 2;
    final reach = ui.lerpDouble(5, 9.5, Curves.elasticOut.transform(p))!;
    _line
      ..strokeWidth = 2.6
      ..color = _tint(colors.accent, p);
    for (var i = 0; i < 8; i++) {
      final angle = spin + i * math.pi / 4;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          dir * (radius + 5), dir * (radius + 5 + reach * 0.62), _line);
    }
    _fill.color = _tint(colors.body, p);
    canvas.drawCircle(Offset.zero, radius, _fill);
  }

  void _moon(Canvas canvas, double p) {
    const radius = 15.0;
    canvas.save();
    canvas.rotate(ui.lerpDouble(-0.6, 0, Curves.easeOutBack.transform(p))!);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
      Path()
        ..addOval(
          Rect.fromCircle(
            center: const Offset(8, -6),
            radius: radius * 0.86,
          ),
        ),
    );
    _fill.color = _tint(colors.body, p);
    canvas.drawPath(crescent, _fill);
    canvas.restore();

    // Sparkles pop in on selection.
    final pop = Curves.elasticOut.transform(p);
    _fill.color = colors.accent.withValues(alpha: p);
    canvas.drawCircle(const Offset(14, -12), 2.2 * pop, _fill);
    canvas.drawCircle(const Offset(20, -2), 1.5 * pop, _fill);
    canvas.drawCircle(const Offset(10, -20), 1.3 * pop, _fill);
  }

  void _system(Canvas canvas, double p) {
    const radius = 16.0;
    canvas.save();
    canvas.rotate(Curves.easeInOutCubic.transform(p) * math.pi);
    final disc = Rect.fromCircle(center: Offset.zero, radius: radius);
    _line
      ..strokeWidth = 2.4
      ..color = _tint(colors.body, p);
    canvas.drawCircle(Offset.zero, radius, _line);
    _fill.color = _tint(colors.body, p);
    canvas.drawArc(disc, math.pi / 2, math.pi, true, _fill);
    _fill.color = _tint(colors.accent, p);
    canvas.drawCircle(const Offset(7, 0), 3.2, _fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ModeIconPainter old) {
    return old.mode != mode || old.progress != progress || old.colors != colors;
  }
}
