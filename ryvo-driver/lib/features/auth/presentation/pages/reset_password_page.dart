import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/country_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  CountryEntity? _selectedCountry;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).pleaseSelectYourCountry), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    setState(() => _loading = true);
    final phone = '${_selectedCountry!.dialCode}${_phoneController.text.trim()}';
    final error = await providerSendOtp(ref, phone, 'reset_password');
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    ref.read(pendingPhoneProvider.notifier).state = phone;
    ref.read(otpPurposeProvider.notifier).state = 'reset_password';
    context.push('/otp');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
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
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context).resetPassword, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).enterYourPhoneNumberAndWeLlSendAVerificationCode,
                  style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 36),
                PhoneCountryField(
                  hint: '234 567 8900',
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
