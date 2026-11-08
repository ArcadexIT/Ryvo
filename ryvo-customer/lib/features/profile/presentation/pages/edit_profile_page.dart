import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      await ref.read(profileRepositoryProvider).updateProfile(
            fullName: name,
            email: email,
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

    return RyvoModalScaffold(
      title: 'Edit profile',
      body: !_ready
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
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
