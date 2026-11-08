import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/job_alert_sound.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Offer card that drops in over the map and counts down on its own ticker.
class IncomingJobSheet extends ConsumerStatefulWidget {
  const IncomingJobSheet({super.key});

  @override
  ConsumerState<IncomingJobSheet> createState() => _IncomingJobSheetState();
}

class _IncomingJobSheetState extends ConsumerState<IncomingJobSheet> with TickerProviderStateMixin {
  /// Used only when the offer has no server expiry. Matches the API default.
  static const _fallbackSeconds = 30;

  int _totalSeconds = _fallbackSeconds;
  String? _offerId;
  bool _expired = false;
  bool _busy = false;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _enter, curve: Curves.fastOutSlowIn);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, -0.28), end: Offset.zero).animate(
    CurvedAnimation(parent: _enter, curve: Curves.fastOutSlowIn),
  );
  late final Animation<double> _acceptScale = Tween<double>(begin: 0.96, end: 1).animate(
    CurvedAnimation(parent: _enter, curve: const Interval(0.45, 1, curve: Curves.fastOutSlowIn)),
  );
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _fallbackSeconds),
  )..addStatusListener(_onCountdownStatus);

  void _onCountdownStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _expire();
  }

  @override
  void initState() {
    super.initState();
    _arm(ref.read(jobNotifierProvider).value?.incomingJob);
  }

  int _secondsLeft(JobEntity? job) {
    final expiresAt = job?.expiresAt;
    if (expiresAt == null) return _fallbackSeconds;
    final left = expiresAt.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  void _arm(JobEntity? job) {
    if (job == null || job.id.isEmpty) return;
    if (job.id == _offerId && (_countdown.isAnimating || _expired)) return;
    _offerId = job.id;
    _expired = false;
    final left = _secondsLeft(job);
    _totalSeconds = left > 0 ? left : 1;
    _countdown.stop();
    _countdown.duration = Duration(seconds: _totalSeconds);
    if (left <= 0) {
      _expire();
      return;
    }
    JobAlertSound.playIncomingJob();
    _enter.forward(from: 0);
    _countdown.reverse(from: left / _totalSeconds);
  }

  void _expire() {
    if (_expired) return;
    _expired = true;
    if (_countdown.isAnimating) _countdown.stop();
    JobAlertSound.stop();
    if (!mounted) return;
    final id = _offerId ?? ref.read(jobNotifierProvider).value?.incomingJob?.id;
    if (id != null && id.isNotEmpty) {
      ref.read(dismissedIncomingOfferIdProvider.notifier).state = id;
    }
    ref.read(showIncomingJobProvider.notifier).state = false;
  }

  @override
  void dispose() {
    _countdown.removeStatusListener(_onCountdownStatus);
    _countdown.dispose();
    _enter.dispose();
    JobAlertSound.stop();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    if (incoming == null) {
      _reject();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    JobAlertSound.stop();
    final onTrip = ref.read(activeJobProvider)?.status == JobStatusEntity.inProgress;
    final result = await ref.read(jobRepositoryProvider).acceptJob(incoming.id);
    if (!mounted) return;
    result.fold(
      (f) {
        // Accept failed on the server: surface the error, keep the offer open.
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message), backgroundColor: AppColors.error),
        );
      },
      (job) {
        ref.read(dismissedIncomingOfferIdProvider.notifier).state = incoming.id;
        ref.read(showIncomingJobProvider.notifier).state = false;
        if (onTrip) {
          ref.read(activeJobProvider.notifier).state = mockJobFromEntity(job);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Next trip starts after this dropoff')),
          );
          return;
        }
        applyActiveJobSession(ProviderScope.containerOf(context, listen: false), job);
        final route = routeForActiveJob(job.status);
        if (route != null) context.push(route);
      },
    );
  }

  void _reject() {
    JobAlertSound.stop();
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    if (incoming != null) {
      ref.read(dismissedIncomingOfferIdProvider.notifier).state = incoming.id;
      if (!incoming.isBidRequest) {
        ref.read(jobRepositoryProvider).declineJob(incoming.id);
      }
    }
    ref.read(showIncomingJobProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(jobNotifierProvider, (prev, next) {
      final job = next.value?.incomingJob;
      if (job?.id != _offerId) _arm(job);
    });

    final incoming = ref.watch(jobNotifierProvider).value?.incomingJob;
    final liveLoc = ref.watch(locationStreamProvider).valueOrNull;
    final job = incoming != null
        ? mockJobFromEntity(
            incoming,
            providerLat: liveLoc?.latitude,
            providerLng: liveLoc?.longitude,
          )
        : mockIncomingJob;
    final gpsActive = liveLoc != null;
    final tripDistance = job.tripDistance.trim().isEmpty ? job.distance : job.tripDistance;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _countdown,
                builder: (context, _) {
                  final seconds = (_countdown.value * _totalSeconds).ceil().clamp(0, _totalSeconds);
                  final urgent = seconds <= 5;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: _countdown.value.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppColors.grey100,
                        color: urgent ? AppColors.error : AppColors.success,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _TitleRow(
                          seconds: seconds,
                          urgent: urgent,
                          isHighPriority: job.isHighPriority,
                          chainedNote: incoming?.chained == true
                              ? 'After this dropoff · about ${job.eta} until the next pickup'
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FareRow(
                      job: job,
                      tripDistance: tripDistance,
                      busy: _busy,
                      acceptScale: _acceptScale,
                      onAccept: _busy ? null : _accept,
                    ),
                    const SizedBox(height: 12),
                    _RouteBlock(job: job, gpsActive: gpsActive),
                    _FooterActions(
                      onReject: _reject,
                      onCounter: incoming != null && incoming.isBidRequest ? () => _counter(incoming) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _counter(JobEntity bidJob) async {
    final controller = TextEditingController(
      text: (bidJob.offeredPrice ?? bidJob.payout).toStringAsFixed(2),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter offer'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Your price'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0) return;
    final jobId = bidJob.jobId.isEmpty ? bidJob.id : bidJob.jobId;
    await ref.read(jobRepositoryProvider).counterBid(jobId, amount);
    if (!mounted) return;
    ref.read(showIncomingJobProvider.notifier).state = false;
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.seconds,
    required this.urgent,
    required this.isHighPriority,
    this.chainedNote,
  });

  final int seconds;
  final bool urgent;
  final bool isHighPriority;
  final String? chainedNote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'New ride request',
                style: _offerStyle(size: 16, weight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.4),
              ),
            ),
            if (isHighPriority) ...[
              const _PriorityChip(),
              const SizedBox(width: 8),
            ],
            _TimerChip(seconds: seconds, urgent: urgent),
          ],
        ),
        if (chainedNote != null) ...[
          const SizedBox(height: 8),
          Text(
            chainedNote!,
            style: _offerStyle(size: 12, weight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          AppLocalizations.of(context).highPRIORITY,
          style: _offerStyle(size: 10, weight: FontWeight.w700, color: AppColors.error, letterSpacing: 0.2),
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.seconds, required this.urgent});

  final int seconds;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.error : AppColors.textPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: urgent ? AppColors.errorLight : AppColors.grey100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${seconds}s',
          style: _offerStyle(size: 13, weight: FontWeight.w700, color: color, letterSpacing: -0.4, tabular: true),
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.job,
    required this.tripDistance,
    required this.busy,
    required this.acceptScale,
    required this.onAccept,
  });

  final MockJob job;
  final String tripDistance;
  final bool busy;
  final Animation<double> acceptScale;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final initial = job.customerName.trim().isEmpty ? 'R' : job.customerName.trim()[0].toUpperCase();
    final service = job.jobType.trim().isEmpty ? 'Ride' : job.jobType;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.successLight,
          child: Text(
            initial,
            style: _offerStyle(size: 16, weight: FontWeight.w700, color: AppColors.success),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      formatMoney(job.payout),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _offerStyle(
                        size: 22,
                        weight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.6,
                        height: 1.1,
                        tabular: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          service,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _offerStyle(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.directions_car_filled, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      tripDistance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _offerStyle(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        tabular: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    job.eta,
                    style: _offerStyle(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      tabular: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ScaleTransition(
          scale: acceptScale,
          child: Material(
            color: busy ? AppColors.primaryDark : AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: onAccept,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Accept',
                      style: _offerStyle(size: 14, weight: FontWeight.w700, color: AppColors.navy, letterSpacing: -0.2),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.navy),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({required this.job, required this.gpsActive});

  final MockJob job;
  final bool gpsActive;

  @override
  Widget build(BuildContext context) {
    final pickup = job.address.trim().isEmpty ? 'Pickup location' : job.address.trim();
    final dropoff = (job.dropoffAddress ?? '').trim();

    return Column(
      children: [
        _StopRow(
          marker: const _PickupMark(),
          title: 'Pickup',
          badge: gpsActive ? AppLocalizations.of(context).gpsActive : null,
          address: pickup,
          showRail: dropoff.isNotEmpty,
        ),
        if (dropoff.isNotEmpty)
          _StopRow(
            marker: const _DropoffMark(),
            title: 'Drop off',
            address: dropoff,
            showRail: false,
          ),
      ],
    );
  }
}

class _PickupMark extends StatelessWidget {
  const _PickupMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
      child: SizedBox(width: 8, height: 8),
    );
  }
}

class _DropoffMark extends StatelessWidget {
  const _DropoffMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(1)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.error, width: 1.5)),
      ),
      child: SizedBox(width: 8, height: 8),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.marker,
    required this.title,
    required this.address,
    required this.showRail,
    this.badge,
  });

  final Widget marker;
  final String title;
  final String address;
  final bool showRail;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                const SizedBox(height: 4),
                marker,
                if (showRail)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showRail ? 12 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: _offerStyle(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      if (badge != null) ...[
                        Text(
                          '  ·  ',
                          style: _offerStyle(size: 12, weight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                        Text(
                          badge!,
                          style: _offerStyle(size: 12, weight: FontWeight.w600, color: AppColors.success),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _offerStyle(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.25,
                      letterSpacing: -0.2,
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

class _FooterActions extends StatelessWidget {
  const _FooterActions({required this.onReject, this.onCounter});

  final VoidCallback onReject;
  final VoidCallback? onCounter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: onReject,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            AppLocalizations.of(context).decline,
            style: _offerStyle(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
        const Spacer(),
        if (onCounter != null)
          TextButton(
            onPressed: onCounter,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              'Counter offer',
              style: _offerStyle(size: 13, weight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

TextStyle _offerStyle({
  required double size,
  required FontWeight weight,
  required Color color,
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
