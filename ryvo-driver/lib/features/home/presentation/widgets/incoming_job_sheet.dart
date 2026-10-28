import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/job_alert_sound.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

const _sheetBg = Color(0xFFFFFFFF);
const _textDark = Color(0xFF111827);
const _textMuted = Color(0xFF6B7280);
const _textLabel = Color(0xFF9CA3AF);
const _borderLight = Color(0xFFE5E7EB);
const _urgentRed = Color(0xFFEF4444);
const _urgentBg = Color(0xFFFEF2F2);
const _serviceBlue = Color(0xFF2563EB);
const _earnGreen = Color(0xFF10B981);
const _earnBg = Color(0xFFECFDF5);

/// Compact, polished incoming job panel — Accept/Reject always visible.
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
        applyActiveJobSession(ProviderScope.containerOf(context, listen: false), job);
        ref.read(dismissedIncomingOfferIdProvider.notifier).state = incoming.id;
        ref.read(showIncomingJobProvider.notifier).state = false;
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
    final progress = _seconds / _totalSeconds;
    final pad = R.w(context, 16).clamp(14.0, 18.0);
    final urgent = _seconds <= 5;
    final maxSheet = MediaQuery.sizeOf(context).height * 0.78;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheet),
          child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, -6)),
              BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, -1)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 10, pad, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HeaderRow(seconds: _seconds, progress: progress, urgent: urgent, isHighPriority: job.isHighPriority),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _earnBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 14, color: _earnGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Paid when the trip ends',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _earnGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ServiceCard(job: job),
                          const SizedBox(height: 8),
                          _VehicleCard(job: job),
                          const SizedBox(height: 8),
                          _CustomerCard(job: job),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionButtons(
                    onAccept: _accept,
                    onReject: _reject,
                    onCounter: incoming != null && incoming.isBidRequest
                        ? () async {
                            final bidJob = incoming;
                            final controller = TextEditingController(
                              text: (bidJob.offeredPrice ?? bidJob.payout).toStringAsFixed(2),
                            );
                            final amount = await showDialog<double>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Counter offer'),
                                content: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
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
                        : null,
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.seconds,
    required this.progress,
    required this.urgent,
    required this.isHighPriority,
  });

  final int seconds;
  final double progress;
  final bool urgent;
  final bool isHighPriority;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: urgent ? _urgentBg : const Color(0xFFF9FAFB),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3.5,
                backgroundColor: urgent ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(urgent ? _urgentRed : const Color(0xFFB9F36B)),
              ),
              Text(
                '$seconds',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: urgent ? _urgentRed : _textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).requestExpiresIn,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark),
              ),
              if (isHighPriority) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _Chip(label: AppLocalizations.of(context).highPRIORITY, icon: '🚨', color: _urgentRed, bg: _urgentBg),
                    _Chip(label: AppLocalizations.of(context).veryUrgent, icon: null, color: _urgentRed, bg: _urgentBg, showClock: true),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.bg,
    this.icon,
    this.showClock = false,
  });

  final String label;
  final String? icon;
  final Color color;
  final Color bg;
  final bool showClock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 11)), const SizedBox(width: 3)],
          if (showClock) ...[Icon(Icons.access_time_filled, size: 11, color: color), const SizedBox(width: 3)],
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.job});

  final MockJob job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x143B82F6), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: const Icon(Icons.directions_car_filled, color: _serviceBlue, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIDE',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _textLabel,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  job.jobType,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _serviceBlue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  job.serviceDescription,
                  style: GoogleFonts.poppins(fontSize: 10, color: _textMuted, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _earnBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context).earn,
                  style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: _earnGreen, letterSpacing: 0.5),
                ),
                Text(
                  formatMoney(job.payout),
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: _earnGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.job});

  final MockJob job;

  @override
  Widget build(BuildContext context) {
    final pickup = job.address.trim().isEmpty ? 'Pickup' : job.address;
    final dropoff = (job.dropoffAddress ?? '').trim();
    final distance = job.tripDistance.trim();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.route, color: _textDark, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRIP',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _textLabel,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pickup,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dropoff.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dropoff,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (distance.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    distance,
                    style: GoogleFonts.poppins(fontSize: 11, color: _textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.job});

  final MockJob job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _borderLight, width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE5E7EB),
              child: Text(
                job.customerName[0],
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        job.customerName,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
                          Text(
                            '${job.rating}',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).callCustomer,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => dialPhone(context, job.customerPhone),
                      icon: const Icon(Icons.phone, size: 18, color: _earnGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.location_on_outlined, size: 13, color: _textMuted),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.address,
                        style: GoogleFonts.poppins(fontSize: 11, color: _textMuted, height: 1.25),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InfoPill(icon: Icons.route, label: job.distance),
                    const SizedBox(width: 6),
                    _InfoPill(icon: Icons.schedule, label: job.eta),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _textMuted),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onAccept, required this.onReject, this.onCounter});

  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onCounter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x4010B981), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).acceptJob, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
        if (onCounter != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCounter,
              child: Text('Counter offer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMuted,
              backgroundColor: _sheetBg,
              side: const BorderSide(color: _borderLight),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).decline, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
