import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

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

/// Anchored out-of-area sheet. Returns true when the customer asks to be notified.
Future<bool> showServiceUnavailableDialog(
  BuildContext context,
  WidgetRef ref, {
  required double lat,
  required double lng,
  required String addressLabel,
}) async {
  if (_dialogOpen || !context.mounted) return false;
  _dialogOpen = true;
  final notified = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.obsidian.withValues(alpha: 0.46),
    builder: (ctx) => const _ServiceUnavailableSheet(),
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
        SnackBar(
          content: Text(
            "We'll let you know when Ryvo opens nearby.",
            style: RyvoTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onCta,
            ),
          ),
          backgroundColor: AppColors.cta,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
        ),
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

class _ServiceUnavailableSheet extends StatelessWidget {
  const _ServiceUnavailableSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    return Material(
      color: AppColors.modal,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 24),
            const Center(child: _UnavailableMark()),
            const SizedBox(height: 16),
            Text(
              "Ryvo isn't available here",
              textAlign: TextAlign.center,
              style: RyvoTypography.heading(
                fontSize: 22,
                color: AppColors.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We don't serve this pickup yet. Choose a covered address, or get a note when rides open nearby.",
              textAlign: TextAlign.center,
              style: RyvoTypography.style(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _SheetAction(
              label: 'Notify me',
              background: AppColors.cta,
              foreground: AppColors.onCta,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 8),
            _SheetAction(
              label: 'Got it',
              background: AppColors.surface,
              foreground: AppColors.textPrimary,
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _UnavailableMark extends StatelessWidget {
  const _UnavailableMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.location_off_outlined,
        size: 28,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: RyvoTypography.style(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: foreground,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
