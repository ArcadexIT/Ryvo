import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Live morphing preview for the Appearance screen.
///
/// One `CustomPainter` draws the whole stage. Selecting a mode changes only
/// the `morph` target:
///  - Light: radiant sun, rotating rays, alabaster mini cards.
///  - Dark: the sun's disc is eclipsed into a moon, a starfield fades in, and
///    the mini cards turn carbon-slate.
///  - System: a dual-core eclipse split down the middle (light world | dark
///    world); the half matching the device brightness stays lit.
///
/// Both worlds use fixed palette tokens, so the stage always shows the *mode*
/// being previewed regardless of the app theme currently applied.
class ThemePreviewStage extends StatefulWidget {
  const ThemePreviewStage({super.key, required this.mode});

  final ThemeMode mode;

  @override
  State<ThemePreviewStage> createState() => _ThemePreviewStageState();
}

class _ThemePreviewStageState extends State<ThemePreviewStage>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _morph;
  late final List<_Star> _stars;

  late double _darkFrom;
  late double _darkTo;
  late double _splitFrom;
  late double _splitTo;

  static double _darkFor(ThemeMode mode) => mode == ThemeMode.dark ? 1 : 0;
  static double _splitFor(ThemeMode mode) => mode == ThemeMode.system ? 1 : 0;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
      value: 1,
    );
    _darkFrom = _darkTo = _darkFor(widget.mode);
    _splitFrom = _splitTo = _splitFor(widget.mode);
    final random = math.Random(11);
    _stars = List<_Star>.generate(
      42,
      (_) => _Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 0.6 + random.nextDouble() * 1.3,
        phase: random.nextDouble(),
        frequency: 1 + random.nextInt(3),
      ),
      growable: false,
    );
  }

  @override
  void didUpdateWidget(ThemePreviewStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) return;
    // Morph from wherever the previous morph currently is, so rapid taps
    // never snap.
    final m = Curves.easeInOutCubic.transform(_morph.value);
    _darkFrom = ui.lerpDouble(_darkFrom, _darkTo, m)!;
    _splitFrom = ui.lerpDouble(_splitFrom, _splitTo, m)!;
    _darkTo = _darkFor(widget.mode);
    _splitTo = _splitFor(widget.mode);
    _morph.forward(from: 0);
  }

  @override
  void dispose() {
    _ambient.dispose();
    _morph.dispose();
    super.dispose();
  }

  String get _label => switch (widget.mode) {
        ThemeMode.light => 'Light  ·  Radiant',
        ThemeMode.dark => 'Dark  ·  Eclipse',
        ThemeMode.system => 'System  ·  Dual-core',
      };

  @override
  Widget build(BuildContext context) {
    final deviceDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isSystem = widget.mode == ThemeMode.system;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _StagePainter(
                  ambient: _ambient,
                  morph: _morph,
                  darkFrom: _darkFrom,
                  darkTo: _darkTo,
                  splitFrom: _splitFrom,
                  splitTo: _splitTo,
                  deviceDark: deviceDark,
                  stars: _stars,
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _StagePill(
                label: _label,
                trailing: isSystem
                    ? 'Device: ${deviceDark ? 'Dark' : 'Light'}'
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.fastOutSlowIn,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.glowEmerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: RyvoTypography.style(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: RyvoTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.frequency,
  });

  final double x;
  final double y;
  final double radius;
  final double phase;
  final int frequency;
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.ambient,
    required this.morph,
    required this.darkFrom,
    required this.darkTo,
    required this.splitFrom,
    required this.splitTo,
    required this.deviceDark,
    required this.stars,
  }) : super(repaint: Listenable.merge([ambient, morph]));

  final Animation<double> ambient;
  final Animation<double> morph;
  final double darkFrom;
  final double darkTo;
  final double splitFrom;
  final double splitTo;
  final bool deviceDark;
  final List<_Star> stars;

  static const double _tau = math.pi * 2;

  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final m = Curves.easeInOutCubic.transform(morph.value);
    final dark = ui.lerpDouble(darkFrom, darkTo, m)!;
    final split = ui.lerpDouble(splitFrom, splitTo, m)!;
    final t = ambient.value;

    if (split < 0.001) {
      _world(canvas, size, dark, t);
      return;
    }
    if (split > 0.999) {
      _splitWorld(canvas, size, t);
      return;
    }
    _world(canvas, size, dark, t);
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = AppColors.white.withValues(alpha: split),
    );
    _splitWorld(canvas, size, t);
    canvas.restore();
  }

  // ---------------------------------------------------------------- split

  void _splitWorld(Canvas canvas, Size size, double t) {
    final cx = size.width / 2;
    final rect = Offset.zero & size;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, cx, size.height));
    _world(canvas, size, 0, t);
    if (deviceDark) {
      _fill.color = AppColors.obsidian.withValues(alpha: 0.10);
      canvas.drawRect(rect, _fill);
    }
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(cx, 0, size.width, size.height));
    _world(canvas, size, 1, t);
    if (!deviceDark) {
      _fill.color = AppColors.backgroundDark.withValues(alpha: 0.38);
      canvas.drawRect(rect, _fill);
    }
    canvas.restore();

    // Seam: crisp lime core with an emerald bloom.
    _stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..strokeWidth = 5
      ..color = AppColors.glowEmerald.withValues(alpha: 0.5);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), _stroke);
    _stroke
      ..maskFilter = null
      ..strokeWidth = 1.5
      ..color = AppColors.lime.withValues(alpha: 0.9);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), _stroke);
  }

  // ---------------------------------------------------------------- world

  void _world(Canvas canvas, Size size, double dark, double t) {
    final rect = Offset.zero & size;
    final top =
        Color.lerp(AppColors.backgroundLight, AppColors.backgroundDark, dark)!;
    final bottom = Color.lerp(AppColors.headerMint, AppColors.modalDark, dark)!;
    _fill
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [top, bottom],
      )
      ..color = AppColors.white;
    canvas.drawRect(rect, _fill);
    _fill.shader = null;

    final horizon = size.height * 0.64;
    if (dark > 0.01) _starfield(canvas, size, dark, t, horizon);
    _grid(canvas, size, dark, t, horizon);
    _celestial(canvas, size, dark, t);
    _cards(canvas, size, dark, t);
  }

  void _starfield(
      Canvas canvas, Size size, double dark, double t, double horizon) {
    for (final star in stars) {
      final twinkle =
          0.55 + 0.45 * math.sin(_tau * (t * star.frequency + star.phase));
      _fill.color = AppColors.star.withValues(alpha: dark * twinkle * 0.9);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * horizon * 0.92),
        star.radius,
        _fill,
      );
    }
  }

  void _grid(Canvas canvas, Size size, double dark, double t, double horizon) {
    final base = Color.lerp(
      AppColors.dividerLight,
      AppColors.glowEmerald.withValues(alpha: 0.30),
      dark,
    )!;
    final cx = size.width / 2;
    _stroke
      ..maskFilter = null
      ..strokeWidth = 1
      ..color = base;
    final verticals = Path();
    for (var i = -9; i <= 9; i++) {
      verticals
        ..moveTo(cx + i * size.width * 0.018, horizon)
        ..lineTo(cx + i * size.width * 0.12, size.height);
    }
    canvas.drawPath(verticals, _stroke);

    final scroll = (t * 6) % 1;
    for (var k = 0; k < 8; k++) {
      final p = (k + scroll) / 8;
      final y = horizon + (size.height - horizon) * p * p;
      _stroke.color = base.withValues(alpha: base.a * p);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _stroke);
    }

    _stroke
      ..strokeWidth = 1
      ..color = AppColors.lime.withValues(alpha: 0.35 * dark);
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), _stroke);
  }

  void _celestial(Canvas canvas, Size size, double dark, double t) {
    final center = Offset(size.width / 2, size.height * 0.34);
    final radius = math.min(size.width, size.height) * 0.17;

    // Corona.
    final coronaColor =
        Color.lerp(AppColors.sunCore, AppColors.glowEmerald, dark)!;
    final coronaAlpha = ui.lerpDouble(0.40, 0.18, dark)!;
    _fill
      ..shader = ui.Gradient.radial(
        center,
        radius * 2.7,
        [
          coronaColor.withValues(alpha: coronaAlpha),
          coronaColor.withValues(alpha: 0)
        ],
      )
      ..color = AppColors.white;
    canvas.drawCircle(center, radius * 2.7, _fill);
    _fill.shader = null;

    // Rotating rays retract as the sun goes dark.
    final rayAmount = 1 - dark;
    if (rayAmount > 0.01) {
      final rotation = t * _tau * 2;
      final pulse = 1 + 0.07 * math.sin(t * _tau * 10);
      _stroke
        ..maskFilter = null
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 0.10
        ..color = AppColors.sunRay.withValues(alpha: rayAmount);
      for (var i = 0; i < 12; i++) {
        final angle = rotation + i * _tau / 12;
        final outer = radius * (i.isEven ? 1.82 : 1.60) * pulse;
        final inner = radius * 1.30;
        final len = ui.lerpDouble(inner, outer, rayAmount)!;
        final dir = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(center + dir * inner, center + dir * len, _stroke);
      }
      _stroke.strokeCap = StrokeCap.butt;
    }

    // Eclipsed shade of the moon behind the bright crescent.
    if (dark > 0.01) {
      _fill.color = AppColors.moonShade.withValues(alpha: 0.75 * dark);
      canvas.drawCircle(center, radius, _fill);
      _stroke
        ..strokeWidth = 1.5
        ..color = AppColors.glowEmerald.withValues(alpha: 0.55 * dark);
      canvas.drawCircle(center, radius * 1.05, _stroke);
    }

    // Body: the sun's disc, bitten into a crescent by a sliding occluder.
    final occluder = Offset.lerp(
      center + Offset(radius * 2.6, -radius * 0.5),
      center + Offset(radius * 0.46, -radius * 0.14),
      Curves.easeOutCubic.transform(dark),
    )!;
    final body = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Path()..addOval(Rect.fromCircle(center: occluder, radius: radius * 0.94)),
    );
    final bodyColor = Color.lerp(AppColors.sunCore, AppColors.moonLight, dark)!;
    _fill
      ..shader = ui.Gradient.radial(
        center + Offset(-radius * 0.35, -radius * 0.35),
        radius * 1.6,
        [Color.lerp(AppColors.white, bodyColor, 0.35)!, bodyColor],
      )
      ..color = AppColors.white;
    canvas.drawPath(body, _fill);
    _fill.shader = null;
  }

  void _cards(Canvas canvas, Size size, double dark, double t) {
    final bobA = math.sin(t * _tau * 3) * 3;
    final bobB = math.sin(t * _tau * 3 + 1.9) * 3;
    final w = size.width;
    final h = size.height;

    final fill = Color.lerp(AppColors.cardLight, AppColors.cardDark, dark)!;
    final border =
        Color.lerp(AppColors.dividerLight, AppColors.dividerDark, dark)!;
    final cta = Color.lerp(AppColors.obsidian, AppColors.white, dark)!;

    // Ride card.
    final a = Rect.fromLTWH(w * 0.07, h * 0.62 + bobA, w * 0.39, h * 0.27);
    _card(canvas, a, fill, border);
    final pad = a.height * 0.16;
    final avatar = a.height * 0.13;
    _fill.color = AppColors.primary;
    canvas.drawCircle(
      Offset(a.left + pad + avatar, a.top + pad + avatar),
      avatar,
      _fill,
    );
    _bar(
        canvas,
        Rect.fromLTWH(a.left + pad * 2 + avatar * 2, a.top + pad + avatar * 0.2,
            a.width * 0.34, avatar * 0.7),
        border);
    _bar(
        canvas,
        Rect.fromLTWH(a.left + pad * 2 + avatar * 2, a.top + pad + avatar * 1.2,
            a.width * 0.22, avatar * 0.55),
        border);
    _bar(
        canvas,
        Rect.fromLTWH(a.left + pad, a.bottom - pad - avatar * 0.8,
            a.width - pad * 2, avatar * 0.8),
        AppColors.primary.withValues(alpha: 0.22));

    // Fare card.
    final b = Rect.fromLTWH(w * 0.54, h * 0.67 + bobB, w * 0.39, h * 0.22);
    _card(canvas, b, fill, border);
    final padB = b.height * 0.18;
    _bar(
        canvas,
        Rect.fromLTWH(
            b.left + padB, b.top + padB, b.width * 0.30, b.height * 0.16),
        border);
    _bar(
        canvas,
        Rect.fromLTWH(b.left + padB, b.top + padB + b.height * 0.26,
            b.width * 0.46, b.height * 0.2),
        Color.lerp(AppColors.textPrimaryLight, AppColors.textPrimaryDark, dark)!
            .withValues(alpha: 0.85));
    _bar(
        canvas,
        Rect.fromLTWH(b.right - padB - b.width * 0.26,
            b.bottom - padB - b.height * 0.22, b.width * 0.26, b.height * 0.22),
        cta);
  }

  void _card(Canvas canvas, Rect rect, Color fill, Color border) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    _fill.color = fill;
    canvas.drawRRect(rrect, _fill);
    _stroke
      ..maskFilter = null
      ..strokeWidth = 1
      ..color = border;
    canvas.drawRRect(rrect, _stroke);
  }

  void _bar(Canvas canvas, Rect rect, Color color) {
    _fill.color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      _fill,
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) {
    return old.ambient != ambient ||
        old.morph != morph ||
        old.darkFrom != darkFrom ||
        old.darkTo != darkTo ||
        old.splitFrom != splitFrom ||
        old.splitTo != splitTo ||
        old.deviceDark != deviceDark ||
        old.stars != stars;
  }
}
