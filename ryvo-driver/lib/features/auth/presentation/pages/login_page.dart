import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/country_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/verification_sync.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  CountryEntity? _selectedCountry;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pleaseSelectYourCountry), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    setState(() => _loading = true);
    final error = await providerSignIn(
      ProviderScope.containerOf(context, listen: false),
      '${_selectedCountry!.dialCode}${_phoneController.text.trim()}',
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    context.go(providerOnboardingRoute(
      agreementAccepted: ref.read(isAgreementAcceptedProvider),
      kycApproved: ref.read(isKycApprovedProvider),
      documentsInReview: ref.read(isKycInReviewProvider),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Center(
                  child: AppLogo(size: 46, variant: AppLogoVariant.wordmark),
                ),
                const SizedBox(height: 32),
                Text(AppLocalizations.of(context).welcomeBack, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context).signInToYourProviderAccount, style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary)),
                const SizedBox(height: 40),
                PhoneCountryField(
                  hint: '234 567 8900',
                  controller: _phoneController,
                  selectedCountry: _selectedCountry,
                  onCountryChanged: (c) => setState(() => _selectedCountry = c),
                  validator: (v) => (v?.isEmpty ?? true) ? AppLocalizations.of(context).enterYourPhoneNumber : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RyvoTextField(
                  hint: AppLocalizations.of(context).enterPassword,
                  label: AppLocalizations.of(context).password,
                  controller: _passwordController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  validator: (v) => (v?.isEmpty ?? true) ? AppLocalizations.of(context).enterYourPassword : null,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/reset-password'),
                    child: Text(AppLocalizations.of(context).forgotPassword, style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 24),
                RyvoButton(
                  label: _loading ? AppLocalizations.of(context).signingIn : AppLocalizations.of(context).signIn2,
                  onPressed: _loading ? null : _signIn,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.of(context).donTHaveAnAccount, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14)),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: Text(AppLocalizations.of(context).signUp, style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
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
