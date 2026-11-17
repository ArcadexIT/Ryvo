import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../widgets/ryvo_modal_scaffold.dart';

/// In-app account deletion request. Play requires this on Profile.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  bool _submitting = false;
  bool _sent = false;

  Future<void> _confirm() async {
    if (_submitting || _sent) return;
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.modal,
          title: Text(
            'Delete your Ryvo account?',
            style: RyvoTypography.style(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          content: Text(
            'This sends a deletion request for the account you are signed in with. You will be signed out.',
            style: RyvoTypography.style(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: RyvoTypography.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete account',
                style: RyvoTypography.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref.read(supportRepositoryProvider).requestAccountDeletion();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _sent = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        showApiError(context, error);
      }
    }
  }

  Future<void> _finish() async {
    await signOut(ref);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return RyvoModalScaffold(
      title: 'Delete account',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            _sent
                ? 'Your deletion request is in. Ryvo will delete this account and the personal data tied to it. Trip and payment records may stay on file where the law requires them.'
                : 'Deleting your account removes your profile, saved places, vehicles, messages, and notification token. Trip and payment records may be kept where the law requires them.',
            style: RyvoTypography.style(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Spend any wallet balance before you continue. A balance left on the account is closed with it. You can also email enquiries@ryvo.arcadexit.com from the address on this account if you no longer have the app.',
            style: RyvoTypography.style(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          if (_sent)
            RyvoButton(label: 'Sign out', onPressed: _finish)
          else
            RyvoButton(
              label: _submitting ? 'Sending request' : 'Delete account',
              isLoading: _submitting,
              onPressed: _submitting ? null : _confirm,
            ),
        ],
      ),
    );
  }
}
