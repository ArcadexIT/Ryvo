import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/app_config.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

/// Metrics for the floating pill so map sheets and tab lists clear it.
abstract final class RyvoFloatingNav {
  static const double height = 64;
  static const double horizontalMargin = 16;
  static const double bottomMargin = 12;

  /// Pill plus the gap above the system home indicator.
  static const double lift = kRyvoFloatingNavHeight;

  static double reservedHeight(BuildContext context) =>
      kRyvoBottomNavClearance(context);
}

class ShellPage extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  int _navIndexForBranch(int branchIndex, bool walletEnabled) {
    if (walletEnabled) return branchIndex;
    return branchIndex > 2 ? branchIndex - 1 : branchIndex;
  }

  int _branchIndexForNav(int navIndex, bool walletEnabled) {
    if (walletEnabled) return navIndex;
    return navIndex >= 2 ? navIndex + 1 : navIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config =
        ref.watch(appConfigProvider).valueOrNull ?? AppConfig.fallback;
    final walletEnabled = config.customerWalletEnabled;
    final currentNavIndex = _navIndexForBranch(
      navigationShell.currentIndex,
      walletEnabled,
    ).clamp(0, walletEnabled ? 3 : 2).toInt();

    final l10n = AppLocalizations.of(context);
    final items = <_ShellNavSpec>[
      _ShellNavSpec(icon: CupertinoIcons.house_alt, label: l10n.home),
      _ShellNavSpec(icon: CupertinoIcons.doc_text, label: l10n.bookings),
      if (walletEnabled)
        _ShellNavSpec(icon: CupertinoIcons.creditcard, label: l10n.wallet),
      _ShellNavSpec(icon: CupertinoIcons.person, label: l10n.profile),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RepaintBoundary(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: SafeArea(
                top: false,
                child: _FloatingPillBar(
                  items: items,
                  currentIndex: currentNavIndex,
                  onTap: (navIndex) {
                    HapticFeedback.selectionClick();
                    final branch = _branchIndexForNav(navIndex, walletEnabled);
                    navigationShell.goBranch(
                      branch,
                      initialLocation: branch == navigationShell.currentIndex,
                    );
                  },
                  onDragSelect: (navIndex) {
                    HapticFeedback.lightImpact();
                    navigationShell.goBranch(
                      _branchIndexForNav(navIndex, walletEnabled),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShellNavSpec {
  final IconData icon;
  final String label;

  const _ShellNavSpec({required this.icon, required this.label});
}

class _FloatingPillBar extends StatefulWidget {
  final List<_ShellNavSpec> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onDragSelect;

  const _FloatingPillBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onDragSelect,
  });

  @override
  State<_FloatingPillBar> createState() => _FloatingPillBarState();
}

class _FloatingPillBarState extends State<_FloatingPillBar> {
  static const Duration _snapDuration = Duration(milliseconds: 250);

  /// Thumb X (local to the pill's inner area) while dragging; null at rest.
  /// Updated per pointer event without `setState` so only the pill rebuilds.
  final ValueNotifier<double?> _dragXOffset = ValueNotifier<double?>(null);

  /// Tab currently under the thumb; drives icon/label highlight while dragging.
  final ValueNotifier<int?> _hoverIndex = ValueNotifier<int?>(null);

  /// Last tab index that fired a haptic tick during the active drag.
  int? _hapticIndex;

  @override
  void dispose() {
    _dragXOffset.dispose();
    _hoverIndex.dispose();
    super.dispose();
  }

  int _indexForX(double x, double slot, int count) {
    if (slot <= 0 || count == 0) return 0;
    return (x / slot).floor().clamp(0, count - 1).toInt();
  }

  void _onDragStart(
      DragStartDetails d, double maxWidth, double slot, int count) {
    _hapticIndex = widget.currentIndex;
    _onDragUpdateX(d.localPosition.dx, maxWidth, slot, count);
  }

  void _onDragUpdateX(double dx, double maxWidth, double slot, int count) {
    final x = dx.clamp(0.0, maxWidth).toDouble();
    _dragXOffset.value = x;
    final hovered = _indexForX(x, slot, count);
    if (hovered != _hapticIndex) {
      _hapticIndex = hovered;
      HapticFeedback.selectionClick();
    }
    if (_hoverIndex.value != hovered) _hoverIndex.value = hovered;
  }

  void _onDragEnd(double slot, int count) {
    final x = _dragXOffset.value;
    if (x == null) return;
    final finalIndex = _indexForX(x, slot, count);
    _hapticIndex = null;
    _dragXOffset.value = null;
    _hoverIndex.value = null;
    widget.onDragSelect(finalIndex);
  }

  void _onDragCancel() {
    _hapticIndex = null;
    _dragXOffset.value = null;
    _hoverIndex.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        height: RyvoFloatingNav.height,
        margin: const EdgeInsets.fromLTRB(
          RyvoFloatingNav.horizontalMargin,
          0,
          RyvoFloatingNav.horizontalMargin,
          RyvoFloatingNav.bottomMargin,
        ),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.modal,
          borderRadius: BorderRadius.circular(64),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = items.length;
            final slot = count == 0 ? 0.0 : constraints.maxWidth / count;
            final maxWidth = constraints.maxWidth;
            final index = widget.currentIndex
                .clamp(0, count == 0 ? 0 : count - 1)
                .toInt();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) =>
                  _onDragStart(d, maxWidth, slot, count),
              onHorizontalDragUpdate: (d) =>
                  _onDragUpdateX(d.localPosition.dx, maxWidth, slot, count),
              onHorizontalDragEnd: (_) => _onDragEnd(slot, count),
              onHorizontalDragCancel: _onDragCancel,
              child: Stack(
                children: [
                  if (count > 0)
                    ValueListenableBuilder<double?>(
                      valueListenable: _dragXOffset,
                      builder: (context, dragX, child) {
                        final dragging = dragX != null;
                        final left = dragging
                            ? (dragX - slot / 2)
                                .clamp(0.0, maxWidth - slot)
                                .toDouble()
                            : index * slot;
                        return AnimatedPositioned(
                          // Zero duration while dragging = pill tracks the
                          // thumb 1:1; on release it eases into the slot.
                          duration: dragging ? Duration.zero : _snapDuration,
                          curve: Curves.fastOutSlowIn,
                          left: left,
                          width: slot,
                          top: 0,
                          bottom: 0,
                          child: child!,
                        );
                      },
                      child: RepaintBoundary(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                      ),
                    ),
                  ValueListenableBuilder<int?>(
                    valueListenable: _hoverIndex,
                    builder: (context, hovered, _) {
                      final active = hovered ?? index;
                      return Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _ShellNavItem(
                                icon: items[i].icon,
                                label: items[i].label,
                                selected: i == active,
                                onTap: () => widget.onTap(i),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (AppColors.isDark ? AppColors.white : AppColors.obsidian)
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RyvoTypography.style(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
