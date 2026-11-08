import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';

class JobCompletedPage extends ConsumerStatefulWidget {
  const JobCompletedPage({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<JobCompletedPage> createState() => _JobCompletedPageState();
}

class _JobCompletedPageState extends ConsumerState<JobCompletedPage> {
  final _commentController = TextEditingController();
  final _selectedTags = <String>{};
  bool _submitting = false;
  bool _loading = true;
  MockJob? _job;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadJob());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadJob() async {
    final jobId = widget.jobId ?? ref.read(activeJobProvider)?.id;
    if (jobId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final detail = await ref.read(jobRepositoryProvider).fetchJobDetail(jobId);
      if (!mounted) return;
      setState(() {
        _job = detail != null ? mockJobFromEntity(detail) : ref.read(activeJobProvider);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _job = ref.read(activeJobProvider);
        _loading = false;
      });
    }
  }

  String _formatDuration(MockJob job) {
    final start = job.startedAt;
    final end = job.completedAt ?? DateTime.now();
    if (start == null) return '—';
    final diff = end.difference(start);
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min';
    return '${diff.inSeconds} sec';
  }

  String _distanceLabel(MockJob job) {
    if (job.tripDistance.trim().isNotEmpty) return job.tripDistance.trim();
    if (job.distance.trim().isNotEmpty) return job.distance.trim();
    return '—';
  }

  int _band(int rating) {
    if (rating >= 4) return 2;
    if (rating == 3) return 1;
    if (rating >= 1) return 0;
    return -1;
  }

  List<String> _tagsFor(int rating) {
    if (rating >= 4) {
      return const ['Respectful', 'On time', 'Polite', 'Friendly'];
    }
    if (rating == 3) {
      return const ['Quiet', 'Average', 'No issues'];
    }
    if (rating >= 1) {
      return const ['Late', 'Rude', 'Messy', 'Unsafe'];
    }
    return const [];
  }

  String _sentiment(int rating) {
    return switch (rating) {
      1 => 'Terrible',
      2 => 'Poor',
      3 => 'Okay',
      4 => 'Good',
      5 => 'Excellent',
      _ => 'Tap a star to rate',
    };
  }

  String _tagPrompt(int rating) {
    return switch (rating) {
      1 || 2 => 'What went wrong?',
      3 => 'Anything to add?',
      4 || 5 => 'What stood out?',
      _ => '',
    };
  }

  void _onRate(int value) {
    HapticFeedback.selectionClick();
    final previous = ref.read(selectedRatingProvider);
    if (_band(previous) != _band(value)) {
      _selectedTags.clear();
    }
    ref.read(selectedRatingProvider.notifier).state = value;
  }

  void _toggleTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedTags.add(tag)) _selectedTags.remove(tag);
    });
  }

  String _composeComment() {
    final note = _commentController.text.trim();
    final tags = _selectedTags.join(', ');
    if (tags.isEmpty) return note;
    if (note.isEmpty) return tags;
    return '$tags. $note';
  }

  Future<void> _finish() async {
    final job = _job ?? ref.read(activeJobProvider);
    final rating = ref.read(selectedRatingProvider);
    final jobId = job?.id;

    if (rating > 0 && jobId != null) {
      setState(() => _submitting = true);
      try {
        final comment = _composeComment();
        await ref.read(dioClientProvider).dio.post('/provider/ratings', data: {
          'jobId': jobId,
          'score': rating,
          if (comment.isNotEmpty) 'comment': comment,
        });
      } catch (e) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
          return;
        }
      }
    }

    ref.read(showIncomingJobProvider.notifier).state = false;
    ref.read(selectedRatingProvider.notifier).state = 0;
    JobEntity? nextJob;
    try {
      nextJob = await ref.read(jobRepositoryProvider).fetchActiveJob();
    } catch (_) {}
    if (!mounted) return;
    final route = nextJob == null ? null : routeForActiveJob(nextJob.status);
    if (nextJob != null && route != null) {
      applyActiveJobSession(ProviderScope.containerOf(context, listen: false), nextJob);
      context.go(route);
      return;
    }
    ref.read(activeJobProvider.notifier).state = null;
    context.go('/home');
  }

  void _leaveHome() {
    ref.read(activeJobProvider.notifier).state = null;
    ref.read(selectedRatingProvider.notifier).state = 0;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final job = _job ?? ref.watch(activeJobProvider);
    final rating = ref.watch(selectedRatingProvider);

    if (job == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
                const SizedBox(height: 16),
                Text(
                  l10n.jobCompleted,
                  style: _type(
                    size: 28,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.weCouldNotLoadJobDetailsYourEarningsAreInYourWal,
                  style: _type(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                RyvoButton(label: l10n.backToHome, onPressed: _leaveHome),
              ],
            ),
          ),
        ),
      );
    }

    final name = job.customerName.trim().isEmpty ? 'Rider' : job.customerName.trim();
    final pickup = job.address.trim();
    final dropoff = job.dropoffAddress?.trim() ?? '';
    final showRoute = pickup.isNotEmpty || dropoff.isNotEmpty;
    final tags = _tagsFor(rating);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _StatusLine(
                    title: l10n.jobCompleted,
                    reference: job.jobRef,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.youEarned,
                    style: _type(
                      size: 13,
                      weight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(job.payout),
                    style: _type(
                      size: 36,
                      weight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                      tabular: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StatRow(
                    distance: _distanceLabel(job),
                    distanceLabel: l10n.distance,
                    duration: _formatDuration(job),
                    durationLabel: l10n.duration,
                    service: job.jobType.trim().isEmpty ? '—' : job.jobType.trim(),
                    serviceLabel: l10n.service,
                  ),
                  if (showRoute) ...[
                    const SizedBox(height: 22),
                    _RouteTimeline(
                      pickup: pickup.isEmpty ? _compactStop(dropoff) : _compactStop(pickup),
                      dropoff: pickup.isEmpty || dropoff.isEmpty ? null : _compactStop(dropoff),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 1, color: AppColors.divider),
                  const SizedBox(height: 22),
                  _RiderHeader(name: name),
                  const SizedBox(height: 16),
                  _StarRow(rating: rating, onChanged: _onRate),
                  const SizedBox(height: 6),
                  Text(
                    _sentiment(rating),
                    style: _type(
                      size: 13,
                      weight: FontWeight.w600,
                      color: rating == 0 ? AppColors.textHint : AppColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment.topCenter,
                    child: rating == 0
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tagPrompt(rating),
                                  style: _type(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final tag in tags)
                                      _TagChip(
                                        label: tag,
                                        selected: _selectedTags.contains(tag),
                                        onTap: () => _toggleTag(tag),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _commentController,
                                  minLines: 2,
                                  maxLines: 4,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  cursorColor: AppColors.lime,
                                  style: _type(
                                    size: 14,
                                    weight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.writeAReviewOptional,
                                    hintStyle: _type(
                                      size: 14,
                                      weight: FontWeight.w500,
                                      color: AppColors.textHint,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: const EdgeInsets.all(14),
                                    border: _noteBorder(AppColors.divider),
                                    enabledBorder: _noteBorder(AppColors.divider),
                                    focusedBorder: _noteBorder(AppColors.lime, width: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: RyvoButton(
                label: l10n.done,
                isLoading: _submitting,
                onPressed: _submitting ? null : _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

OutlineInputBorder _noteBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
}

String _compactStop(String raw) {
  final parts = raw
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return raw;
  return parts.length == 1 ? parts.first : parts.take(2).join(', ');
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'R';
  String glyph(String value) => value.isEmpty ? '' : value[0].toUpperCase();
  if (parts.length == 1) return glyph(parts.first);
  return '${glyph(parts.first)}${glyph(parts.last)}';
}

TextStyle _type({
  required double size,
  required FontWeight weight,
  required Color color,
  double letterSpacing = 0,
  bool tabular = false,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.2,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.title, required this.reference});

  final String title;
  final String reference;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _type(
              size: 15,
              weight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (reference.trim().isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            reference.trim(),
            style: _type(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.textSecondary,
              tabular: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.distance,
    required this.distanceLabel,
    required this.duration,
    required this.durationLabel,
    required this.service,
    required this.serviceLabel,
  });

  final String distance;
  final String distanceLabel;
  final String duration;
  final String durationLabel;
  final String service;
  final String serviceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Stat(value: distance, label: distanceLabel, tabular: true)),
        const _StatDivider(),
        Expanded(child: _Stat(value: duration, label: durationLabel, tabular: true)),
        const _StatDivider(),
        Expanded(child: _Stat(value: service, label: serviceLabel)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: 1,
        height: 36,
        child: ColoredBox(color: AppColors.divider),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.tabular = false});

  final String value;
  final String label;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _type(
            size: 15,
            weight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
            tabular: tabular,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: _type(
            size: 12,
            weight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.pickup, required this.dropoff});

  final String pickup;
  final String? dropoff;

  static const double _node = 8;

  @override
  Widget build(BuildContext context) {
    final hasDropoff = dropoff != null && dropoff!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: Column(
            children: [
              const SizedBox(height: 5),
              const _RouteNode(filled: true),
              if (hasDropoff) ...[
                const SizedBox(
                  height: 22,
                  child: Center(
                    child: SizedBox(
                      width: 1.5,
                      height: 22,
                      child: ColoredBox(color: AppColors.divider),
                    ),
                  ),
                ),
                const _RouteNode(filled: false),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _type(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (hasDropoff) ...[
                const SizedBox(height: 14),
                Text(
                  dropoff!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _RouteTimeline._node,
      height: _RouteTimeline._node,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? AppColors.lime : Colors.transparent,
          borderRadius: filled ? null : BorderRadius.circular(1),
          shape: filled ? BoxShape.circle : BoxShape.rectangle,
          border: filled
              ? null
              : Border.all(color: AppColors.white, width: 1.5),
        ),
      ),
    );
  }
}

class _RiderHeader extends StatelessWidget {
  const _RiderHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.surface,
          child: Text(
            _initials(name),
            style: _type(
              size: 14,
              weight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _type(
                  size: 18,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'How was this trip?',
                style: _type(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        final filled = rating >= value;
        return Semantics(
          button: true,
          selected: filled,
          label: '$value star${value == 1 ? '' : 's'}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: Padding(
              padding: EdgeInsets.only(right: index == 4 ? 0 : 6, top: 2, bottom: 2),
              child: Icon(
                Icons.star_rounded,
                size: 36,
                color: filled ? AppColors.primary : AppColors.grey300,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.white : AppColors.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: _type(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
