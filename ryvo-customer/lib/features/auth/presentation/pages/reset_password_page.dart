import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_scaffold.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  Country? _selectedCountry;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      showApiError(
          context, AppLocalizations.of(context).pleaseSelectYourCountry);
      return;
    }
    final phone = composeE164(
      _selectedCountry!.dialCode,
      _phoneController.text.trim(),
    );
    setState(() => _loading = true);
    try {
      ref.read(pendingPhoneProvider.notifier).state = phone;
      ref.read(otpPurposeProvider.notifier).state = 'reset_password';
      await ref.read(authRepositoryProvider).sendOtp(phone, 'reset_password');
      if (!mounted) return;
      context.push('/otp');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      onBack: () => context.pop(),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(l10n.resetPassword, style: authTitleStyle()),
              AppSpacing.h8,
              Text(
                l10n.enterYourPhoneNumberAndWeLlSendAVerificationCode,
                style: authBodyStyle(),
              ),
              AppSpacing.h32,
              PhoneCountryField(
                hint: '2345678900',
                controller: _phoneController,
                selectedCountry: _selectedCountry,
                onCountryChanged: (country) {
                  setState(() => _selectedCountry = country);
                },
                validator: (value) =>
                    (value?.isEmpty ?? true) ? l10n.enterYourPhoneNumber : null,
                textInputAction: TextInputAction.done,
              ),
              AppSpacing.h24,
              RyvoButton(
                label: l10n.sendResetCode,
                isLoading: _loading,
                onPressed: _sendCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
