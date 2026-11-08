import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/widgets.dart';

class NoProvidersPage extends StatelessWidget {
  const NoProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Spacer(),
          Material(
            color: AppColors.modal,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _SheetHandle()),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        size: 28,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noProvidersAvailable,
                    textAlign: TextAlign.center,
                    style: RyvoTypography.heading(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.thereAreNoProvidersAvailableNearbyRightNowPlease,
                    textAlign: TextAlign.center,
                    style: RyvoTypography.style(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  RyvoButton(
                    label: 'Try Again',
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(height: 8),
                  RyvoButton(
                    label: 'Increase Bid',
                    variant: RyvoButtonVariant.outline,
                    onPressed: () => context.push('/service-request'),
                  ),
                  const SizedBox(height: 8),
                  RyvoButton(
                    label: 'Back',
                    variant: RyvoButtonVariant.ghost,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
