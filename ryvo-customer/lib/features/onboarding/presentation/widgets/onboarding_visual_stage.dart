import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/currency.dart';

/// Top-stage illustrations for onboarding. Listens to [controller] and
/// crossfades scenes with a short parallax travel as the page changes.
class OnboardingVisualStage extends StatelessWidget {
  const OnboardingVisualStage({super.key, required this.controller});

  final PageController controller;

  double _page() {
    if (!controller.hasClients) return controller.initialPage.toDouble();
    return controller.page ?? controller.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRect(
        child: ColoredBox(
          color: AppColors.background,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final page = _page();
              final order = <int>[0, 1, 2]..sort(
                  (a, b) => (b - page).abs().compareTo((a - page).abs()),
                );
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final index in order)
                    _SceneLayer(
                      key: ValueKey<int>(index),
                      delta: index - page,
                      child: switch (index) {
                        0 => _MoveSmarterScene(parallax: index - page),
                        1 => _ModesScene(parallax: index - page),
                        _ => _TrackingScene(parallax: index - page),
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SceneLayer extends StatelessWidget {
  const _SceneLayer({
    super.key,
    required this.delta,
    required this.child,
  });

  final double delta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final distance = delta.abs();
    final shown = distance < 1;
    final fade = (1 - distance).clamp(0.0, 1.0);
    final width = MediaQuery.sizeOf(context).width;
    final travel = Transform.translate(
      offset: Offset(delta * width * 0.18, 0),
      child: Transform.scale(
        scale: 1 - distance.clamp(0.0, 1.0) * 0.04,
        child: child,
      ),
    );

    return Offstage(
      offstage: !shown,
      child: TickerMode(
        enabled: distance < 0.98,
        child: fade > 0.999
            ? travel
            : FadeTransition(
                opacity: AlwaysStoppedAnimation<double>(fade),
                child: travel,
              ),
      ),
    );
  }
}

void _play(
  BuildContext context,
  AnimationController controller, {
  bool reverse = false,
  double resting = 1,
}) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  if (reduce) {
    if (controller.isAnimating) controller.stop();
    controller.value = resting;
    return;
  }
  if (!controller.isAnimating) {
    controller.repeat(reverse: reverse);
  }
}

class _MoveSmarterScene extends StatefulWidget {
  const _MoveSmarterScene({required this.parallax});

  final double parallax;

  @override
  State<_MoveSmarterScene> createState() => _MoveSmarterSceneState();
}

class _MoveSmarterSceneState extends State<_MoveSmarterScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play(context, _clock, resting: 0.7);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final grid = AppColors.divider;
    final block = AppColors.surface;
    const route = AppColors.primary;
    final ink = AppColors.textPrimary;
    final sheet = AppColors.modal;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MapGridPainter(
                parallax: widget.parallax,
                grid: grid,
                block: block,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RoutePainter(
                clock: _clock,
                parallax: widget.parallax,
                route: route,
                ink: ink,
                sheet: sheet,
                topInset: topInset,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: topInset + 12,
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, child) {
              final bob = math.sin(_clock.value * math.pi * 2) * 4;
              return Transform.translate(
                offset: Offset(widget.parallax * 18, bob),
                child: child,
              );
            },
            child: const _EtaPill(),
          ),
        ),
      ],
    );
  }
}

