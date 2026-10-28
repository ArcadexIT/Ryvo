import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  int _seconds = 60;
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
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _verify() async {
    final phone = ref.read(pendingPhoneProvider);
    if (phone == null || _otp.length != 6) return;

    final purpose = ref.read(otpPurposeProvider);

    setState(() => _loading = true);
    try {
      if (purpose == 'reset_password') {
        final newPassword = await _promptNewPassword();
        if (newPassword == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        await ref.read(authRepositoryProvider).resetPassword(
              phone: phone,
              code: _otp,
              newPassword: newPassword,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).passwordResetPleaseSignIn)),
        );
        context.go('/login');
        return;
      }

      await ref.read(authRepositoryProvider).verifyOtp(phone, _otp, purpose);
      ref.read(needsPhoneVerificationProvider.notifier).state = false;
      ref.read(isAuthenticatedProvider.notifier).state = true;
      ref.invalidate(profileProvider);
      await afterLogin(ref);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptNewPassword() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppLocalizations.of(context).newPassword,
            style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 18)),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: GoogleFonts.poppins(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: AppLocalizations.of(context).enterNewPasswordMin6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.length >= 6) Navigator.pop(ctx, controller.text);
            },
            child: Text(AppLocalizations.of(context).reset, style: GoogleFonts.poppins(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _resend() async {
    final phone = ref.read(pendingPhoneProvider);
    if (phone == null) return;
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone, ref.read(otpPurposeProvider));
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).verificationCodeSent)),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(pendingPhoneProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () async {
            final signedIn = ref.read(isAuthenticatedProvider);
            if (signedIn && ref.read(needsPhoneVerificationProvider)) {
              await signOut(ref);
              if (!context.mounted) return;
              context.go('/login');
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(signedIn ? '/home' : '/register');
            }
          },
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).verifyPhone,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phone != null
                    ? 'Enter the 6-digit code sent to $phone'
                    : AppLocalizations.of(context).enterThe6DigitCodeSentToYourNumber,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Demo code: 123456',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                onChanged: (v) => setState(() => _otp = v),
                onCompleted: (_) => _verify(),
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 56,
                  fieldWidth: 48,
                  activeFillColor: AppColors.surface,
                  inactiveFillColor: AppColors.surface,
                  selectedFillColor: AppColors.surface,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  selectedColor: AppColors.primary,
                ),
                enableActiveFill: true,
                textStyle: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Center(
                child: _seconds > 0
                    ? Text(
                        'Resend code in ${_seconds}s',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: Text(
                          AppLocalizations.of(context).resendCode,
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 32),
              RyvoButton(
                label: _loading ? AppLocalizations.of(context).verifying : AppLocalizations.of(context).verify,
                onPressed: (_loading || _otp.length != 6) ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
