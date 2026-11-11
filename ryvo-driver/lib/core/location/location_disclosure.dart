import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

const kLocationDisclosurePrefKey = 'ryvo_driver_location_disclosure_v1';

/// Set from [main] before [runApp] so the first frame does not request GPS
/// before the driver has seen the disclosure.
bool locationDisclosureAcceptedAtLaunch = false;

final locationUpdatesEnabledProvider = StateProvider<bool>(
  (ref) => locationDisclosureAcceptedAtLaunch,
);

bool _promptOpen = false;

/// Shows Play's prominent location disclosure, then lets the caller start GPS.
/// Returns true only after the driver agrees.
Future<bool> promptDriverLocationDisclosure(BuildContext context, WidgetRef ref) async {
  if (ref.read(locationUpdatesEnabledProvider)) return true;
  if (_promptOpen) return ref.read(locationUpdatesEnabledProvider);
  _promptOpen = true;
  try {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        title: const Text(
          'Location while you are online',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Ryvo Driver uses your precise location while you are online so nearby riders can be matched to you and can see your arrival. A notification stays on screen the whole time location is shared, including if you switch to maps. Location is used for trips, not for advertising. Go offline any time to stop sharing.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLocationDisclosurePrefKey, true);
    ref.read(locationUpdatesEnabledProvider.notifier).state = true;
    return true;
  } finally {
    _promptOpen = false;
  }
}
