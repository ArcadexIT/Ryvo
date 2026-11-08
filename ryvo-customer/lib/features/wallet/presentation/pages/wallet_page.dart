import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_bottom_up_page_route.dart';
import '../../../../shared/widgets/ryvo_close_button.dart';
import '../../../home/presentation/pages/shell_page.dart';
import 'top_up_page.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key, this.showClose = false});

  /// Profile opens this screen above the shell, so it needs its own close control.
  final bool showClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final txAsync = ref.watch(walletTransactionsProvider);
    final l10n = AppLocalizations.of(context);
    final balanceLabel = balanceAsync.isLoading && !balanceAsync.hasValue
        ? null
        : formatMoney(balanceAsync.valueOrNull?.balance ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        leading: showClose ? const RyvoCloseButton() : null,
        title: Text(
          l10n.wallet,
          style: RyvoTypography.heading(
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(walletTransactionsProvider);
            await ref.read(walletBalanceProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + RyvoFloatingNav.lift,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BalanceTopUpCard(
                  balance: balanceLabel,
                  onTopUp: () async {
                    await Navigator.of(context).push<void>(
                      RyvoBottomUpPageRoute<void>(
                        builder: (_) => const TopUpPage(),
                      ),
                    );
                    ref.invalidate(walletBalanceProvider);
                    ref.invalidate(walletTransactionsProvider);
                  },
                ),
                const SizedBox(height: 32),
                Text(AppLocalizations.of(context).transactionHistory,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                txAsync.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )),
                  error: (e, _) => Text(e.toString(),
                      style: const TextStyle(color: Colors.white70)),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                          AppLocalizations.of(context).noTransactionsYet,
                          style: GoogleFonts.poppins(
                              color: AppColors.textSecondary));
                    }
                    return Column(
                        children: items.map((tx) => _TxCard(tx: tx)).toList());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same balance card as the post-ride payment screen, without the trip switch.
class _BalanceTopUpCard extends StatelessWidget {
  const _BalanceTopUpCard({
    required this.balance,
    required this.onTopUp,
  });

  /// Formatted balance, or null while it loads.
  final String? balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final onCard = AppColors.onCta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ryvo balance',
                  style: RyvoTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: onCard.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance ?? '—',
                  style: RyvoTypography.style(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: onCard,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTopUp();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.plus,
                    size: 14,
                    color: AppColors.obsidian,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Top Up',
                    style: RyvoTypography.style(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.obsidian,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  final WalletTransaction tx;
  const _TxCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final credit = tx.isCredit;
    final date = tx.createdAt != null
        ? DateFormat('MMM d, yyyy').format(tx.createdAt!)
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (credit ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              credit ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: credit ? AppColors.success : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.type.replaceAll('_', ' '),
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                Text(date,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '-'}${formatMoney(tx.amount)}',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: credit ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
