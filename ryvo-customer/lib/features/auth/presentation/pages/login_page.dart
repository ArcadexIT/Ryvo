import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/job/active_job_session.dart';
import '../../../../core/job/resume_customer_job.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  Country? _selectedCountry;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
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
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    setState(() => _loading = true);
    // Auth flips inside signIn and the router replaces this page immediately.
    // The keyboard has to be gone first, or the dying login route looks up
    // MediaQuery while it is already deactivated.
    await dismissKeyboard();
    if (!isContextActive(context)) return;
    try {
      await signIn(
        ref,
        phone,
        _passwordController.text,
      );
      final resumeRoute = await restoreActiveJobSession(container);
      final job = container.read(jobDraftProvider).activeJob;
      if (job != null && effectiveCustomerJobStatus(job) == 'payment_pending') {
        final nav = activeRootContext();
        if (nav != null) await resumeCustomerJob(nav, job, replace: true);
        return;
      }
      final target = resumeRoute ?? '/home';
      final current = router.routerDelegate.currentConfiguration.uri.path;
      if (current != target) router.go(target);
    } catch (e) {
      if (!isContextActive(context)) return;
      if (e.toString().contains('finish registration')) {
        ref.read(pendingPhoneProvider.notifier).state = phone;
        ref.read(otpPurposeProvider.notifier).state = 'register';
        try {
          await ref.read(authRepositoryProvider).sendOtp(phone, 'register');
        } catch (sendError) {
          if (isContextActive(context)) showApiError(context, sendError);
          return;
        }
        if (!isContextActive(context)) return;
        context.push('/otp');
        return;
      }
      showApiError(context, e);
    } finally {
      if (isContextActive(context)) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              const AppLogo(size: 28, variant: AppLogoVariant.wordmark),
              AppSpacing.h32,
              Text(l10n.welcomeBack, style: authTitleStyle()),
              AppSpacing.h8,
              Text(l10n.signInToContinue, style: authBodyStyle()),
              AppSpacing.h32,
              PhoneCountryField(
                hint: '234 567 8900',
                controller: _phoneController,
                selectedCountry: _selectedCountry,
                onCountryChanged: (country) {
                  setState(() => _selectedCountry = country);
                },
                validator: (value) =>
                    (value?.isEmpty ?? true) ? l10n.enterYourPhoneNumber : null,
                textInputAction: TextInputAction.next,
              ),
              AppSpacing.h16,
              RyvoTextField(
                hint: l10n.enterPassword,
                label: l10n.password,
                controller: _passwordController,
                isPassword: true,
                autofillHints: const [AutofillHints.password],
                validator: (value) =>
                    (value?.isEmpty ?? true) ? l10n.enterYourPassword : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
              ),
              AppSpacing.h8,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/reset-password'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.forgotPassword,
                    style: RyvoTypography.style(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              AppSpacing.h16,
              RyvoButton(
                label: l10n.signIn2,
                isLoading: _loading,
                onPressed: _signIn,
              ),
              AppSpacing.h24,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.donTHaveAnAccount,
                    style: RyvoTypography.style(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.signUp,
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
