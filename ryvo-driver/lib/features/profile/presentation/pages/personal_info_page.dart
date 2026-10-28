import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/provider_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  String? _profileImagePath;
  String? _existingAvatarUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _initFromProfile(ProviderEntity? provider) {
    if (_initialized || provider == null) return;
    _nameController.text = provider.name;
    _phoneController.text = provider.phone;
    _emailController.text = provider.email;
    _existingAvatarUrl = provider.avatarUrl;
    _initialized = true;
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{'fullName': _nameController.text.trim()};

      if (_profileImagePath != null) {
        final fileUrl = await ref.read(fileUploadServiceProvider).uploadProviderFile(
              localPath: _profileImagePath!,
              folder: 'avatars',
            );
        payload['avatarUrl'] = fileUrl;
      }

      await ref.read(dioClientProvider).dio.patch('/provider/profile', data: payload);
      ref.invalidate(providerProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileUpdatedSuccessfully, style: GoogleFonts.poppins()),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', 'Could not save profile'),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildAvatar() {
    final hasLocal = _profileImagePath != null;

    return GestureDetector(
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
                color: hasLocal || _existingAvatarUrl != null ? AppColors.primary : AppColors.divider,
                width: 2.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasLocal
                ? Image.file(File(_profileImagePath!), fit: BoxFit.cover)
                : _existingAvatarUrl != null && _existingAvatarUrl!.isNotEmpty
                    ? SecureNetworkImage(
                        fileUrl: _existingAvatarUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorWidget: Icon(Icons.person_outline, size: 48, color: AppColors.grey500),
                      )
                    : Icon(Icons.person_outline, size: 48, color: AppColors.grey500),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).couldNotLoadProfile,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).checkYourConnectionAndTryAgain,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                RyvoButton(
                  label: AppLocalizations.of(context).retry,
                  onPressed: () => ref.invalidate(providerProfileProvider),
                ),
              ],
            ),
          ),
        ),
        data: (provider) {
          _initFromProfile(provider);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).personalInformation,
                      style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context).updateYourProfileDetails,
                      style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    Center(child: _buildAvatar()),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        AppLocalizations.of(context).tapToChangePhoto,
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    if (provider != null) ...[
                      const SizedBox(height: 16),
                      Center(child: _VerificationBadge(status: provider.verificationStatus)),
                    ],
                    const SizedBox(height: 28),
                    RyvoTextField(
                      hint: AppLocalizations.of(context).johnDoe,
                      label: AppLocalizations.of(context).fullName,
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      validator: (v) => (v?.trim().isEmpty ?? true) ? AppLocalizations.of(context).enterYourFullName : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    RyvoTextField(
                      hint: '+1 234 567 8900',
                      label: AppLocalizations.of(context).phoneNumber,
                      controller: _phoneController,
                      readOnly: true,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Padding(padding: EdgeInsets.all(14), child: Text('🇺🇸', style: TextStyle(fontSize: 18))),
                      suffixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.grey500),
                    ),
                    const SizedBox(height: 16),
                    RyvoTextField(
                      hint: AppLocalizations.of(context).johnExampleCom,
                      label: AppLocalizations.of(context).email,
                      controller: _emailController,
                      readOnly: true,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      suffixIcon: const Icon(Icons.lock_outline, size: 18, color: AppColors.grey500),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.info),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).phoneAndEmailAreLinkedToYourAccountAndCannotBeCh,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    RyvoButton(
                      label: _saving ? AppLocalizations.of(context).saving : AppLocalizations.of(context).saveChanges,
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final String status;

  const _VerificationBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('Verified Driver', AppColors.success, Icons.verified_user),
      'rejected' => ('Verification Rejected', AppColors.error, Icons.cancel_outlined),
      'suspended' => ('Account Suspended', AppColors.error, Icons.block),
      _ => ('Verification Pending', AppColors.warning, Icons.schedule),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
