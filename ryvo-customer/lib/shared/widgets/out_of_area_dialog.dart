import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'ryvo_button.dart';

/// True when [lat]/[lng] is inside an active customer service zone from the
/// admin panel. Null when the check could not be completed.
Future<bool?> customerAreaCovered(WidgetRef ref, double lat, double lng) async {
  try {
    final data = await ref.read(apiClientProvider).post<dynamic>(
      '/customer/coverage/check',
      data: {'lat': lat, 'lng': lng},
    );
    if (data is Map && data['inside'] is bool) return data['inside'] as bool;
    return null;
  } catch (_) {
    return null;
  }
}

bool _dialogOpen = false;

/// Shows the same out-of-area dialog as the provider app.
/// Returns true when the customer asks to be notified.
Future<bool> showServiceUnavailableDialog(
  BuildContext context,
  WidgetRef ref, {
  required double lat,
  required double lng,
  required String addressLabel,
}) async {
  if (_dialogOpen || !context.mounted) return false;
  _dialogOpen = true;
  final notified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      elevation: 0,
      backgroundColor: AppColors.modal,
      surfaceTintColor: AppColors.modal,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24, AppSpacing.s24, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            AppSpacing.h16,
            Text(
              'Rides unavailable',
              style: RyvoTypography.heading(
                  fontSize: 18, color: AppColors.textPrimary),
            ),
            AppSpacing.h8,
            Text(
              'RYVO is unavailable in the current area',
              style: RyvoTypography.style(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.h8,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx, false);
                  },
                  child: Text(
                    'Close',
                    style: RyvoTypography.button(
                        fontSize: 15, color: AppColors.primary),
                  ),
                ),
                AppSpacing.w4,
                RyvoPressScale(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: AppColors.onCta,
                      minimumSize: const Size(64, 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx, true);
                    },
                    child: Text(
                      'Notify me',
                      style: RyvoTypography.button(
                          fontSize: 15, color: AppColors.onCta),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  _dialogOpen = false;
  if (notified != true || !context.mounted) return false;
  try {
    await ref.read(apiClientProvider).post<dynamic>(
      '/customer/coverage/notify',
      data: {'lat': lat, 'lng': lng, 'addressLabel': addressLabel},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We will notify you when RYVO is available here.')),
      );
    }
  } catch (_) {}
  return true;
}

/// False when the point is outside admin coverage and the dialog was shown.
/// True when the point is inside, or when the check could not be completed.
Future<bool> ensureCustomerCoverage(
  BuildContext context,
  WidgetRef ref, {
  required double lat,
  required double lng,
  required String addressLabel,
}) async {
  final inside = await customerAreaCovered(ref, lat, lng);
  if (inside != false) return true;
  if (!context.mounted) return false;
  await showServiceUnavailableDialog(
    context,
    ref,
    lat: lat,
    lng: lng,
    addressLabel: addressLabel,
  );
  return false;
}
