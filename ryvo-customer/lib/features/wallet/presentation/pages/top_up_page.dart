import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class TopUpPage extends ConsumerStatefulWidget {
  const TopUpPage({super.key});

  @override
  ConsumerState<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends ConsumerState<TopUpPage> {
  int? _selectedAmount;
  final _customController = TextEditingController();
  final _presets = [10, 20, 50, 100];
  bool _loading = false;

  int get _amount => _selectedAmount ?? (int.tryParse(_customController.text) ?? 0);

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    if (_amount <= 0) return;
    setState(() => _loading = true);
    try {
      await ref.read(walletRepositoryProvider).topUp(
            _amount.toDouble(),
            description: 'Wallet top up',
          );
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(walletTransactionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${formatMoney(_amount.toDouble())} to wallet')),
      );
      context.pop();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(walletBalanceProvider).valueOrNull?.balance ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).topUpWallet, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context).currentBalance, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                    Text(formatMoney(balance), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(AppLocalizations.of(context).selectAmount, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              Row(
                children: _presets.map((amount) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAmount = amount;
                        _customController.clear();
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: amount != _presets.last ? 10 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedAmount == amount ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedAmount == amount ? AppColors.primary : AppColors.divider,
                          width: _selectedAmount == amount ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        formatMoney(amount.toDouble()),
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _selectedAmount == amount ? AppColors.primary : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              Text(AppLocalizations.of(context).orEnterCustomAmount, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              RyvoTextField(
                hint: formatMoney(0),
                controller: _customController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                onChanged: (_) => setState(() => _selectedAmount = null),
              ),
              const Spacer(),
              if (_amount > 0)
                Text(
                  'New balance after top up: ${formatMoney(balance + _amount)}',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              RyvoButton(
                label: _loading
                    ? AppLocalizations.of(context).processing
                    : _amount > 0
                        ? 'Top Up ${formatMoney(_amount.toDouble())}'
                        : AppLocalizations.of(context).selectAmount,
                onPressed: (_loading || _amount <= 0) ? null : _topUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
