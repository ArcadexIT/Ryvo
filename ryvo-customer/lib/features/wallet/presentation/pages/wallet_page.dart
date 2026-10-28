import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final txAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).wallet, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary.withOpacity(0.3), AppColors.primary.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(context).availableBalance, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(AppLocalizations.of(context).active, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      balanceAsync.when(
                        loading: () => const CircularProgressIndicator(color: AppColors.primary),
                        error: (_, __) => Text('--', style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        data: (balance) => Text(
                          balance != null ? formatMoney(balance.balance) : '--',
                          style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: RyvoButton(
                              label: AppLocalizations.of(context).topUp,
                              prefixIcon: const Icon(Icons.add, color: Colors.black, size: 18),
                              height: 46,
                              borderRadius: 12,
                              onPressed: () => context.push('/top-up'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(AppLocalizations.of(context).transactionHistory, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                txAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )),
                  error: (e, _) => Text(e.toString(), style: const TextStyle(color: Colors.white70)),
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(AppLocalizations.of(context).noTransactionsYet, style: GoogleFonts.poppins(color: AppColors.textSecondary));
                    }
                    return Column(children: items.map((tx) => _TxCard(tx: tx)).toList());
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

class _TxCard extends StatelessWidget {
  final WalletTransaction tx;
  const _TxCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final credit = tx.isCredit;
    final date = tx.createdAt != null ? DateFormat('MMM d, yyyy').format(tx.createdAt!) : '';
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
              color: (credit ? AppColors.success : AppColors.error).withOpacity(0.12),
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
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(date, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
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
