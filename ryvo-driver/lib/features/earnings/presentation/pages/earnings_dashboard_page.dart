import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/earnings_entity.dart';
import '../widgets/earnings_bar_chart.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class EarningsDashboardPage extends ConsumerStatefulWidget {
  const EarningsDashboardPage({super.key});

  @override
  ConsumerState<EarningsDashboardPage> createState() => _EarningsDashboardPageState();
}

class _EarningsDashboardPageState extends ConsumerState<EarningsDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Future.wait([
      ref.read(earningsNotifierProvider.notifier).load(),
      ref.read(walletNotifierProvider.notifier).loadBalance(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(earningsNotifierProvider);
    final walletState = ref.watch(walletNotifierProvider);
    final available = walletState.value?.wallet?.availableBalance ?? 0.0;
    final pending = walletState.value?.wallet?.pendingBalance ?? 0.0;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: state.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: ShimmerList(count: 6, itemHeight: 72),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.couldNotLoadEarnings, style: _type(size: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _load,
                  child: Text(l10n.retry, style: _type(size: 14, weight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          data: (data) {
            final earnings = data.earnings ??
                const EarningsEntity(
                  weeklyTotal: 0,
                  jobCount: 0,
                  averageRating: 0,
                  dailyBreakdown: [],
                );
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.earnings,
                            style: _type(size: 22, weight: FontWeight.w700, letterSpacing: -0.4),
                          ),
                          const SizedBox(height: 28),
                          _BalanceBlock(
                            available: available,
                            pending: pending,
                            weekly: earnings.weeklyTotal,
                            jobs: earnings.jobCount,
                            rating: earnings.averageRating,
                            onWithdraw: () {
                              HapticFeedback.lightImpact();
                              context.push('/wallet');
                            },
                          ),
                          const SizedBox(height: 36),
                          Text(
                            l10n.weeklyBreakdown,
                            style: _type(size: 15, weight: FontWeight.w700, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 18),
                          EarningsBarChart(values: earnings.dailyBreakdown),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _Ledger(
                      history: data.history,
                      onOpenWallet: () => context.push('/wallet'),
                      onOpenTransaction: (id) => context.push('/transaction/$id'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BalanceBlock extends StatelessWidget {
  const _BalanceBlock({
    required this.available,
    required this.pending,
    required this.weekly,
    required this.jobs,
    required this.rating,
    required this.onWithdraw,
  });

  final double available;
  final double pending;
  final double weekly;
  final int jobs;
  final double rating;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.availableBalance,
                style: _type(size: 12, weight: FontWeight.w600, color: AppColors.textHint, letterSpacing: 0.4),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoney(available),
                  style: _type(size: 40, weight: FontWeight.w700, letterSpacing: -0.8, height: 1, tabular: true),
                ),
              ),
              if (pending > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '+${formatMoney(pending)} pending',
                  style: _type(size: 13, color: AppColors.textSecondary, tabular: true),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onWithdraw,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.navy,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: const StadiumBorder(),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.withdraw, style: _type(size: 14, weight: FontWeight.w700, color: AppColors.navy)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.divider)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SideStat(label: l10n.thisWeek, value: formatMoney(weekly)),
                  const SizedBox(height: 16),
                  _SideStat(label: l10n.jobs, value: '$jobs'),
                  const SizedBox(height: 16),
                  _SideStat(label: l10n.rating, value: rating.toStringAsFixed(1)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SideStat extends StatelessWidget {
  const _SideStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: _type(size: 11, weight: FontWeight.w500, color: AppColors.textHint),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            style: _type(size: 16, weight: FontWeight.w700, letterSpacing: -0.4, tabular: true),
          ),
        ),
      ],
    );
  }
}

class _Ledger extends StatelessWidget {
  const _Ledger({
    required this.history,
    required this.onOpenWallet,
    required this.onOpenTransaction,
  });

  final List<TransactionEntity> history;
  final VoidCallback onOpenWallet;
  final ValueChanged<String> onOpenTransaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.recentEarnings,
                    style: _type(size: 15, weight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                ),
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: onOpenWallet,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.wallet,
                      style: _type(size: 13, weight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.noEarningsYet, style: _type(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      l10n.completedJobsWillShowUpHere,
                      style: _type(size: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(history.length, (i) {
                final item = history[i];
                return _LedgerRow(
                  title: item.title,
                  amount: item.net,
                  date: item.date,
                  showDivider: i != history.length - 1,
                  onTap: () => onOpenTransaction(item.id),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.amount,
    required this.date,
    required this.showDivider,
    required this.onTap,
  });

  final String title;
  final double amount;
  final DateTime date;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d').format(date),
                    style: _type(size: 16, weight: FontWeight.w700, letterSpacing: -0.4, height: 1.1, tabular: true),
                  ),
                  Text(
                    DateFormat('MMM').format(date),
                    style: _type(size: 11, weight: FontWeight.w500, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _type(size: 14, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '+',
                    style: _type(size: 15, weight: FontWeight.w700, color: AppColors.success),
                  ),
                  TextSpan(
                    text: formatMoney(amount),
                    style: _type(size: 15, weight: FontWeight.w700, letterSpacing: -0.4, tabular: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _type({
  required double size,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.textPrimary,
  double letterSpacing = 0,
  double height = 1.2,
  bool tabular = false,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}
