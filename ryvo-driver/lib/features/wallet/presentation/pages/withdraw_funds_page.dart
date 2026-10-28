import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';
import 'stripe_onboarding_page.dart';

class WithdrawFundsPage extends ConsumerStatefulWidget {
  const WithdrawFundsPage({super.key});

  @override
  ConsumerState<WithdrawFundsPage> createState() => _WithdrawFundsPageState();
}

class _WithdrawFundsPageState extends ConsumerState<WithdrawFundsPage> {
  final _amountController = TextEditingController();
  String? _selectedPreset;
  bool _submitting = false;
  bool _statusLoading = true;
  bool? _stripeConnected;
  bool? _payoutsEnabled;

  bool get _payoutsReady => _payoutsEnabled == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _amountController.addListener(() {
      if (_selectedPreset != null) setState(() => _selectedPreset = null);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _available => ref.read(walletNotifierProvider).value?.wallet?.availableBalance ?? 0;

  Future<void> _load() async {
    await ref.read(walletNotifierProvider.notifier).loadBalance();
    await _loadStripeStatus();
  }

  Future<void> _loadStripeStatus() async {
    try {
      final res = await ref.read(dioClientProvider).dio.get('/provider/stripe/status');
      final data = res.data is Map ? res.data['data'] : null;
      if (!mounted || data is! Map) return;
      setState(() {
        _stripeConnected = data['connected'] == true;
        _payoutsEnabled = data['payoutsEnabled'] == true;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  void _selectPreset(String key, double amount) {
    setState(() {
      _selectedPreset = key;
      _amountController.text = amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
    });
  }

  Future<String?> _askForPayoutEmail() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Email for payouts', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'you@email.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectStripe() async {
    try {
      final profile = await ref.read(providerProfileProvider.future);
      var email = profile?.email.trim() ?? '';
      if (!email.contains('@')) {
        email = (await _askForPayoutEmail()) ?? '';
        if (!email.contains('@')) {
          if (email.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a valid email address.')),
            );
          }
          return;
        }
        await ref.read(dioClientProvider).dio.patch('/provider/profile', data: {'email': email});
        ref.invalidate(providerProfileProvider);
      }
      final res = await ref.read(dioClientProvider).dio.post('/provider/stripe/account-link', data: {
        'refreshUrl': 'https://ryvo.arcadexit.com/stripe/refresh',
        'returnUrl': 'https://ryvo.arcadexit.com/stripe/return',
      });
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      final url = data is Map ? data['url']?.toString() : null;
      if (url == null || !mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => StripeOnboardingPage(url: url)),
      );
      await _loadStripeStatus();
    } catch (e) {
      if (!mounted) return;
      final failure = e is DioException ? e.error : null;
      final message = failure is Failure ? failure.message : 'Could not start Stripe payout setup';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirmSheet({required double amount}) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context).confirmWithdrawal, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).reviewTheDetailsBeforeSubmittingYourPayoutReques, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              _SummaryRow(label: AppLocalizations.of(context).amount, value: formatMoney(amount), highlight: true),
              const SizedBox(height: 12),
              _SummaryRow(label: AppLocalizations.of(context).destination, value: 'Stripe account'),
              const SizedBox(height: 12),
              _SummaryRow(label: AppLocalizations.of(context).processing, value: 'After RYVO approves'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(AppLocalizations.of(context).cancel, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: RyvoButton(
                      label: AppLocalizations.of(context).confirm,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  Future<void> _submit() async {
    if (!_payoutsReady) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).enterAValidAmount, style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
      return;
    }

    final available = _available;
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount exceeds available balance (${formatMoney(available)})', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await _confirmSheet(amount: amount);
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      await ref.read(walletNotifierProvider.notifier).withdraw(amount, 'stripe');
      ref.invalidate(payoutsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 44),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context).withdrawalSubmitted, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                '${formatMoney(amount)} was submitted. RYVO will pay it to your Stripe account after approval.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
          actions: [
            RyvoButton(
              label: AppLocalizations.of(context).done,
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e is Failure ? e.message : AppLocalizations.of(context).withdrawalFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.poppins()), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletNotifierProvider);
    final available = walletState.value?.wallet?.availableBalance ?? 0;
    final canWithdraw = _payoutsReady && !_submitting && available > 0;

    final presets = <Map<String, dynamic>>[
      if (available >= 50) {'key': '50', 'amount': 50.0},
      if (available >= 100) {'key': '100', 'amount': 100.0},
      if (available >= 200) {'key': '200', 'amount': 200.0},
      if (available > 0) {'key': 'max', 'amount': available, 'label': 'Max'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).withdraw, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _statusLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCard(height: 96, borderRadius: 16),
                  SizedBox(height: 24),
                  ShimmerCard(height: 14, width: 72),
                  SizedBox(height: 10),
                  ShimmerCard(height: 96, borderRadius: 14),
                  SizedBox(height: 28),
                  ShimmerCard(height: 14, width: 140),
                  SizedBox(height: 12),
                  ShimmerCard(height: 44, width: 180),
                  SizedBox(height: 16),
                  ShimmerCard(height: 56, borderRadius: 14),
                  SizedBox(height: 32),
                  ShimmerCard(height: 54, borderRadius: 14),
                ],
              ),
            )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).availableBalance, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(formatMoney(available), style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary.withOpacity(0.7), size: 32),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context).payoutTo, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            _StripeDestinationCard(
              ready: _payoutsReady,
              connected: _stripeConnected == true,
              onSetup: _connectStripe,
            ),
            const SizedBox(height: 28),
            Text(AppLocalizations.of(context).withdrawalAmount, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (presets.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: presets.map((p) {
                  final key = p['key'] as String;
                  final amount = p['amount'] as double;
                  final label = p['label'] as String? ?? formatMoney(amount);
                  final isSelected = _selectedPreset == key;
                  return GestureDetector(
                    onTap: canWithdraw || available > 0 ? () => _selectPreset(key, amount) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            RyvoTextField(
              hint: AppLocalizations.of(context).enterAmount,
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              prefixIcon: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(currencySymbol, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 32),
            RyvoButton(
              label: _submitting ? AppLocalizations.of(context).submitting : AppLocalizations.of(context).reviewWithdraw,
              onPressed: canWithdraw ? _submit : null,
            ),
            if (!_payoutsReady) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Set up Stripe payouts before you can withdraw.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ] else if (available <= 0) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(AppLocalizations.of(context).noFundsAvailableToWithdraw, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StripeDestinationCard extends StatelessWidget {
  const _StripeDestinationCard({
    required this.ready,
    required this.connected,
    required this.onSetup,
  });

  final bool ready;
  final bool connected;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ready ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (ready ? AppColors.success : AppColors.info).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ready ? Icons.check_circle_outline : Icons.account_balance_wallet_outlined,
                  color: ready ? AppColors.success : AppColors.info,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'Paid to your Stripe account' : 'Stripe payouts',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? 'Bank details stay with Stripe. RYVO sends the withdrawal after it is approved.'
                          : 'Finish Stripe setup so withdrawals can be paid to your bank.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: 14),
            RyvoButton(
              label: connected ? 'Continue Stripe setup' : 'Set up Stripe payouts',
              variant: RyvoButtonVariant.outline,
              onPressed: onSetup,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: highlight ? 18 : 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
