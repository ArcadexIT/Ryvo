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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      showApiError(context, AppLocalizations.of(context).pleaseSelectYourCountry);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).resetPassword,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).enterYourPhoneNumberAndWeLlSendAVerificationCode,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                PhoneCountryField(
                  hint: '2345678900',
                  controller: _phoneController,
                  selectedCountry: _selectedCountry,
                  onCountryChanged: (c) => setState(() => _selectedCountry = c),
                  validator: (v) => (v?.isEmpty ?? true) ? AppLocalizations.of(context).enterYourPhoneNumber : null,
                ),
                const SizedBox(height: 32),
                RyvoButton(
                  label: _loading ? AppLocalizations.of(context).sending : AppLocalizations.of(context).sendResetCode,
                  onPressed: _loading ? null : _sendCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
