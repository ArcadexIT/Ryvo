import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      showApiError(context, AppLocalizations.of(context).pleaseSelectYourCountry);
      return;
    }
    if (!_acceptedTerms) {
      showApiError(context, AppLocalizations.of(context).pleaseAcceptTheTermsAndPrivacyPolicy);
      return;
    }
    final phone = composeE164(
      _selectedCountry!.dialCode,
      _phoneController.text.trim(),
    );
    setState(() => _loading = true);
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
        if (!mounted) return;
        context.push('/otp');
        return;
      }
      ref.read(needsPhoneVerificationProvider.notifier).state = false;
      ref.read(isAuthenticatedProvider.notifier).state = true;
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).createAccount,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).joinRyvoAndGetHelpInMinutes,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                RyvoTextField(
                  hint: AppLocalizations.of(context).johnDoe,
                  label: AppLocalizations.of(context).fullName,
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? AppLocalizations.of(context).enterYourFullName : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RyvoTextField(
                  hint: 'you@email.com',
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return null;
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                PhoneCountryField(
                  hint: '2345678900',
                  controller: _phoneController,
                  selectedCountry: _selectedCountry,
                  onCountryChanged: (c) => setState(() => _selectedCountry = c),
                  validator: (v) => (v?.length ?? 0) < 7
                      ? AppLocalizations.of(context).enterAValidPhoneNumber
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RyvoTextField(
                  hint: AppLocalizations.of(context).min8Characters,
                  label: AppLocalizations.of(context).password,
                  controller: _passwordController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  validator: (v) => (v?.length ?? 0) < 8
                      ? AppLocalizations.of(context).passwordMustBeAtLeast8Characters
                      : null,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),
                _TermsAcceptance(
                  accepted: _acceptedTerms,
                  onChanged: (value) => setState(() => _acceptedTerms = value),
                ),
                const SizedBox(height: 24),
                RyvoButton(
                  label: _loading ? AppLocalizations.of(context).creatingAccount : AppLocalizations.of(context).createAccount,
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context).alreadyHaveAnAccount,
                      style: GoogleFonts.poppins(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        AppLocalizations.of(context).signIn,
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
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
    final base = GoogleFonts.poppins(fontSize: 13, height: 1.45, color: AppColors.textSecondary);
    final link = base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            activeColor: AppColors.primary,
            side: BorderSide(color: AppColors.textHint),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        const SizedBox(width: 10),
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
