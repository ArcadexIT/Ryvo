import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_scaffold.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  Country? _selectedCountry;
  bool _loading = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      showApiError(
          context, AppLocalizations.of(context).pleaseSelectYourCountry);
      return;
    }
    if (!_acceptedTerms) {
      showApiError(context,
          AppLocalizations.of(context).pleaseAcceptTheTermsAndPrivacyPolicy);
      return;
    }
    final phone = composeE164(
      _selectedCountry!.dialCode,
      _phoneController.text.trim(),
    );
    final router = GoRouter.of(context);
    setState(() => _loading = true);
    await dismissKeyboard();
    if (!isContextActive(context)) return;
    try {
      final result = await ref.read(authRepositoryProvider).register(
            phone: phone,
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            acceptedTerms: true,
          );
      if (result.verificationRequired || result.tokens == null) {
        ref.read(pendingPhoneProvider.notifier).state = phone;
        ref.read(otpPurposeProvider.notifier).state = 'register';
        await ref.read(authRepositoryProvider).sendOtp(phone, 'register');
        if (!isContextActive(context)) return;
        context.push('/otp');
        return;
      }
      ref.read(needsPhoneVerificationProvider.notifier).state = false;
      ref.read(isAuthenticatedProvider.notifier).state = true;
      if (router.routerDelegate.currentConfiguration.uri.path != '/home') {
        router.go('/home');
      }
    } catch (e) {
      if (isContextActive(context)) showApiError(context, e);
    } finally {
      if (isContextActive(context)) setState(() => _loading = false);
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
              Text(l10n.createAccount, style: authTitleStyle()),
              AppSpacing.h8,
              Text(l10n.joinRyvoAndGetHelpInMinutes, style: authBodyStyle()),
              AppSpacing.h32,
              RyvoTextField(
                hint: l10n.johnDoe,
                label: l10n.fullName,
                controller: _nameController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? l10n.enterYourFullName
                    : null,
                textInputAction: TextInputAction.next,
              ),
              AppSpacing.h16,
              RyvoTextField(
                hint: 'you@email.com',
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return null;
                  if (!email.contains('@')) return 'Enter a valid email';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              AppSpacing.h16,
              PhoneCountryField(
                hint: '2345678900',
                controller: _phoneController,
                selectedCountry: _selectedCountry,
                onCountryChanged: (country) {
                  setState(() => _selectedCountry = country);
                },
                validator: (value) => (value?.length ?? 0) < 7
                    ? l10n.enterAValidPhoneNumber
                    : null,
                textInputAction: TextInputAction.next,
              ),
              AppSpacing.h16,
              RyvoTextField(
                hint: l10n.min8Characters,
                label: l10n.password,
                controller: _passwordController,
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => (value?.length ?? 0) < 8
                    ? l10n.passwordMustBeAtLeast8Characters
                    : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              AppSpacing.h20,
              _TermsAcceptance(
                accepted: _acceptedTerms,
                onChanged: (value) => setState(() => _acceptedTerms = value),
              ),
              AppSpacing.h24,
              RyvoButton(
                label: l10n.createAccount,
                isLoading: _loading,
                onPressed: _submit,
              ),
              AppSpacing.h24,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.alreadyHaveAnAccount,
                    style: RyvoTypography.style(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.signIn,
                      style: RyvoTypography.style(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
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
  }
}

class _TermsAcceptance extends StatelessWidget {
  const _TermsAcceptance({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = RyvoTypography.style(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppColors.textSecondary,
    );
    final link = RyvoTypography.style(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.45,
      color: AppColors.textPrimary,
      letterSpacing: -0.2,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            activeColor: AppColors.focusBorder,
            checkColor: AppColors.isDark ? AppColors.obsidian : AppColors.white,
            side: BorderSide(color: AppColors.textHint, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.iAgreeToThe, style: base),
                GestureDetector(
                  onTap: () => context.push('/legal/terms'),
                  child: Text(l10n.termsAndConditions, style: link),
                ),
                Text(' ${l10n.andWord} ', style: base),
                GestureDetector(
                  onTap: () => context.push('/legal/privacy'),
                  child: Text(l10n.privacyPolicy, style: link),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
