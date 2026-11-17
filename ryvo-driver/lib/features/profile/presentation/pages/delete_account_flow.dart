import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';

/// Profile → Delete account. Tries a server delete, then a support request
/// so the driver can start deletion from inside the app.
Future<void> confirmDeleteDriverAccount(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(providerProfileProvider).asData?.value;
  final name = profile?.name ?? '';
  final phone = profile?.phone ?? '';
  final email = profile?.email ?? '';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DeleteAccountDialog(name: name),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final dio = ref.read(dioClientProvider).dio;
  var removedOnServer = false;
  var needsTicket = false;

  try {
    final res = await dio.delete('/provider/account');
    final code = res.statusCode ?? 0;
    removedOnServer = code >= 200 && code < 300;
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    if (code == 404 || code == 405 || code == 501) {
      needsTicket = true;
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_dioMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
  }

  if (!removedOnServer) needsTicket = true;

  if (needsTicket) {
    try {
      await ref.read(supportRepositoryProvider).createTicket(
            category: 'account',
            subject: 'Delete my Ryvo Driver account',
            message: 'I request deletion of my Ryvo Driver account and the personal data attached to it.\n'
                'Name: $name\n'
                'Phone: $phone\n'
                'Email: $email\n'
                'Please close the account. Trip and payout records may be kept only where tax, safety, or fraud law requires it.',
          );
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not send the deletion request. $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      title: Text(
        removedOnServer ? 'Account deleted' : 'Deletion requested',
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: Text(
        removedOnServer
            ? 'Your Ryvo Driver account has been deleted. Trip and payout records may be kept only where the law requires it.'
            : 'Your deletion request was sent. Ryvo will close this account and delete your personal data, usually within 30 days. Trip and payout records may be kept where UK tax, safety, or fraud law requires it. You can also email enquiries@ryvo.arcadexit.com.',
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  if (!context.mounted) return;
  await providerSignOut(ref);
  if (context.mounted) context.go('/login');
}

String _dioMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) return data['message'].toString();
  return 'Could not delete the account. Try again, or email enquiries@ryvo.arcadexit.com.';
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.name});

  final String name;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _confirm.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      title: const Text(
        'Delete account',
        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.name.isEmpty
                  ? 'This closes your Ryvo Driver account.'
                  : 'This closes the Ryvo Driver account for ${widget.name}.',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'We delete your profile, login, licence and vehicle documents, and trip chat. Trip and payout records may be kept where tax, safety, or fraud law requires it. This is not the same as logging out.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type DELETE to confirm',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: Text('Delete account', style: TextStyle(color: ready ? AppColors.error : AppColors.textHint, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
