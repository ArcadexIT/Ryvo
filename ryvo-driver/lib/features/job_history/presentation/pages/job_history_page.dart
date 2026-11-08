import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/travel_estimate.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/job_status_chip.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

final _jobHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioClientProvider).dio.get('/provider/jobs/history');
  final body = res.data;
  final data = body is Map && body.containsKey('data') ? body['data'] : body;
  final list = data as List? ?? [];
  return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
});

class JobHistoryPage extends ConsumerWidget {
  const JobHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_jobHistoryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: history.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            itemCount: 8,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const ShimmerCard(height: 72),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.couldNotLoadHistory, style: _type(size: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(_jobHistoryProvider),
                  child: Text(l10n.retry, style: _type(size: 14, weight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          data: (jobs) {
            final entries = jobs.map((job) => _JobEntry.fromMap(context, job)).toList()
              ..sort((a, b) {
                if (a.when == null && b.when == null) return 0;
                if (a.when == null) return 1;
                if (b.when == null) return -1;
                return b.when!.compareTo(a.when!);
              });
            final earned = entries
                .where((e) => e.status == JobStatus.completed)
                .fold<double>(0, (sum, e) => sum + e.amount);
            final lines = _sheetLines(entries);

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => ref.refresh(_jobHistoryProvider.future),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.history,
                            style: _type(size: 22, weight: FontWeight.w700, letterSpacing: -0.4),
                          ),
                          if (entries.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            _Summary(count: entries.length, earned: earned),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (entries.isEmpty)
                    const SliverToBoxAdapter(child: _EmptySheet())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _sheetChild(lines[index]),
                        childCount: lines.length,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.earned});

  final int count;
  final double earned;

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
                '$count',
                style: _type(size: 40, weight: FontWeight.w700, letterSpacing: -0.8, height: 1, tabular: true),
              ),
              const SizedBox(height: 6),
              Text(l10n.jobs, style: _type(size: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.divider)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l10n.amount, style: _type(size: 11, weight: FontWeight.w500, color: AppColors.textHint)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(earned),
                      style: _type(size: 16, weight: FontWeight.w700, letterSpacing: -0.4, tabular: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySheet extends StatelessWidget {
  const _EmptySheet();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 48),
        child: _EmptyCopy(),
      ),
    );
  }
}

class _EmptyCopy extends StatelessWidget {
  const _EmptyCopy();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.noCompletedJobsYet, style: _type(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          l10n.completedJobsWillShowUpHere,
          style: _type(size: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

sealed class _SheetLine {}

class _DaySheetLine extends _SheetLine {
  _DaySheetLine(this.day, {required this.lead});
  final DateTime day;
  final bool lead;
}

class _JobSheetLine extends _SheetLine {
  _JobSheetLine(this.entry, {required this.lead, required this.showDivider});
  final _JobEntry entry;
  final bool lead;
  final bool showDivider;
}

class _TailSheetLine extends _SheetLine {}

List<_SheetLine> _sheetLines(List<_JobEntry> entries) {
  final lines = <_SheetLine>[];
  DateTime? previous;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry.day != null && entry.day != previous) {
      lines.add(_DaySheetLine(entry.day!, lead: lines.isEmpty));
    }
    final next = i + 1 < entries.length ? entries[i + 1] : null;
    final nextOpensDay = next != null && next.day != null && next.day != entry.day;
    lines.add(_JobSheetLine(entry, lead: lines.isEmpty, showDivider: next != null && !nextOpensDay));
    previous = entry.day;
  }
  lines.add(_TailSheetLine());
  return lines;
}

Widget _sheetChild(_SheetLine line) => switch (line) {
      _DaySheetLine(:final day, :final lead) => _DayLabel(day: day, lead: lead),
      _JobSheetLine(:final entry, :final lead, :final showDivider) =>
        _JobRow(entry: entry, lead: lead, showDivider: showDivider),
      _TailSheetLine() => const ColoredBox(
          color: AppColors.surface,
          child: SizedBox(height: 28),
        ),
    };

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day, required this.lead});

  final DateTime day;
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = day.year == now.year ? DateFormat('d MMM').format(day) : DateFormat('d MMM yyyy').format(day);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: lead ? const Border(top: BorderSide(color: AppColors.divider)) : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, lead ? 22 : 26, 24, 2),
        child: Text(
          label,
          style: _type(size: 12, weight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.entry, required this.lead, required this.showDivider});

  final _JobEntry entry;
  final bool lead;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final settled = entry.status == JobStatus.completed;
    final status = _statusLabel(entry.status);

    return ColoredBox(
      color: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        decoration: BoxDecoration(
          border: Border(
            top: lead ? const BorderSide(color: AppColors.divider) : BorderSide.none,
            bottom: showDivider ? const BorderSide(color: AppColors.divider) : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _type(size: 15, weight: FontWeight.w700, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          style: _type(size: 13, color: AppColors.textSecondary),
                          children: [
                            TextSpan(text: entry.service),
                            if (entry.distance != null)
                              TextSpan(
                                text: '  ·  ${formatDistanceKm(entry.distance!)}',
                                style: _type(size: 13, color: AppColors.textSecondary, tabular: true),
                              ),
                            if (status != null)
                              TextSpan(
                                text: '  ·  $status',
                                style: _type(size: 13, weight: FontWeight.w600, color: _statusColor(entry.status)),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatMoney(entry.amount),
                  style: _type(
                    size: 15,
                    weight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: settled ? AppColors.textPrimary : AppColors.textHint,
                    tabular: true,
                  ),
                ),
              ],
            ),
            if (entry.pickup != null || entry.dropoff != null) ...[
              const SizedBox(height: 12),
              _Route(pickup: entry.pickup, dropoff: entry.dropoff),
            ],
          ],
        ),
      ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.pickup, required this.dropoff});

  final String? pickup;
  final String? dropoff;

  @override
  Widget build(BuildContext context) {
    if (pickup != null && dropoff != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            children: [
              SizedBox(height: 4),
              _PickupMark(),
              SizedBox(
                width: 1.5,
                height: 18,
                child: ColoredBox(color: AppColors.divider),
              ),
              _DropoffMark(),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickup!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(size: 13, height: 1.15, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Text(
                  dropoff!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(size: 13, height: 1.15, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final only = pickup ?? dropoff!;
    return _Stop(text: only, marker: pickup != null ? const _PickupMark() : const _DropoffMark());
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.text, required this.marker});

  final String text;
  final Widget marker;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        marker,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _type(size: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _PickupMark extends StatelessWidget {
  const _PickupMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
    );
  }
}

class _DropoffMark extends StatelessWidget {
  const _DropoffMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textPrimary, width: 1.5),
      ),
    );
  }
}

