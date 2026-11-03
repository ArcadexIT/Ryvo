import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/ryvo_theme_transition_portal.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_close_button.dart';
import '../widgets/theme_mode_card.dart';
import '../widgets/theme_preview_stage.dart';

/// Appearance HUD: live morphing preview stage on top (45%), three tactile
/// mode cards below (55%). Picking a card fires the radial shockwave portal
/// from the exact touch point.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(themeModeProvider);
    final deviceDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RyvoCloseButton(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'App theme',
                style: RyvoTypography.style(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ),
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ThemePreviewStage(mode: current),
              ),
            ),
            Expanded(
              flex: 55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'DISPLAY MODE',
                        style: RyvoTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 228),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final spec in _specs(l10n)) ...[
                                if (spec.mode != ThemeMode.light)
                                  const SizedBox(width: 12),
                                Expanded(
                                  child: ThemeModeCard(
                                    mode: spec.mode,
                                    label: spec.label,
                                    caption: spec.caption,
                                    selected: current == spec.mode,
                                    onSelected: (origin) =>
                                        _select(origin, spec.mode),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                      child: Text(
                        current == ThemeMode.system
                            ? 'Following your device. It is currently '
                                '${deviceDark ? 'dark' : 'light'}.'
                            : 'Applies instantly across the whole app.',
                        style: RyvoTypography.style(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ModeSpec> _specs(AppLocalizations l10n) => [
        _ModeSpec(ThemeMode.light, l10n.light, 'Radiant'),
        _ModeSpec(ThemeMode.dark, l10n.dark, 'Eclipse'),
        _ModeSpec(ThemeMode.system, l10n.system, 'Auto'),
      ];

  void _select(Offset origin, ThemeMode mode) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    RyvoThemeTransitionPortal.trigger(origin, mode);
  }
}

class _ModeSpec {
  const _ModeSpec(this.mode, this.label, this.caption);

  final ThemeMode mode;
  final String label;
  final String caption;
}
