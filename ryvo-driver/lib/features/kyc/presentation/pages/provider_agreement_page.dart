import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ProviderAgreementPage extends ConsumerStatefulWidget {
  const ProviderAgreementPage({super.key});

  @override
  ConsumerState<ProviderAgreementPage> createState() =>
      _ProviderAgreementPageState();
}

class _ProviderAgreementPageState extends ConsumerState<ProviderAgreementPage> {
  bool _accepted = false;
  bool _loading = true;
  bool _submitting = false;
  String _version = '1';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(kycRepositoryProvider).getAgreement();
    if (!mounted) return;
    result.fold(
      (f) {
        // Keep the local agreement UI usable when the API route is missing
        // (e.g. production not yet deployed) or temporarily unavailable.
        setState(() {
          _loading = false;
          _error = f.message;
          _version = '1';
        });
      },
      (agreement) {
        ref.read(isAgreementAcceptedProvider.notifier).state =
            agreement.accepted;
        if (agreement.accepted) {
          context.go('/kyc');
          return;
        }
        setState(() {
          _loading = false;
          _version = agreement.currentVersion;
        });
      },
    );
  }

  Future<void> _submit() async {
    if (!_accepted || _submitting) return;
    setState(() => _submitting = true);
    final result =
        await ref.read(kycRepositoryProvider).acceptAgreement(_version);
    if (!mounted) return;
    result.fold(
      (f) {
        final msg = f.message.toLowerCase();
        final unavailable = msg.contains('not found') ||
            msg.contains('404') ||
            msg.contains('cannot post') ||
            msg.contains('cannot get');
        if (unavailable) {
          // Local/dev fallback when agreement API is not deployed yet.
          ref.read(isAgreementAcceptedProvider.notifier).state = true;
          setState(() => _submitting = false);
          context.go('/kyc');
          return;
        }
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message, style: GoogleFonts.poppins()),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (_) {
        ref.read(isAgreementAcceptedProvider.notifier).state = true;
        setState(() => _submitting = false);
        context.go('/kyc');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context).providerAgreement,
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).youCanStillReviewAndAcceptTheAgreementBelowForLo,
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _load,
                                child: Text(AppLocalizations.of(context).retry, style: GoogleFonts.poppins(color: AppColors.primary)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version $_version',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textHint),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Text(
                              AppLocalizations.of(context).providerAgreementBody,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.55,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CheckboxListTile(
                            value: _accepted,
                            onChanged: _submitting
                                ? null
                                : (v) =>
                                    setState(() => _accepted = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.primary,
                            title: Text(
                              'I have read and agree to the Ryvo Driver Service Agreement (v$_version).',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: RyvoButton(
                      label: _submitting ? AppLocalizations.of(context).saving : AppLocalizations.of(context).acceptContinue,
                      isLoading: _submitting,
                      onPressed: _accepted && !_submitting ? _submit : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
