import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/job/active_job_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class ProviderAssignedPage extends ConsumerStatefulWidget {
  const ProviderAssignedPage({super.key});

  @override
  ConsumerState<ProviderAssignedPage> createState() =>
      _ProviderAssignedPageState();
}

class _ProviderAssignedPageState extends ConsumerState<ProviderAssignedPage> {
  int _etaSeconds = 3 * 60; // 3 minutes
  Timer? _timer;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  String? _jobId;

  @override
  void initState() {
    super.initState();
    _jobId = ref.read(jobDraftProvider).activeJob?.id;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_etaSeconds > 0) setState(() => _etaSeconds--);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollJob());
    Future.microtask(_pollJob);
    _connectTracking();
  }

  Future<void> _connectTracking() async {
    if (_jobId == null) return;
    final socket = ref.read(trackingSocketProvider);
    await socket.connect();
    socket.subscribeJob(_jobId!);
    _statusSub = socket.onStatus.listen((data) {
      if (!mounted) return;
      final status = data['status'] as String?;
      if (status != null) _pollJob();
    });
  }

  Future<void> _pollJob() async {
    if (!mounted) return;
    final job = ref.read(jobDraftProvider).activeJob;
    if (job == null) return;
    try {
      final updated = await ref.read(jobRepositoryProvider).getJob(job.id);
      if (!mounted) return;
      ref.read(jobDraftProvider.notifier).state =
          ref.read(jobDraftProvider).copyWith(activeJob: updated);
      _handleStatus(updated.status);
    } catch (_) {}
  }

  void _handleStatus(String status) {
    if (!mounted) return;
    if (status == 'in_progress') {
      _pollTimer?.cancel();
      context.pushReplacement('/in-progress');
    } else if (status == 'searching') {
      _pollTimer?.cancel();
      context.go('/searching');
    } else if (status == 'no_provider_found') {
      _pollTimer?.cancel();
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: _jobId,
      );
      context.go('/no-providers');
    } else if (status.startsWith('cancelled')) {
      _pollTimer?.cancel();
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: _jobId,
      );
      context.go('/home');
    } else if (status == 'arrived' || status == 'provider_en_route') {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    _statusSub?.cancel();
    if (_jobId != null) {
      ref.read(trackingSocketProvider).unsubscribeJob(_jobId!);
    }
    super.dispose();
  }

  String get _etaDisplay {
    final m = _etaSeconds ~/ 60;
    final s = _etaSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _cancelJob() async {
    final jobId = _jobId ?? ref.read(jobDraftProvider).activeJob?.id;
    if (jobId == null) return;
    final reason = await promptJobCancelReason(context);
    if (reason == null || !mounted) return;
    try {
      await ref.read(jobRepositoryProvider).cancelJob(jobId, reason: reason);
      if (!mounted) return;
      markJobSessionFinished(
        ProviderScope.containerOf(context, listen: false),
        jobId: jobId,
      );
      context.go('/home');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  void _openChat(String? jobId) {
    if (jobId == null) return;
    context.push('/chat/$jobId');
  }

  void _callProvider(String? phone) {
    dialPhone(context, phone);
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDraftProvider).activeJob;
    final providerName = job?.provider?.fullName ?? AppLocalizations.of(context).yourProvider;
    final rating = job?.provider?.ratingAvg;
    final vehicle = job?.vehicle;
    final status = job?.status ?? AppLocalizations.of(context).matched;
    final hasArrived = status == 'arrived';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).providerAssigned,
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasArrived
                        ? [
                            AppColors.success.withOpacity(0.2),
                            AppColors.success.withOpacity(0.05)
                          ]
                        : [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary.withOpacity(0.05)
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasArrived
                        ? AppColors.success.withOpacity(0.3)
                        : AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    if (hasArrived) ...[
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).providerHasArrived,
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).yourProviderIsAtYourLocation,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ] else ...[
                      Text(AppLocalizations.of(context).arrivingIn,
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        _etaDisplay,
                        style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                      Text(
                        status == 'provider_en_route'
                            ? AppLocalizations.of(context).providerIsOnTheWay
                            : AppLocalizations.of(context).providerIsHeadingToYou,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Provider card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppColors.grey700,
                              child: Text(_initials(providerName),
                                  style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.surface, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(providerName,
                                  style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: AppColors.primary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(rating?.toStringAsFixed(1) ?? '—',
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(AppLocalizations.of(context).verified,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _ActionButton(
                                icon: Icons.phone,
                                color: AppColors.success,
                                onTap: () =>
                                    _callProvider(job?.provider?.phone)),
                            const SizedBox(width: 8),
                            _ActionButton(
                                icon: Icons.chat_bubble_outline,
                                color: AppColors.info,
                                onTap: () => _openChat(job?.id)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.divider),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _VehicleInfo(
                            icon: Icons.directions_car,
                            label: AppLocalizations.of(context).vehicle,
                            value: vehicle != null
                                ? '${vehicle.make} ${vehicle.model}'
                                : '—'),
                        const SizedBox(width: 16),
                        _VehicleInfo(
                            icon: Icons.badge_outlined,
                            label: AppLocalizations.of(context).plate,
                            value: vehicle?.plateNumber ?? '—'),
                        const SizedBox(width: 16),
                        _VehicleInfo(
                            icon: Icons.color_lens_outlined,
                            label: AppLocalizations.of(context).color,
                            value: vehicle?.color ?? '—'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.divider),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.of(context).backgroundCheckedCertified,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Map preview placeholder
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Center(
                    child: Icon(Icons.map_outlined,
                        color: AppColors.grey600, size: 48)),
              ),
              const SizedBox(height: 24),
              RyvoButton(
                label: AppLocalizations.of(context).trackOnMap,
                prefixIcon:
                    const Icon(Icons.gps_fixed, color: Colors.black, size: 20),
                onPressed: () => context.push('/live-tracking'),
              ),
              const SizedBox(height: 8),
              RyvoButton(
                label: AppLocalizations.of(context).cancelJob,
                variant: RyvoButtonVariant.ghost,
                onPressed: _cancelJob,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _VehicleInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _VehicleInfo(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.grey500, size: 18),
          const SizedBox(height: 4),
          Text(label,
              style:
                  GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
