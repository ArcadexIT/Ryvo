import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../domain/entities/earnings_entity.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

final _transactionProvider =
    FutureProvider.autoDispose.family<TransactionEntity, String>((ref, id) async {
  final result = await ref.read(earningsRepositoryProvider).getTransaction(id);
  return result.fold((f) => throw f, (t) => t);
});

class TransactionDetailPage extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailPage({super.key, required this.transactionId});

  String _formatDate(BuildContext context, DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? AppLocalizations.of(context).am : AppLocalizations.of(context).pm;
    return '${d.day}/${d.month}/${d.year}, $h:${d.minute.toString().padLeft(2, '0')} $ap';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(_transactionProvider(transactionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).transaction, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: tx.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(AppLocalizations.of(context).couldNotLoadTransaction,
              style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        data: (t) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Text(AppLocalizations.of(context).netPayout, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(formatMoney(t.net), style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    Text('Ref: ${t.id}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _LineItem(label: AppLocalizations.of(context).grossEarnings, value: formatMoney(t.gross)),
              _LineItem(label: AppLocalizations.of(context).platformFee, value: '-${formatMoney(t.platformFee)}', isNegative: true),
              const Divider(color: AppColors.divider, height: 32),
              _LineItem(label: AppLocalizations.of(context).netPayout, value: formatMoney(t.net), isBold: true),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).jobDetails, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Text(t.title, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                    Text(_formatDate(context, t.date), style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isNegative;
  final bool isBold;

  const _LineItem({required this.label, required this.value, this.isNegative = false, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: isBold ? 15 : 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.w400, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.poppins(fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: isNegative ? AppColors.error : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
