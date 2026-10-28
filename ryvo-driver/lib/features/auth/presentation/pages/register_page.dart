import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/country_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/verification_sync.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  CountryEntity? _selectedCountry;
  bool _loading = false;
  String? _profileImagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _profileImagePath = file.path);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text(AppLocalizations.of(context).takePhoto, style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text(AppLocalizations.of(context).chooseFromGallery, style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseSelectYourCountry, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final phone = '${_selectedCountry!.dialCode}${_phoneController.text.trim()}';
    final outcome = await providerRegister(
      ProviderScope.containerOf(context, listen: false),
      name: _nameController.text.trim(),
      phone: phone,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      avatarLocalPath: _profileImagePath,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (outcome.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(outcome.error!), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    final config = await ref.refresh(appConfigProvider.future);
    if (!mounted) return;

    if (config.providerOtpEnabled) {
      ref.read(pendingPhoneProvider.notifier).state = phone;
      ref.read(otpPurposeProvider.notifier).state = 'register';
      await providerSendOtp(ref, phone, 'register');
      if (!mounted) return;
      if (outcome.avatarWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created, but photo upload failed: ${outcome.avatarWarning}'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
      context.push('/otp');
      return;
    }

    if (outcome.avatarWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created, but photo upload failed: ${outcome.avatarWarning}'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
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
                Text(AppLocalizations.of(context).becomeAProvider, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context).joinRyvoAndStartEarningToday, style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary)),
                const SizedBox(height: 28),
                Center(
                  child: GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(
                              color: _profileImagePath != null ? AppColors.primary : AppColors.divider,
                              width: 2.5,
                            ),
                            image: _profileImagePath != null
                                ? DecorationImage(
                                    image: FileImage(File(_profileImagePath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profileImagePath == null
                              ? Icon(Icons.person_outline, size: 48, color: AppColors.grey500)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppLocalizations.of(context).profilePhotoOptionalSelfieSetDuringVerification,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
                RyvoTextField(
                  hint: AppLocalizations.of(context).johnDoe,
                  label: AppLocalizations.of(context).fullName,
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  validator: (v) => (v?.isEmpty ?? true) ? AppLocalizations.of(context).enterYourFullName : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                PhoneCountryField(
                  hint: '234 567 8900',
                  controller: _phoneController,
                  selectedCountry: _selectedCountry,
                  onCountryChanged: (c) => setState(() => _selectedCountry = c),
                  validator: (v) => (v?.length ?? 0) < 7 ? AppLocalizations.of(context).enterAValidPhoneNumber : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RyvoTextField(
                  hint: AppLocalizations.of(context).johnExampleCom,
                  label: AppLocalizations.of(context).email,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Enter your email';
                    if (!v!.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RyvoTextField(
                  hint: AppLocalizations.of(context).min8Characters,
                  label: AppLocalizations.of(context).password,
                  controller: _passwordController,
                  isPassword: true,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  validator: (v) => (v?.length ?? 0) < 8 ? AppLocalizations.of(context).passwordMustBeAtLeast8Characters : null,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),
                RyvoButton(
                  label: _loading ? AppLocalizations.of(context).creatingAccount : AppLocalizations.of(context).createAccount,
                  onPressed: _loading ? null : _register,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.of(context).alreadyHaveAnAccount, style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14)),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(AppLocalizations.of(context).signIn, style: GoogleFonts.poppins(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
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