class _EtaPill extends StatelessWidget {
  const _EtaPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 8, height: 8),
            ),
            const SizedBox(width: 8),
            Text(
              '3 min away',
              style: RyvoTypography.eta(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// City blocks as fractions of the canvas: x, y, w, h.
const List<(double, double, double, double)> _cityBlocks =
    <(double, double, double, double)>[
  (0.05, 0.06, 0.18, 0.11),
  (0.28, 0.05, 0.22, 0.13),
  (0.56, 0.08, 0.16, 0.10),
  (0.78, 0.04, 0.16, 0.14),
  (0.06, 0.28, 0.16, 0.12),
  (0.32, 0.30, 0.20, 0.10),
  (0.62, 0.32, 0.14, 0.12),
  (0.80, 0.28, 0.14, 0.11),
  (0.08, 0.55, 0.20, 0.12),
  (0.40, 0.58, 0.18, 0.11),
  (0.68, 0.54, 0.22, 0.13),
  (0.10, 0.78, 0.24, 0.12),
  (0.46, 0.80, 0.18, 0.10),
  (0.72, 0.76, 0.18, 0.13),
];

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({
    required this.parallax,
    required this.grid,
    required this.block,
  });

  final double parallax;
  final Color grid;
  final Color block;

  @override
  void paint(Canvas canvas, Size size) {
    final shift = parallax * size.width * -0.045;
    final blockPaint = Paint()..color = block;
    for (final cell in _cityBlocks) {
      final rect = Rect.fromLTWH(
        cell.$1 * size.width + shift,
        cell.$2 * size.height,
        cell.$3 * size.width,
        cell.$4 * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        blockPaint,
      );
    }

    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = -step; x <= size.width + step; x += step) {
      canvas.drawLine(
        Offset(x + shift, 0),
        Offset(x + shift, size.height),
        line,
      );
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.parallax != parallax ||
        oldDelegate.grid != grid ||
        oldDelegate.block != block;
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.clock,
    required this.parallax,
    required this.route,
    required this.ink,
    required this.sheet,
    required this.topInset,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final double parallax;
  final Color route;
  final Color ink;
  final Color sheet;
  final double topInset;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final reveal = t < 0.58 ? Curves.easeInOutCubic.transform(t / 0.58) : 1.0;
    final fade = t < 0.78 ? 1.0 : ((1 - t) / 0.22).clamp(0.0, 1.0);
    final shift = parallax * size.width * 0.03;
    final top = topInset + 20;
    final bottom = size.height - 72;
    final span = math.max(80.0, bottom - top);
    final start = Offset(size.width * 0.22 + shift, top + span * 0.74);
    final end = Offset(size.width * 0.72 + shift * 1.35, top + span * 0.30);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + size.width * 0.10,
        start.dy - span * 0.42,
        end.dx - size.width * 0.20,
        end.dy + span * 0.38,
        end.dx,
        end.dy,
      );

    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * reveal);

    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = sheet.withValues(alpha: fade),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = route.withValues(alpha: 0.22 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = route.withValues(alpha: fade),
    );

    if (reveal > 0.02 && reveal < 0.995 && fade > 0.9) {
      final tip = metric.getTangentForOffset(metric.length * reveal);
      if (tip != null) {
        canvas.drawCircle(tip.position, 4, Paint()..color = route);
      }
    }

    _pickup(canvas, start, t);
    _dropoff(canvas, end);
  }

  void _pickup(Canvas canvas, Offset at, double t) {
    final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
    final second = (pulse + 0.45) % 1;
    canvas.drawCircle(
      at,
      9 + pulse * 18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = route.withValues(alpha: 0.34 * (1 - pulse)),
    );
    canvas.drawCircle(
      at,
      9 + second * 14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = route.withValues(alpha: 0.22 * (1 - second)),
    );
    canvas.drawCircle(at, 6.5, Paint()..color = route);
    canvas.drawCircle(at, 2.4, Paint()..color = sheet);
  }

  void _dropoff(Canvas canvas, Offset at) {
    final rect = Rect.fromCenter(center: at, width: 13, height: 13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.parallax != parallax ||
        oldDelegate.route != route ||
        oldDelegate.ink != ink ||
        oldDelegate.sheet != sheet ||
        oldDelegate.topInset != topInset ||
        oldDelegate.clock != clock;
  }
}

class _ModesScene extends StatefulWidget {
  const _ModesScene({required this.parallax});

  final double parallax;

  @override
  State<_ModesScene> createState() => _ModesSceneState();
}

