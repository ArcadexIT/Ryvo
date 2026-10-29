import 'dart:async';
import 'package:flutter/material.dart';
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

const _card = Color(0xF21A2333);
const _text = Color(0xFFF8FAFC);
const _muted = Color(0xFF94A3B8);
const _urgentRed = Color(0xFFEF4444);
const _pickup = Color(0xFF22C55E);
const _dropoff = Color(0xFFEF4444);

/// Floating ride-offer card shown over the home map.
class IncomingJobSheet extends ConsumerStatefulWidget {
  const IncomingJobSheet({super.key});

  @override
  ConsumerState<IncomingJobSheet> createState() => _IncomingJobSheetState();
}

class _IncomingJobSheetState extends ConsumerState<IncomingJobSheet> with SingleTickerProviderStateMixin {
  /// Used only when the offer has no server expiry. Matches the API default.
  static const _fallbackSeconds = 30;

  int _totalSeconds = _fallbackSeconds;
  int _seconds = _fallbackSeconds;
  String? _offerId;
  bool _expired = false;
  Timer? _timer;
  late AnimationController _enterCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();

    _arm(ref.read(jobNotifierProvider).value?.incomingJob, notify: false);
  }

  int _secondsLeft(JobEntity? job) {
    final expiresAt = job?.expiresAt;
    if (expiresAt == null) return _fallbackSeconds;
    final left = expiresAt.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  void _arm(JobEntity? job, {bool notify = true}) {
    if (job == null || job.id.isEmpty) return;
    if (job.id == _offerId && _timer != null) return;
    _offerId = job.id;
    _expired = false;
    final left = _secondsLeft(job);
    _totalSeconds = left > 0 ? left : 1;
    _seconds = left;
    _timer?.cancel();
    if (notify && mounted) setState(() {});
    if (left <= 0) {
      _expire();
      return;
    }
    JobAlertSound.playIncomingJob();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) {
        t.cancel();
        _expire();
      }
    });
  }

  void _expire() {
    if (_expired) return;
    _expired = true;
    _timer?.cancel();
    JobAlertSound.stop();
    final id = _offerId ?? ref.read(jobNotifierProvider).value?.incomingJob?.id;
    if (id != null && id.isNotEmpty) {
      ref.read(dismissedIncomingOfferIdProvider.notifier).state = id;
    }
    ref.read(showIncomingJobProvider.notifier).state = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enterCtrl.dispose();
    JobAlertSound.stop();
    super.dispose();
  }

  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    final incoming = ref.read(jobNotifierProvider).value?.incomingJob;
    if (incoming == null) {
      _reject();
      return;
    }
    setState(() => _busy = true);
    JobAlertSound.stop();
    final onTrip = ref.read(activeJobProvider)?.status == JobStatusEntity.inProgress;
    final result = await ref.read(jobRepositoryProvider).acceptJob(incoming.id);
    if (!mounted) return;
    result.fold(
      (f) {
        setState(() => _busy = false);
        if (incoming.isBidRequest) {
          ref.read(dismissedIncomingOfferIdProvider.notifier).state = incoming.id;
          ref.read(showIncomingJobProvider.notifier).state = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(f.message.contains('Waiting') ? 'Offer sent to the rider' : f.message)),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(f.message), backgroundColor: Colors.red.shade700),
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
    final progress = (_seconds / _totalSeconds).clamp(0.0, 1.0);
    final urgent = _seconds <= 5;
    final gpsActive = liveLoc != null;
    final tripDistance = job.tripDistance.trim().isEmpty ? job.distance : job.tripDistance;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  color: urgent ? _urgentRed : _pickup,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TitleRow(
                        seconds: _seconds,
                        urgent: urgent,
                        isHighPriority: job.isHighPriority,
                        chainedNote: incoming?.chained == true
                            ? 'After this dropoff · about ${job.eta} until the next pickup'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _FareRow(
                        job: job,
                        tripDistance: tripDistance,
                        busy: _busy,
                        onAccept: _busy ? null : _accept,
                      ),
                      const SizedBox(height: 14),
                      _RouteBlock(job: job, gpsActive: gpsActive),
                      _FooterActions(
                        onReject: _reject,
                        onCounter: incoming != null && incoming.isBidRequest
                            ? () => _counter(incoming)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: _text),
              ),
            ),
            if (isHighPriority)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _urgentRed.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppLocalizations.of(context).highPRIORITY,
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: _urgentRed),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (urgent ? _urgentRed : Colors.white).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${seconds}s',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: urgent ? _urgentRed : _text,
                ),
              ),
            ),
          ],
        ),
        if (chainedNote != null) ...[
          const SizedBox(height: 6),
          Text(
            chainedNote!,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
          ),
        ],
      ],
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.job,
    required this.tripDistance,
    required this.busy,
    required this.onAccept,
  });

  final MockJob job;
  final String tripDistance;
  final bool busy;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final initial = job.customerName.trim().isEmpty ? 'R' : job.customerName.trim()[0].toUpperCase();
    final service = job.jobType.trim().isEmpty ? 'Ride' : job.jobType;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary.withValues(alpha: 0.18),
          child: Text(
            initial,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
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
                    fit: FlexFit.loose,
                    child: Text(
                      formatMoney(job.payout),
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: _text, height: 1.1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        service,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.directions_car_filled, size: 14, color: _muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      tripDistance,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: _muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.schedule, size: 14, color: _muted),
                  const SizedBox(width: 4),
                  Text(
                    job.eta,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: _muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onAccept,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Accept',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.navy),
                      ],
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
          color: _pickup,
          title: 'Pickup',
          badge: gpsActive ? AppLocalizations.of(context).gpsActive : null,
          address: pickup,
          showRail: dropoff.isNotEmpty,
        ),
        if (dropoff.isNotEmpty)
          _StopRow(
            color: _dropoff,
            title: 'Drop off',
            address: dropoff,
            showRail: false,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.color,
    required this.title,
    required this.address,
    required this.showRail,
    this.badge,
  });

  final Color color;
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
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)],
                  ),
                ),
                if (showRail)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showRail ? 10 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                      ),
                      if (badge != null) ...[
                        Text('  ·  ', style: GoogleFonts.poppins(fontSize: 12, color: _muted)),
                        Text(
                          badge!,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _pickup),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _text, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
            foregroundColor: _muted,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            AppLocalizations.of(context).decline,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
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
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
