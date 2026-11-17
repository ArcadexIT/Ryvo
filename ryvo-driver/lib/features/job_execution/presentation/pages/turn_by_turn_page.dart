import 'dart:async';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/mock_data.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/location/driving_route.dart';
import '../../../../core/location/location_disclosure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_navigation.dart';
import '../../../../core/utils/phone_call.dart';
import '../../../../features/job/domain/entities/job_entity.dart';
import '../../../../features/location/domain/entities/location_entity.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/ride_trip_map.dart';
import '../widgets/swipe_to_confirm.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class _Leg {
  const _Leg(this.minutes, this.km);

  final int minutes;
  final double km;

  @override
  bool operator ==(Object other) => other is _Leg && other.minutes == minutes && other.km == km;

  @override
  int get hashCode => Object.hash(minutes, km);
}

/// En route to the rider. The map follows the driver; the sheet only rebuilds
/// when the road distance changes.
class TurnByTurnPage extends ConsumerStatefulWidget {
  const TurnByTurnPage({super.key});

  @override
  ConsumerState<TurnByTurnPage> createState() => _TurnByTurnPageState();
}

class _TurnByTurnPageState extends ConsumerState<TurnByTurnPage> {
  Timer? _pollTimer;
  final ValueNotifier<LatLng?> _driver = ValueNotifier(null);
  final ValueNotifier<_Leg?> _leg = ValueNotifier(null);
  bool _arriving = false;

  @override
  void initState() {
    super.initState();
    final loc = ref.read(locationStreamProvider).valueOrNull;
    if (loc != null) _driver.value = LatLng(loc.latitude, loc.longitude);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshActive());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      promptDriverLocationDisclosure(context, ref);
      _markEnRoute();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driver.dispose();
    _leg.dispose();
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

  /// Returns true only when the server accepted the `arrived` transition.
  /// A rejection keeps the driver on this page, shows the reason, and returns
  /// false so [SwipeToConfirm] springs the thumb back for a retry.
  Future<bool> _markArrived() async {
    if (_arriving) return false;
    final job = ref.read(activeJobProvider);
    if (job == null) return false;
    setState(() => _arriving = true);

    final Either<Failure, void> result;
    try {
      result = await ref.read(jobRepositoryProvider).updateJobStatus(job.id, JobStatusEntity.arrived);
    } catch (e) {
      if (mounted) {
        setState(() => _arriving = false);
        _showError(e.toString());
      }
      return false;
    }
    if (!mounted) return result.isRight();

    return result.fold(
      (failure) {
        setState(() => _arriving = false);
        _showError(failure.message);
        return false;
      },
      (_) {
        HapticFeedback.mediumImpact();
        context.push('/arrived').whenComplete(() {
          // Back on this page: re-arm the swipe (it resets when re-enabled).
          if (mounted) setState(() => _arriving = false);
        });
        return true;
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
  }

  void _onDriver(AsyncValue<LocationEntity>? _, AsyncValue<LocationEntity> next) {
    final loc = next.valueOrNull;
    if (loc == null) return;
    final pos = LatLng(loc.latitude, loc.longitude);
    final current = _driver.value;
    if (current != null &&
        (current.latitude - pos.latitude).abs() < 0.00003 &&
        (current.longitude - pos.longitude).abs() < 0.00003) {
      return;
    }
    _driver.value = pos;
  }

  LatLng? _pickup(MockJob job) {
    final lat = job.customerLat;
    final lng = job.customerLng;
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(locationStreamProvider, _onDriver);

    final job = ref.watch(activeJobProvider);
    if (job == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Align(
          alignment: Alignment.topCenter,
          child: LinearProgressIndicator(
            minHeight: 4,
            backgroundColor: AppColors.grey100,
            color: AppColors.primary,
          ),
        ),
      );
    }

    final pickup = _pickup(job);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ValueListenableBuilder<LatLng?>(
          valueListenable: _driver,
          builder: (context, driver, sheet) {
            return RideTripMap(
              driver: driver,
              destination: pickup ?? driver ?? const LatLng(52.48, -1.89),
              pickup: pickup,
              mapStyle: MockData.darkMapStyle,
              onRoute: (DrivingRoute route) {
                final next = _Leg(route.durationMin <= 0 ? 1 : route.durationMin, route.distanceKm);
                if (_leg.value == next) return;
                _leg.value = next;
              },
              top: const _TripTopBar(),
              sheet: sheet!,
            );
          },
          child: _EnRouteSheet(
            job: job,
            leg: _leg,
            arriving: _arriving,
            onArrived: _markArrived,
            onCancel: () => _cancelJob(job.id),
          ),
        ),
      ),
    );
  }
}