class _ModesSceneState extends State<_ModesScene>
    with TickerProviderStateMixin {
  late final AnimationController _float;
  late final AnimationController _fare;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _fare = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play(context, _float, resting: 0);
    _play(context, _fare, reverse: true, resting: 0.35);
  }

  @override
  void dispose() {
    _float.dispose();
    _fare.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FareTracePainter(
                clock: _fare,
                color: AppColors.primary,
                parallax: widget.parallax,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, topInset + 64, 24, 36),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StaggeredCard(
                        index: 0,
                        parallax: widget.parallax,
                        clock: _float,
                        child: _ModeCard(
                          icon: Icons.near_me_rounded,
                          label: 'Ride',
                          detail: '12 min',
                          selected: true,
                          trailing: _LiveFare(clock: _fare),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StaggeredCard(
                        index: 1,
                        parallax: widget.parallax,
                        clock: _float,
                        child: const _ModeCard(
                          icon: Icons.local_offer_outlined,
                          label: 'Bid',
                          detail: 'You set the fare',
                          selected: false,
                          trailing: _StaticFare(label: 'Offer'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StaggeredCard(
                        index: 2,
                        parallax: widget.parallax,
                        clock: _float,
                        child: const _ModeCard(
                          icon: Icons.inventory_2_outlined,
                          label: 'Parcel',
                          detail: 'Door to door',
                          selected: false,
                          trailing: _StaticFare(label: 'Send'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StaggeredCard extends StatelessWidget {
  const _StaggeredCard({
    required this.index,
    required this.parallax,
    required this.clock,
    required this.child,
  });

  final int index;
  final double parallax;
  final Animation<double> clock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, child) {
          final wave = math.sin((clock.value + index * 0.33) * math.pi * 2) * 5;
          final distance = parallax.abs().clamp(0.0, 1.0);
          final raw = ((1 - distance) - index * 0.1) / 0.7;
          final enter = Curves.fastOutSlowIn.transform(raw.clamp(0.0, 1.0));
          final moved = Transform.translate(
            offset: Offset(
              parallax * (12 + index * 10),
              wave + (1 - enter) * 18,
            ),
            child: child,
          );
          if (enter >= 0.98) return moved;
          return FadeTransition(
            opacity: AlwaysStoppedAnimation<double>(enter),
            child: moved,
          );
        },
        child: child,
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final fill = selected
        ? (dark ? AppColors.card : AppColors.surface)
        : (dark ? AppColors.modal : AppColors.card);
    final borderColor = selected
        ? (dark ? AppColors.white : AppColors.obsidian)
        : AppColors.divider;
    final indent = selected ? 0.0 : 18.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, right: selected ? 12 : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? (dark
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : AppColors.primaryLight)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? (dark ? AppColors.primary : AppColors.primaryDark)
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.2,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveFare extends StatelessWidget {
  const _LiveFare({required this.clock});

  final Animation<double> clock;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) {
        final eased = Curves.easeInOut.transform(clock.value);
        final cents = (1840 + eased * 420).round();
        return Text(
          _formatFare(cents),
          maxLines: 1,
          style: RyvoTypography.price(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        );
      },
    );
  }
}

class _StaticFare extends StatelessWidget {
  const _StaticFare({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      style: RyvoTypography.style(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
      ),
    );
  }
}

String _formatFare(int cents) {
  final symbol = ActiveCurrency.current.symbol;
  final whole = cents ~/ 100;
  final frac = (cents % 100).toString().padLeft(2, '0');
  return '$symbol$whole.$frac';
}

class _FareTracePainter extends CustomPainter {
  _FareTracePainter({
    required this.clock,
    required this.color,
    required this.parallax,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final Color color;
  final double parallax;

  static const List<double> _steps = <double>[
    0.32,
    0.32,
    0.50,
    0.44,
    0.68,
    0.60,
    0.84,
    0.74,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeInOut.transform(clock.value);
    final left = 28.0 + parallax * 16;
    final right = size.width - 28;
    final base = size.height - 52;
    final span = math.max(1.0, right - left);
    double yAt(int index) => base - _steps[index] * 46 - t * 10;
    final path = Path()..moveTo(left, yAt(0));
    for (var i = 1; i < _steps.length; i++) {
      final x = left + span * (i / (_steps.length - 1));
      path
        ..lineTo(x, yAt(i - 1))
        ..lineTo(x, yAt(i));
    }

    final progress = 0.35 + t * 0.65;
    final metric = path.computeMetrics().first;
    final visible = metric.extractPath(0, metric.length * progress);
    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.8);
    canvas.drawPath(visible, trace);
    final tip = metric.getTangentForOffset(metric.length * progress);
    if (tip != null) {
      canvas.drawCircle(tip.position, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _FareTracePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.parallax != parallax ||
        oldDelegate.clock != clock;
  }
}

class _TrackingScene extends StatefulWidget {
  const _TrackingScene({required this.parallax});

  final double parallax;

  @override
  State<_TrackingScene> createState() => _TrackingSceneState();
}

class _TrackingSceneState extends State<_TrackingScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play(context, _clock, resting: 0.2);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _RadarPainter(
                clock: _clock,
                parallax: widget.parallax,
                route: AppColors.primary,
                ink: AppColors.textPrimary,
                ring: AppColors.divider,
                sheet: AppColors.modal,
                topInset: topInset,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 32,
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, child) {
              final bob = math.sin(_clock.value * math.pi * 2) * 4;
              return Transform.translate(
                offset: Offset(widget.parallax * 14, bob),
                child: child,
              );
            },
            child: const _TrustBadge(),
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Verified driver',
              style: RyvoTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            ColoredBox(
              color: AppColors.divider,
              child: const SizedBox(width: 1, height: 12),
            ),
            const SizedBox(width: 8),
            Text(
              '4.98',
              style: RyvoTypography.eta(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.clock,
    required this.parallax,
    required this.route,
    required this.ink,
    required this.ring,
    required this.sheet,
    required this.topInset,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final double parallax;
  final Color route;
  final Color ink;
  final Color ring;
  final Color sheet;
  final double topInset;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final regionTop = topInset + 8;
    final regionBottom = size.height - 96;
    final regionHeight = math.max(140.0, regionBottom - regionTop);
    final center = Offset(
      size.width * 0.56 + parallax * size.width * 0.04,
      regionTop + regionHeight * 0.46,
    );
    final maxR = math.min(size.width * 0.30, regionHeight * 0.42);
    final radii = <double>[maxR * 0.28, maxR * 0.52, maxR * 0.76, maxR];

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring;
    for (final radius in radii) {
      canvas.drawCircle(center, radius, ringPaint);
    }

    final pulse = 12 + t * (maxR + 8);
    canvas.drawCircle(
      center,
      pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = route.withValues(alpha: (1 - t) * 0.45),
    );

    final orbit = radii[1];
    final angle = t * math.pi * 2;
    final vehicle =
        center + Offset(math.cos(angle) * orbit, math.sin(angle) * orbit);

    canvas.drawLine(
      center,
      vehicle,
      Paint()
        ..color = route.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: orbit),
      angle - 0.5,
      1.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = route,
    );
    canvas.drawCircle(center, 4, Paint()..color = route);
    canvas.drawCircle(center, 1.8, Paint()..color = sheet);

    _reticle(canvas, vehicle, t);
    _vehicle(canvas, vehicle, angle);
  }

  void _reticle(Canvas canvas, Offset at, double t) {
    final arm = 8 + math.sin(t * math.pi * 2) * 1.5;
    final paint = Paint()
      ..color = route
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at + Offset(-arm - 4, 0), at + const Offset(-4, 0), paint);
    canvas.drawLine(at + const Offset(4, 0), at + Offset(arm + 4, 0), paint);
    canvas.drawLine(at + Offset(0, -arm - 4), at + const Offset(0, -4), paint);
    canvas.drawLine(at + const Offset(0, 4), at + Offset(0, arm + 4), paint);
  }

  void _vehicle(Canvas canvas, Offset at, double angle) {
    final heading = math.atan2(math.cos(angle), -math.sin(angle)) + math.pi / 2;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(heading);
    final body = Path()
      ..moveTo(0, -11)
      ..lineTo(7, 9)
      ..lineTo(0, 5)
      ..lineTo(-7, 9)
      ..close();
    canvas.drawPath(body, Paint()..color = ink);
    canvas.drawCircle(
      const Offset(0, -4),
      2.2,
      Paint()..color = route,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.parallax != parallax ||
        oldDelegate.route != route ||
        oldDelegate.ink != ink ||
        oldDelegate.ring != ring ||
        oldDelegate.sheet != sheet ||
        oldDelegate.topInset != topInset ||
        oldDelegate.clock != clock;
  }
}
