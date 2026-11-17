import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/location/location_disclosure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_navigation.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/arrived_sheet.dart';
import '../widgets/ride_trip_map.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ArrivedPage extends ConsumerStatefulWidget {
  const ArrivedPage({super.key});

  @override
  ConsumerState<ArrivedPage> createState() => _ArrivedPageState();
}

class _ArrivedPageState extends ConsumerState<ArrivedPage> {
  Timer? _pollTimer;
  bool _openedService = false;
  final ValueNotifier<bool> _confirming = ValueNotifier(false);
  final ValueNotifier<bool> _uploadingPhoto = ValueNotifier(false);
  final ValueNotifier<String?> _pickupPhotoUrl = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      promptDriverLocationDisclosure(context, ref);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _confirming.dispose();
    _uploadingPhoto.dispose();
    _pickupPhotoUrl.dispose();
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
        final detail =
            await ref.read(jobRepositoryProvider).fetchJobDetail(currentId);
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
    final result =
        await ref.read(jobRepositoryProvider).cancelJob(jobId, reason: reason);
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
    if (_uploadingPhoto.value) return;
    _uploadingPhoto.value = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (picked == null) {
        _uploadingPhoto.value = false;
        return;
      }
      final fileUrl =
          await ref.read(fileUploadServiceProvider).uploadProviderFile(
                localPath: picked.path,
                folder: 'parcels',
              );
      if (!mounted) return;
      final result = await ref
          .read(jobRepositoryProvider)
          .uploadParcelPickup(jobId, fileUrl);
      if (!mounted) return;
      result.fold(
        (failure) {
          _uploadingPhoto.value = false;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        },
        (_) {
          _pickupPhotoUrl.value = fileUrl;
          _uploadingPhoto.value = false;
        },
      );
    } catch (e) {
      if (!mounted) return;
      _uploadingPhoto.value = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<bool> _startTrip(String jobId) async {
    if (_confirming.value) return false;
    final job = ref.read(activeJobProvider);
    if (job?.bookingMode == 'parcel' &&
        (_pickupPhotoUrl.value == null || _pickupPhotoUrl.value!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Upload a pickup photo before starting')),
        );
      }
      return false;
    }
    _confirming.value = true;
    try {
      final result = await ref
          .read(jobRepositoryProvider)
          .updateJobStatus(jobId, JobStatusEntity.inProgress);
      if (!mounted) return false;
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        _confirming.value = false;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
        return false;
      }
      final updated = await ref.read(jobRepositoryProvider).fetchActiveJob();
      if (!mounted) return false;
      if (updated != null) {
        ref.read(activeJobProvider.notifier).state = mockJobFromEntity(updated);
      }
      _openService();
      return true;
    } catch (e) {
      if (mounted) {
        _confirming.value = false;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
  }

  Future<void> _navigate() async {
    final job = ref.read(activeJobProvider);
    if (job == null || !mounted) return;
    final dropoff = (job.dropoffAddress ?? '').trim();
    final hasDropoff = dropoff.isNotEmpty ||
        MapsNavigation.hasCoordinates(job.dropoffLat, job.dropoffLng);
    final opened = await MapsNavigation.openGoogleMaps(
      address:
          hasDropoff ? (dropoff.isNotEmpty ? dropoff : 'Dropoff') : job.address,
      latitude: hasDropoff ? job.dropoffLat : job.customerLat,
      longitude: hasDropoff ? job.dropoffLng : job.customerLng,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotOpenGoogleMaps),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(activeJobProvider);
    if (job == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final dropoff = (job.dropoffAddress ?? '').trim();
    final hasDropoff = dropoff.isNotEmpty ||
        MapsNavigation.hasCoordinates(job.dropoffLat, job.dropoffLng);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _ArrivedMap(
          pickupLat: job.customerLat,
          pickupLng: job.customerLng,
          top: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _MapBackButton(onTap: () => context.go('/home')),
              ),
            ),
          ),
          sheet: ArrivedSheet(
            riderName: job.customerName,
            rating: job.rating,
            pickup: job.address,
            dropoff: dropoff,
            isParcel: job.bookingMode == 'parcel',
            navigateLabel:
                hasDropoff ? 'Navigate to Dropoff' : 'Navigate to Pickup',
            confirming: _confirming,
            uploadingPhoto: _uploadingPhoto,
            pickupPhotoUrl: _pickupPhotoUrl,
            onCall: () => dialPhone(context, job.customerPhone),
            onMessage: () => openJobChat(context, ref, jobId: job.id),
            onNavigate: _navigate,
            onStart: () => _startTrip(job.id),
            onCancel: () => _cancelJob(job.id),
            onUploadPhoto: () => _uploadPickupPhoto(job.id),
          ),
        ),
      ),
    );
  }
}

/// Map canvas isolated from the sheet. GPS ticks rebuild this widget only.
class _ArrivedMap extends ConsumerWidget {
  const _ArrivedMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.top,
    required this.sheet,
  });

  final double? pickupLat;
  final double? pickupLng;
  final Widget top;
  final Widget sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locationStreamProvider).valueOrNull;
    final driver = loc == null ? null : LatLng(loc.latitude, loc.longitude);
    final pickup = _mapPoint(pickupLat, pickupLng);
    final destination = pickup ?? driver ?? const LatLng(52.48, -1.89);

    return RideTripMap(
      driver: driver,
      destination: destination,
      pickup: pickup,
      top: top,
      sheet: sheet,
    );
  }
}

class _MapBackButton extends StatelessWidget {
  const _MapBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.divider)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

LatLng? _mapPoint(double? lat, double? lng) {
  if (lat == null || lng == null || lat == 0 || lng == 0) return null;
  return LatLng(lat, lng);
}
