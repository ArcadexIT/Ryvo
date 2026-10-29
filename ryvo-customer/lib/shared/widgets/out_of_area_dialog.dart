import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
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
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Rides unavailable',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'RYVO is unavailable in the current area',
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.4,
                color: const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'Notify me',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15),
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
