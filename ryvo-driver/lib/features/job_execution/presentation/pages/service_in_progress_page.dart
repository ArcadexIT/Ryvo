import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/job_elapsed.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/providers/notifiers/job_notifier.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../home/presentation/widgets/incoming_job_sheet.dart';
import '../widgets/customer_location_actions.dart';
import '../widgets/ride_trip_map.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ServiceInProgressPage extends ConsumerStatefulWidget {
  const ServiceInProgressPage({super.key});

  @override
  ConsumerState<ServiceInProgressPage> createState() => _ServiceInProgressPageState();
}

class _ServiceInProgressPageState extends ConsumerState<ServiceInProgressPage> {
  Timer? _pollTimer;
  int? _routeMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(tripScreenCoveringHomeProvider.notifier).state = true;
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshActiveJob());
    Future.microtask(_refreshActiveJob);
  }

  void _leaveCancelled() {
    ref.read(activeJobProvider.notifier).state = null;
    ref.read(providerSocketProvider).setActiveJob(null);
    context.go('/home');
  }

  Future<void> _refreshActiveJob() async {
    try {
      final job = await ref.read(jobRepositoryProvider).fetchActiveJob();
      if (!mounted) return;
      if (job == null) {
        final currentId = ref.read(activeJobProvider)?.id;
        if (currentId == null) return;
        final detail = await ref.read(jobRepositoryProvider).fetchJobDetail(currentId);
        if (!mounted) return;
        if (detail == null ||
            detail.status == JobStatusEntity.cancelled ||
            detail.status == JobStatusEntity.incoming) {
          _leaveCancelled();
        }
        return;
      }
      if (job.status == JobStatusEntity.cancelled) {
        _leaveCancelled();
        return;
      }
      ref.read(activeJobProvider.notifier).state = mockJobFromEntity(job);
    } catch (_) {}
  }

  Future<void> _cancelJob(String jobId) async {
    final reason = await promptJobCancelReason(context);
    if (reason == null || !mounted) return;
    final result = await ref.read(jobRepositoryProvider).cancelJob(jobId, reason: reason);
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (_) {
        ref.read(activeJobProvider.notifier).state = null;
        ref.read(providerSocketProvider).setActiveJob(null);
        context.go('/home');
      },
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    final covering = ref.read(tripScreenCoveringHomeProvider.notifier);
    super.dispose();
    Future(() => covering.state = false);
  }

  LatLng? _point(double? lat, double? lng) {
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  Future<void> _endTrip(MockJob job) async {
    if (job.bookingMode == 'parcel') {
      String? dropoffPhotoUrl;
      try {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1600,
        );
        if (picked == null) return;
        dropoffPhotoUrl = await ref.read(fileUploadServiceProvider).uploadProviderFile(
              localPath: picked.path,
              folder: 'parcels',
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
      if (!mounted) return;
      final otpCtrl = TextEditingController();
      final otp = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recipient OTP'),
          content: TextField(
            controller: otpCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '4-digit code from the recipient'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, otpCtrl.text.trim()), child: const Text('Confirm')),
          ],
        ),
      );
      if (otp == null || otp.isEmpty) return;
      final delivered = await ref.read(jobRepositoryProvider).deliverParcel(
            job.id,
            otp: otp,
            fileUrl: dropoffPhotoUrl,
          );
      final fail = delivered.fold((f) => f.message, (_) => null);
      if (fail != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fail)));
        return;
      }
    }
    await ref.read(jobRepositoryProvider).updateJobStatus(job.id, JobStatusEntity.completed);
    ref.read(providerSocketProvider).setActiveJob(null);
    final detail = await ref.read(jobRepositoryProvider).fetchJobDetail(job.id);
    if (detail != null) {
      ref.read(activeJobProvider.notifier).state = mockJobFromEntity(detail);
    }
    if (mounted) context.push('/job-completed?jobId=${job.id}');
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(activeJobProvider);
    if (job == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final loc = ref.watch(locationStreamProvider).valueOrNull;
    final driver = loc == null ? null : LatLng(loc.latitude, loc.longitude);
    final pickup = _point(job.customerLat, job.customerLng);
    final dropoff = _point(job.dropoffLat, job.dropoffLng);
    final destination = dropoff ?? driver ?? pickup ?? const LatLng(52.48, -1.89);
    final dropoffLabel = (job.dropoffAddress ?? '').trim().isEmpty ? 'Dropoff' : job.dropoffAddress!.trim();
    final l10n = AppLocalizations.of(context);
    final showNextOffer = ref.watch(showIncomingJobProvider);
    final nextPickup = (job.nextPickupAddress ?? '').trim();

    ref.listen<AsyncValue<JobUiState>>(jobNotifierProvider, (prev, next) {
      final incoming = next.value?.incomingJob;
      final dismissed = ref.read(dismissedIncomingOfferIdProvider);
      final show = incomingOfferIsOpen(incoming, dismissed);
      if (ref.read(showIncomingJobProvider) != show) {
        ref.read(showIncomingJobProvider.notifier).state = show;
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            RideTripMap(
          driver: driver,
          destination: destination,
          dropoff: dropoff,
          onRoute: (route) {
            if (!mounted) return;
            if (_routeMinutes == route.durationMin) return;
            setState(() => _routeMinutes = route.durationMin);
          },
          top: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.go('/home'),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.close, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _EtaPill(minutes: _routeMinutes, startedAt: job.startedAt),
                  const SizedBox(width: 8),
                  JobChatButton(jobId: job.id),
                ],
              ),
            ),
          ),
          sheet: Material(
            color: AppColors.modal,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Text(
                      'Heading to dropoff',
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (nextPickup.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Next trip after this dropoff · $nextPickup',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                    Text(
                      job.customerName,
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    CustomerLocationActions(
                      address: dropoffLabel,
                      latitude: dropoff?.latitude ?? job.dropoffLat,
                      longitude: dropoff?.longitude ?? job.dropoffLng,
                      phone: job.customerPhone,
                    ),
                    const SizedBox(height: 16),
                    RyvoButton(
                      label: 'End trip',
                      onPressed: () => _endTrip(job),
                    ),
                    RyvoButton(
                      label: l10n.cancelJob,
                      variant: RyvoButtonVariant.ghost,
                      onPressed: () => _cancelJob(job.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ),
            if (showNextOffer)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IncomingJobSheet(),
              ),
          ],
        ),
      ),
    );
  }
}

class _EtaPill extends StatelessWidget {
  const _EtaPill({required this.minutes, required this.startedAt});

  final int? minutes;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final label = minutes != null
        ? '$minutes min'
        : formatElapsedClock(serviceElapsedDuration(startedAt: startedAt));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}
