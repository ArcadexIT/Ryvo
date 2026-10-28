import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/rating_stars.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

final _performanceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ref.read(dioClientProvider).dio.get('/provider/performance');
  final body = res.data;
  final data = body is Map && body.containsKey('data') ? body['data'] : body;
  return (data as Map).cast<String, dynamic>();
});

class PerformancePage extends ConsumerWidget {
  const PerformancePage({super.key});

  double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = raw is DateTime ? raw : DateTime.tryParse('$raw');
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<Map<String, dynamic>> _parseReviews(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perf = ref.watch(_performanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).myPerformance, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: perf.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(AppLocalizations.of(context).couldNotLoadPerformance, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        data: (data) {
          final avg = _d(data['averageRating']);
          final reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
          final reviews = _parseReviews(data['reviews']);
          final rawBreakdown = (data['ratingBreakdown'] as Map?)?.cast<String, dynamic>() ?? {};
          final total = rawBreakdown.values.fold<double>(0, (s, v) => s + _d(v));
          final breakdown = <int, double>{
            for (var star = 1; star <= 5; star++)
              star: total > 0 ? _d(rawBreakdown['$star']) / total : 0.0,
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _MetricCard(label: AppLocalizations.of(context).acceptanceRate, value: '${(data['acceptanceRate'] as num?)?.toInt() ?? 0}%')),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricCard(label: AppLocalizations.of(context).completionRate, value: '${(data['completionRate'] as num?)?.toInt() ?? 0}%')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _MetricCard(label: AppLocalizations.of(context).totalJobs, value: '${(data['totalJobs'] as num?)?.toInt() ?? 0}')),
                    const SizedBox(width: 12),
                    Expanded(child: _MetricCard(label: AppLocalizations.of(context).reviews, value: '$reviewCount')),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Text(AppLocalizations.of(context).averageRating, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(avg.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      RatingStars(rating: avg, size: 24),
                      const SizedBox(height: 20),
                      StarBreakdown(breakdown: breakdown),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context).customerReviews, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                if (reviews.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(AppLocalizations.of(context).noReviewsYet, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...reviews.map((r) => _ReviewCard(
                        fromName: '${r['fromName'] ?? 'Customer'}',
                        score: (r['score'] as num?)?.toInt() ?? 0,
                        comment: r['comment'] as String?,
                        jobNumber: r['jobNumber'] as String?,
                        date: _formatDate(r['createdAt']),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String fromName;
  final int score;
  final String? comment;
  final String? jobNumber;
  final String date;

  const _ReviewCard({
    required this.fromName,
    required this.score,
    this.comment,
    this.jobNumber,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fromName,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              if (date.isNotEmpty)
                Text(date, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              RatingStars(rating: score.toDouble(), size: 16),
              if (jobNumber != null && jobNumber!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('· $jobNumber', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
              ],
            ],
          ),
          if (comment != null && comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment!.trim(),
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
