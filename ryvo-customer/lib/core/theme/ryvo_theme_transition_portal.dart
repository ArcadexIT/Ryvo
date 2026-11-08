import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/app_providers.dart';
import 'app_colors.dart';
import 'theme_sync.dart';

/// Radial "shockwave portal" theme transition.
///
/// Mounted once at the root (`MaterialApp.builder`). [trigger] does:
///  1. Rasterises the live app into a GPU `ui.Image` through a
///     `RepaintBoundary`.
///  2. Switches `themeModeProvider`, so the real tree underneath renders the
///     new theme on the very next frame.
///  3. Lays the old frame on top and punches an expanding circular hole in it
///     (550ms, `easeInOutCubic`) from the tap point to the farthest corner.
///  4. Draws a glowing shockwave ring on the hole's edge that fades out, then
///     disposes the image.
///
/// The animation is driven entirely by one `AnimationController` feeding a
/// clipper and a painter via `reclip` / `repaint`; no widget rebuilds per frame.
class RyvoThemeTransitionPortal extends ConsumerStatefulWidget {
  const RyvoThemeTransitionPortal({super.key, required this.child});

  final Widget child;

  static _RyvoThemeTransitionPortalState? _active;

  /// Switches the app to [mode] with a shockwave expanding from [origin]
  /// (global coordinates, e.g. `TapDownDetails.globalPosition`).
  static Future<void> trigger(Offset origin, ThemeMode mode) async {
    final portal = _active;
    if (portal == null) return;
    await portal._run(origin, mode);
  }

  @override
  ConsumerState<RyvoThemeTransitionPortal> createState() =>
      _RyvoThemeTransitionPortalState();
}

class _RyvoThemeTransitionPortalState
    extends ConsumerState<RyvoThemeTransitionPortal>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 550);

  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  late final CurvedAnimation _progress;

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  double _maxRadius = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    RyvoThemeTransitionPortal._active = this;
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener(_onStatus);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    if (identical(RyvoThemeTransitionPortal._active, this)) {
      RyvoThemeTransitionPortal._active = null;
    }
    _progress.dispose();
    _controller.dispose();
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  Future<void> _run(Offset origin, ThemeMode mode) async {
    final notifier = ref.read(themeModeProvider.notifier);
    final current = ref.read(themeModeProvider);
    if (current == mode) return;

    final flips = ThemeSync.effectiveBrightness(mode) !=
        ThemeSync.effectiveBrightness(current);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!flips || _busy || reduceMotion) {
      // Palette is unchanged (or a transition is already running): no portal.
      notifier.state = mode;
      return;
    }

    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) {
      notifier.state = mode;
      return;
    }

    _busy = true;
    final pixelRatio = View.of(context).devicePixelRatio;
    final ui.Image image;
    try {
      image = await boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      _busy = false;
      if (mounted) notifier.state = mode;
      return;
    }
    if (!mounted) {
      image.dispose();
      return;
    }

    final size = boundary.size;
    final local = boundary.globalToLocal(origin);
    final corners = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var farthest = 0.0;
    for (final corner in corners) {
      farthest = math.max(farthest, (corner - local).distance);
    }

    setState(() {
      _snapshot = image;
      _origin = local;
      _maxRadius = farthest;
    });
    // Same event, same frame: the tree underneath renders the new theme while
    // the overlay still shows the old one.
    notifier.state = mode;
    _controller.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final image = _snapshot;
    if (mounted) setState(() => _snapshot = null);
    _controller.value = 0;
    _busy = false;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (snapshot != null)
          _PortalOverlay(
            image: snapshot,
            origin: _origin,
            maxRadius: _maxRadius,
            progress: _progress,
          ),
      ],
    );
  }
}

class _PortalOverlay extends StatelessWidget {
  const _PortalOverlay({
    required this.image,
    required this.origin,
    required this.maxRadius,
    required this.progress,
  });

  final ui.Image image;
  final Offset origin;
  final double maxRadius;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: _PortalHoleClipper(
                origin: origin,
                maxRadius: maxRadius,
                progress: progress,
              ),
              child: RawImage(
                image: image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            CustomPaint(
              painter: _ShockwavePainter(
                origin: origin,
                maxRadius: maxRadius,
                progress: progress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen rect minus a growing circle (even-odd fill).
class _PortalHoleClipper extends CustomClipper<Path> {
  _PortalHoleClipper({
    required this.origin,
    required this.maxRadius,
    required this.progress,
  }) : super(reclip: progress);

  final Offset origin;
  final double maxRadius;
  final Animation<double> progress;

  @override
  Path getClip(Size size) {
    final radius = maxRadius * progress.value;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: origin, radius: radius));
  }

  @override
  bool shouldReclip(_PortalHoleClipper oldClipper) {
    return oldClipper.origin != origin ||
        oldClipper.maxRadius != maxRadius ||
        oldClipper.progress != progress;
  }
}

/// Glowing ring riding the portal edge. Emerald bloom, lime core, thin white
/// highlight, plus a faint trailing echo. Everything fades as the portal ends.
class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter({
    required this.origin,
    required this.maxRadius,
    required this.progress,
  }) : super(repaint: progress);

  final Offset origin;
  final double maxRadius;
  final Animation<double> progress;

  final Paint _bloom = Paint()
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
  final Paint _echo = Paint()..style = PaintingStyle.stroke;
  final Paint _core = Paint()..style = PaintingStyle.stroke;
  final Paint _highlight = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final fade = 1 - Curves.easeIn.transform(t);
    final radius = maxRadius * t;
    if (fade <= 0.01 || radius < 1) return;

    _bloom
      ..color = AppColors.glowEmerald.withValues(alpha: 0.6 * fade)
      ..strokeWidth = ui.lerpDouble(30, 10, t)!;
    canvas.drawCircle(origin, radius, _bloom);

    _echo
      ..color = AppColors.glowEmerald.withValues(alpha: 0.28 * fade)
      ..strokeWidth = ui.lerpDouble(10, 3, t)!;
    canvas.drawCircle(origin, radius * 0.94, _echo);

    _core
      ..color = AppColors.lime.withValues(alpha: 0.95 * fade)
      ..strokeWidth = ui.lerpDouble(5, 1.5, t)!;
    canvas.drawCircle(origin, radius, _core);

    _highlight
      ..color = AppColors.white.withValues(alpha: 0.7 * fade)
      ..strokeWidth = 1;
    canvas.drawCircle(origin, radius, _highlight);
  }

  @override
  bool shouldRepaint(_ShockwavePainter oldDelegate) {
    return oldDelegate.origin != origin ||
        oldDelegate.maxRadius != maxRadius ||
        oldDelegate.progress != progress;
  }
}