class _TripTopBar extends StatelessWidget {
  const _TripTopBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _CircleButton(
            icon: Icons.arrow_back,
            onTap: () => context.go('/home'),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
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
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _EnRouteSheet extends ConsumerWidget {
  const _EnRouteSheet({
    required this.job,
    required this.leg,
    required this.arriving,
    required this.onArrived,
    required this.onCancel,
  });

  final MockJob job;
  final ValueNotifier<_Leg?> leg;
  final bool arriving;
  final Future<bool> Function() onArrived;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<_Leg?>(
      valueListenable: leg,
      builder: (context, leg, _) {
        final l10n = AppLocalizations.of(context);
        final name = job.customerName.trim().isEmpty ? 'Rider' : job.customerName.trim();
        final initial = name[0].toUpperCase();
        final service = job.jobType.trim();
        final address = job.address.trim().isEmpty ? 'Pickup location' : job.address.trim();

        return Material(
          color: AppColors.modal,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(color: AppColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leg == null)
                  const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.grey100,
                    color: AppColors.primary,
                  )
                else
                  const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: _Handle()),
                      const SizedBox(height: 16),
                      _DistanceHeader(leg: leg),
                      const SizedBox(height: 16),
                      _RiderRow(initial: initial, name: name, service: service),
                      const SizedBox(height: 12),
                      _PickupRow(
                        address: address,
                        latitude: job.customerLat,
                        longitude: job.customerLng,
                      ),
                      const SizedBox(height: 16),
                      _ActionRow(
                        address: address,
                        latitude: job.customerLat,
                        longitude: job.customerLng,
                        phone: job.customerPhone,
                        onChat: () => openJobChat(context, ref, jobId: job.id),
                      ),
                      const SizedBox(height: 16),
                      SwipeToConfirm(
                        label: arriving ? 'ARRIVING…' : 'SWIPE TO ARRIVE',
                        enabled: !arriving,
                        busy: arriving,
                        onConfirmed: onArrived,
                      ),
                      TextButton(
                        onPressed: arriving ? null : onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          l10n.cancelJob,
                          style: _type(size: 14, weight: FontWeight.w600, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.grey300,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      child: SizedBox(width: 36, height: 4),
    );
  }
}

class _DistanceHeader extends StatelessWidget {
  const _DistanceHeader({required this.leg});

  final _Leg? leg;

  @override
  Widget build(BuildContext context) {
    final minutes = leg == null ? '—' : '${leg!.minutes}';
    final distance = leg == null ? '—' : _formatDistance(leg!.km);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          minutes,
          style: _type(size: 40, weight: FontWeight.w700, letterSpacing: -0.8, height: 1, tabular: true),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'min',
            style: _type(size: 16, weight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              distance,
              style: _type(size: 18, weight: FontWeight.w700, letterSpacing: -0.4, tabular: true),
            ),
            const SizedBox(height: 2),
            Text(
              'to pickup',
              style: _type(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.initial, required this.name, required this.service});

  final String initial;
  final String name;
  final String service;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.grey100,
          child: Text(
            initial,
            style: _type(size: 16, weight: FontWeight.w700),
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
                style: _type(size: 16, weight: FontWeight.w700, letterSpacing: -0.3),
              ),
              if (service.isNotEmpty)
                Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickupRow extends StatelessWidget {
  const _PickupRow({required this.address, this.latitude, this.longitude});

  final String address;
  final double? latitude;
  final double? longitude;

  Future<void> _copy(BuildContext context) async {
    final text = MapsNavigation.copyText(address: address, latitude: latitude, longitude: longitude);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).addressCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: () => _copy(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                child: SizedBox(width: 8, height: 8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup',
                    style: _type(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _type(size: 15, weight: FontWeight.w600, height: 1.3, letterSpacing: -0.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.address,
    required this.onChat,
    this.latitude,
    this.longitude,
    this.phone,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final VoidCallback onChat;

  Future<void> _navigate(BuildContext context) async {
    final opened = await MapsNavigation.openGoogleMaps(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotOpenGoogleMaps),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _SheetAction(
            icon: Icons.navigation_rounded,
            label: 'Navigate',
            tooltip: l10n.openInGoogleMaps,
            onTap: () => _navigate(context),
          ),
        ),
        Expanded(
          child: _SheetAction(
            icon: Icons.phone_rounded,
            label: 'Call',
            tooltip: l10n.callCustomer,
            onTap: () => dialPhone(context, phone),
          ),
        ),
        Expanded(
          child: _SheetAction(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            tooltip: l10n.chatWithCustomer,
            onTap: onChat,
          ),
        ),
      ],
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: AppColors.grey100, shape: BoxShape.circle),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(icon, size: 22, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: _type(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
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
