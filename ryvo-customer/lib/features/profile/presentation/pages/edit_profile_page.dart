import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/app_providers.dart';
import '../widgets/ryvo_modal_scaffold.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  var _ready = false;
  var _saving = false;
  String? _error;
  String? _localPath;
  var _removePhoto = false;

  @override
  void dispose() {
    if (_ready) {
      _name.dispose();
      _email.dispose();
    }
    super.dispose();
  }

  void _bind(String name, String email) {
    if (_ready) return;
    _name = TextEditingController(text: name);
    _email = TextEditingController(text: email);
    _ready = true;
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() {
      _localPath = file.path;
      _removePhoto = false;
    });
  }

  Future<void> _choosePhoto(String existingUrl) async {
    final hasPhoto =
        _localPath != null || (!_removePhoto && existingUrl.isNotEmpty);
    final source = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      backgroundColor: AppColors.modal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: AppColors.textPrimary),
                  title: Text(
                    'Take photo',
                    style: RyvoTypography.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, _PhotoChoice.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_outlined, color: AppColors.textPrimary),
                  title: Text(
                    'Choose from gallery',
                    style: RyvoTypography.style(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
                ),
                if (hasPhoto)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: AppColors.dangerText),
                    title: Text(
                      'Remove photo',
                      style: RyvoTypography.style(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dangerText,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, _PhotoChoice.remove),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || source == null) return;
    HapticFeedback.selectionClick();
    switch (source) {
      case _PhotoChoice.camera:
        await _pick(ImageSource.camera);
      case _PhotoChoice.gallery:
        await _pick(ImageSource.gallery);
      case _PhotoChoice.remove:
        setState(() {
          _localPath = null;
          _removePhoto = true;
        });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (email.isNotEmpty && !email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      String? avatarUrl;
      if (_localPath != null) {
        avatarUrl = await repo.uploadAvatar(File(_localPath!));
      }
      await repo.updateProfile(
        fullName: name,
        email: email,
        avatarUrl: avatarUrl,
        clearAvatar: _removePhoto && _localPath == null,
      );
      ref.invalidate(profileProvider);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile != null) {
      _bind(profile.fullName.trim(), profile.email?.trim() ?? '');
    }
    final phone = profile?.phone ?? '';
    final existingUrl = profile?.avatarUrl?.trim() ?? '';

    return RyvoModalScaffold(
      title: 'Edit profile',
      body: !_ready
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Center(
                  child: _PhotoPicker(
                    initials: profile?.initials ?? '?',
                    localPath: _localPath,
                    existingUrl: _removePhoto ? '' : existingUrl,
                    onTap: _saving ? null : () => _choosePhoto(existingUrl),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Photo is optional',
                    style: RyvoTypography.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  phone,
                  style: RyvoTypography.style(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    tabular: true,
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Name'),
                TextField(
                  controller: _ready ? _name : null,
                  textCapitalization: TextCapitalization.words,
                  style: RyvoTypography.style(color: AppColors.textPrimary),
                  decoration: _fill('Your name'),
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Email'),
                TextField(
                  controller: _ready ? _email : null,
                  keyboardType: TextInputType.emailAddress,
                  style: RyvoTypography.style(color: AppColors.textPrimary),
                  decoration: _fill('you@email.com'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: RyvoTypography.style(
                        fontSize: 13, color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 24),
                Material(
                  color: AppColors.cta,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: _saving ? null : _save,
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 52,
                      child: Center(
                        child: Text(
                          _saving ? 'Saving' : 'Save',
                          style: RyvoTypography.style(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onCta,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

enum _PhotoChoice { camera, gallery, remove }

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.initials,
    required this.localPath,
    required this.existingUrl,
    required this.onTap,
  });

  final String initials;
  final String? localPath;
  final String existingUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        initials,
        style: RyvoTypography.style(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.6,
        ),
      ),
    );
    Widget face = fallback;
    if (localPath != null) {
      face = Image.file(File(localPath!), fit: BoxFit.cover);
    } else if (existingUrl.isNotEmpty) {
      face = Image.network(
        existingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: face,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.cta,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Icon(Icons.camera_alt, size: 16, color: AppColors.onCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: RyvoTypography.style(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

InputDecoration _fill(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    hintStyle: RyvoTypography.style(color: AppColors.textHint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.focusBorder, width: 1.5),
    ),
  );
}
