import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/customer_location_actions.dart';
import '../widgets/ride_trip_map.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ArrivedPage extends ConsumerStatefulWidget {
  const ArrivedPage({super.key});

  @override
  ConsumerState<ArrivedPage> createState() => _ArrivedPageState();
}

class _ArrivedPageState extends ConsumerState<ArrivedPage> {
  Timer? _pollTimer;
  bool _confirming = false;
  bool _openedService = false;
  bool _uploadingPhoto = false;
  String? _pickupPhotoUrl;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _leaveCancelled() {
    ref.read(activeJobProvider.notifier).state = null;
    ref.read(providerSocketProvider).setActiveJob(null);
    context.go('/home');
  }

  Future<void> _refresh() async {
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
      if (job.status == JobStatusEntity.inProgress || job.startedAt != null) {
        _openService();
      }
    } catch (_) {}
  }

  void _openService() {
    if (_openedService || !mounted) return;
    _openedService = true;
    _pollTimer?.cancel();
    context.go('/in-progress');
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

  Future<void> _uploadPickupPhoto(String jobId) async {
    if (_uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploadingPhoto = false);
        return;
      }
      final fileUrl = await ref.read(fileUploadServiceProvider).uploadProviderFile(
            localPath: picked.path,
            folder: 'parcels',
          );
      final result = await ref.read(jobRepositoryProvider).uploadParcelPickup(jobId, fileUrl);
      if (!mounted) return;
      result.fold(
        (failure) {
          setState(() => _uploadingPhoto = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (_) => setState(() {
          _pickupPhotoUrl = fileUrl;
          _uploadingPhoto = false;
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _startTrip(String jobId) async {
    if (_confirming) return;
    final job = ref.read(activeJobProvider);
    if (job?.bookingMode == 'parcel' && (_pickupPhotoUrl == null || _pickupPhotoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload a pickup photo before starting')),
      );
      return;
    }
    setState(() => _confirming = true);
    final result = await ref.read(jobRepositoryProvider).updateJobStatus(jobId, JobStatusEntity.inProgress);
    if (!mounted) return;
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    final updated = await ref.read(jobRepositoryProvider).fetchActiveJob();
    if (!mounted) return;
    setState(() => _confirming = false);
    if (updated != null) {
      ref.read(activeJobProvider.notifier).state = mockJobFromEntity(updated);
    }
    _openService();
  }

  LatLng? _point(double? lat, double? lng) {
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
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
    final destination = pickup ?? driver ?? const LatLng(52.48, -1.89);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RideTripMap(
          driver: driver,
          destination: destination,
          pickup: pickup,
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
                        child: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      l10n.youVeArrived,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
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
                      job.customerName,
                      style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The rider is here. Start the trip when you leave for the dropoff.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    CustomerLocationActions(
                      address: job.address,
                      latitude: pickup?.latitude,
                      longitude: pickup?.longitude,
                      phone: job.customerPhone,
                    ),
                    if ((job.dropoffAddress ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        job.dropoffAddress!,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (job.bookingMode == 'parcel') ...[
                      Text(
                        'Upload a pickup photo of the parcel before starting.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _uploadingPhoto ? null : () => _uploadPickupPhoto(job.id),
                        icon: Icon(_pickupPhotoUrl == null ? Icons.camera_alt_outlined : Icons.check_circle_outline),
                        label: Text(
                          _uploadingPhoto
                              ? 'Uploading…'
                              : _pickupPhotoUrl == null
                                  ? 'Take pickup photo'
                                  : 'Photo uploaded',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    RyvoButton(
                      label: _confirming ? 'Starting…' : 'Start trip',
                      onPressed: _confirming ? null : () => _startTrip(job.id),
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
      ),
    );
  }
}
