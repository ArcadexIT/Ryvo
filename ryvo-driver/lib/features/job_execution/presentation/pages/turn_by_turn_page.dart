import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/customer_location_actions.dart';
import '../widgets/ride_trip_map.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class TurnByTurnPage extends ConsumerStatefulWidget {
  const TurnByTurnPage({super.key});

  @override
  ConsumerState<TurnByTurnPage> createState() => _TurnByTurnPageState();
}

class _TurnByTurnPageState extends ConsumerState<TurnByTurnPage> {
  Timer? _pollTimer;
  int? _routeMinutes;
  double? _routeKm;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshActive());
    WidgetsBinding.instance.addPostFrameCallback((_) => _markEnRoute());
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

  Future<void> _refreshActive() async {
    try {
      final job = await ref.read(jobRepositoryProvider).fetchActiveJob();
      if (!mounted) return;
      if (job != null) {
        if (job.status == JobStatusEntity.cancelled || job.status == JobStatusEntity.incoming) {
          _leaveCancelled();
        }
        return;
      }
      final currentId = ref.read(activeJobProvider)?.id;
      if (currentId == null) return;
      final detail = await ref.read(jobRepositoryProvider).fetchJobDetail(currentId);
      if (!mounted) return;
      if (detail == null ||
          detail.status == JobStatusEntity.cancelled ||
          detail.status == JobStatusEntity.incoming) {
        _leaveCancelled();
      }
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

  void _markEnRoute() {
    final job = ref.read(activeJobProvider);
    if (job != null && job.status != JobStatusEntity.paymentPending) {
      ref.read(jobRepositoryProvider).updateJobStatus(job.id, JobStatusEntity.navigating);
    }
  }

  Future<void> _markArrived() async {
    final job = ref.read(activeJobProvider);
    if (job != null) {
      await ref.read(jobRepositoryProvider).updateJobStatus(job.id, JobStatusEntity.arrived);
    }
    if (mounted) context.push('/arrived');
  }

  LatLng? _driverPos() {
    final loc = ref.watch(locationStreamProvider).valueOrNull;
    if (loc == null) return null;
    return LatLng(loc.latitude, loc.longitude);
  }

  LatLng? _pickup(MockJob job) {
    final lat = job.customerLat;
    final lng = job.customerLng;
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  Widget _sheet(MockJob job, LatLng? pickup) {
    final l10n = AppLocalizations.of(context);
    final eta = _routeMinutes == null ? null : '$_routeMinutes min';
    final distance = _routeKm == null ? null : '${_routeKm!.toStringAsFixed(1)} km';
    return Material(
      color: AppColors.modal,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
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
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Navigating to ${job.customerName}',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (job.jobType.trim().isNotEmpty)
                          Text(
                            job.jobType,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (eta != null || distance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        [if (eta != null) eta, if (distance != null) distance].join(' · '),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              CustomerLocationActions(
                address: job.address,
                latitude: pickup?.latitude ?? job.customerLat,
                longitude: pickup?.longitude ?? job.customerLng,
                phone: job.customerPhone,
              ),
              const SizedBox(height: 16),
              RyvoButton(
                label: l10n.iVeArrived,
                height: 50,
                onPressed: _markArrived,
              ),
              RyvoButton(
                label: l10n.cancelJob,
                variant: RyvoButtonVariant.ghost,
                height: 40,
                onPressed: () => _cancelJob(job.id),
              ),
            ],
          ),
        ),
      ),
    );
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
    final driver = _driverPos();
    final pickup = _pickup(job);
    final destination = pickup ?? driver ?? const LatLng(52.48, -1.89);

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
          onRoute: (DrivingRoute route) {
            if (!mounted) return;
            if (_routeMinutes == route.durationMin && _routeKm == route.distanceKm) return;
            setState(() {
              _routeMinutes = route.durationMin;
              _routeKm = route.distanceKm;
            });
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
                        child: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const Spacer(),
                  JobChatButton(jobId: job.id),
                ],
              ),
            ),
          ),
          sheet: _sheet(job, pickup),
        ),
      ),
    );
  }
}