class _JobEntry {
  const _JobEntry({
    required this.name,
    required this.service,
    required this.status,
    required this.amount,
    required this.when,
    this.distance,
    this.pickup,
    this.dropoff,
  });

  final String name;
  final String service;
  final JobStatus status;
  final double amount;
  final DateTime? when;
  final double? distance;
  final String? pickup;
  final String? dropoff;

  DateTime? get day {
    final value = when;
    if (value == null) return null;
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  factory _JobEntry.fromMap(BuildContext context, Map<String, dynamic> job) {
    final l10n = AppLocalizations.of(context);
    final user = (job['customer'] as Map?)?['user'] as Map?;
    final name = _text(user?['fullName']) ??
        _text(job['riderFirstName']) ??
        _text(job['customerName']) ??
        l10n.customer;
    final service = _text((job['serviceCategory'] as Map?)?['name']) ?? l10n.roadsideService;
    final raw = (job['completedAt'] ?? job['createdAt']) as String?;
    final fare = job['finalFare'] ?? job['estimatedFare'];

    return _JobEntry(
      name: name,
      service: service,
      status: _parseStatus(job['status'] as String? ?? ''),
      amount: fare == null ? 0 : (fare is num ? fare.toDouble() : double.tryParse('$fare') ?? 0),
      when: DateTime.tryParse(raw ?? ''),
      distance: _positive(job['tripDistanceKm'] ?? job['distanceKm']),
      pickup: _text(job['pickupAddress']),
      dropoff: _text(job['dropoffAddress']),
    );
  }
}

JobStatus _parseStatus(String s) => switch (s) {
      'completed' => JobStatus.completed,
      'declined' => JobStatus.declined,
      _ when s.startsWith('cancelled') => JobStatus.cancelled,
      _ => JobStatus.pending,
    };

String? _statusLabel(JobStatus status) => switch (status) {
      JobStatus.completed => null,
      JobStatus.declined => 'Declined',
      JobStatus.cancelled => 'Cancelled',
      JobStatus.pending => 'Pending',
      JobStatus.active => 'Active',
    };

Color _statusColor(JobStatus status) => switch (status) {
      JobStatus.declined || JobStatus.cancelled => AppColors.error,
      JobStatus.pending => AppColors.warning,
      JobStatus.active => AppColors.info,
      JobStatus.completed => AppColors.textSecondary,
    };

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double? _positive(dynamic value) {
  if (value == null) return null;
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || number <= 0) return null;
  return number;
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
