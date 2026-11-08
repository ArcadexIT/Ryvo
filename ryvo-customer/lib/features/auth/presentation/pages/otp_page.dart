import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/auth_scaffold.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  static const int _resendWindow = 30;
  int _seconds = _resendWindow;
  Timer? _timer;
  String _otp = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = _resendWindow);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
  }

  String _clock(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remain = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remain';
  }

  Future<void> _verify() async {
    final phone = ref.read(pendingPhoneProvider);
    if (phone == null || _otp.length != 6 || _loading) return;

    final purpose = ref.read(otpPurposeProvider);

    final router = GoRouter.of(context);
    setState(() => _loading = true);
    await dismissKeyboard();
    if (!isContextActive(context)) return;
    try {
      if (purpose == 'reset_password') {
        final newPassword = await _promptNewPassword();
        if (newPassword == null) return;
        await ref.read(authRepositoryProvider).resetPassword(
              phone: phone,
              code: _otp,
              newPassword: newPassword,
            );
        if (!isContextActive(context)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).passwordResetPleaseSignIn)),
        );
        router.go('/login');
        return;
      }

      await ref.read(authRepositoryProvider).verifyOtp(phone, _otp, purpose);
      ref.read(needsPhoneVerificationProvider.notifier).state = false;
      ref.read(isAuthenticatedProvider.notifier).state = true;
      await afterLogin(ref);
      if (router.routerDelegate.currentConfiguration.uri.path != '/home') {
        router.go('/home');
      }
    } catch (e) {
      if (isContextActive(context)) showApiError(context, e);
    } finally {
      if (isContextActive(context)) setState(() => _loading = false);
    }
  }

  Future<String?> _promptNewPassword() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          backgroundColor: AppColors.modal,
          title: Text(
            l10n.newPassword,
            style: RyvoTypography.heading(
              fontSize: 20,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          content: RyvoTextField(
            hint: l10n.enterNewPasswordMin6,
            controller: controller,
            isPassword: true,
            textInputAction: TextInputAction.done,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.cancel,
                style: RyvoTypography.style(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.length >= 6) {
                  Navigator.pop(dialogContext, controller.text);
                }
              },
              child: Text(
                l10n.reset,
                style: RyvoTypography.style(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return password;
  }

  Future<void> _resend() async {
    final phone = ref.read(pendingPhoneProvider);
    if (phone == null || _seconds > 0) return;
    try {
      await ref.read(authRepositoryProvider).sendOtp(
            phone,
            ref.read(otpPurposeProvider),
          );
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).verificationCodeSent)),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _leave() async {
    final signedIn = ref.read(isAuthenticatedProvider);
    if (signedIn && ref.read(needsPhoneVerificationProvider)) {
      await signOut(ref);
      if (!mounted) return;
      context.go('/login');
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(signedIn ? '/home' : '/register');
    }
  }

  void _onCodeChanged(String value) {
    if (value.length > _otp.length) {
      HapticFeedback.selectionClick();
    }
    setState(() => _otp = value);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = ref.watch(pendingPhoneProvider);
    final width = MediaQuery.sizeOf(context).width;
    final fieldWidth = ((width - 48) / 6 - 8).clamp(36.0, 52.0);

    return AuthScaffold(
      onBack: () {
        _leave();
      },
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(l10n.verifyPhone, style: authTitleStyle()),
          AppSpacing.h8,
          Text(
            phone != null
                ? 'Enter the 6-digit code sent to $phone'
                : l10n.enterThe6DigitCodeSentToYourNumber,
            style: authBodyStyle(),
          ),
          AppSpacing.h32,
          PinCodeTextField(
            appContext: context,
            length: 6,
            controller: _otpController,
            autoDisposeControllers: false,
            enabled: !_loading,
            onChanged: _onCodeChanged,
            onCompleted: (_) => _verify(),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            animationType: AnimationType.fade,
            animationDuration: const Duration(milliseconds: 180),
            enableActiveFill: true,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 56,
              fieldWidth: fieldWidth,
              borderWidth: 2,
              activeBorderWidth: 2,
              selectedBorderWidth: 2,
              inactiveBorderWidth: 2,
              errorBorderWidth: 2,
              activeFillColor: AppColors.surface,
              inactiveFillColor: AppColors.surface,
              selectedFillColor: AppColors.surface,
              activeColor: AppColors.focusBorder,
              selectedColor: AppColors.focusBorder,
              inactiveColor: Colors.transparent,
              errorBorderColor: AppColors.error,
            ),
            textStyle: RyvoTypography.style(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
              tabular: true,
            ),
            cursorColor: AppColors.focusBorder,
          ),
          AppSpacing.h8,
          SizedBox(
            height: 44,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                child: _seconds > 0
                    ? Row(
                        key: const ValueKey<String>('countdown'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Resend in ',
                            style: RyvoTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _clock(_seconds),
                            style: RyvoTypography.style(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                              tabular: true,
                            ),
                          ),
                        ],
                      )
                    : TextButton(
                        key: const ValueKey<String>('resend'),
                        onPressed: _resend,
                        child: Text(
                          l10n.resendCode,
                          style: RyvoTypography.style(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          AppSpacing.h24,
          RyvoButton(
            label: l10n.verify,
            isLoading: _loading,
            onPressed: _otp.length == 6 ? _verify : null,
          ),
        ],
      ),
    );
  }
}
