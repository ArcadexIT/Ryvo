import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import 'ryvo_spatial_drawer.dart';

/// Carbon sidebar that sits behind the scaled map. Layout follows the
/// ChatGPT drawer: icon row, outlined links, text history, pinned action.
class RyvoSpatialMenu extends StatelessWidget {
  const RyvoSpatialMenu({
    super.key,
    required this.onSearch,
    required this.onNewRide,
    required this.onRecentRide,
  });

  final Future<void> Function() onSearch;
  final Future<void> Function() onNewRide;
  final Future<void> Function(String address, double lat, double lng)
      onRecentRide;

  Future<void> _leave(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    await RyvoSpatialDrawerController.maybeOf(context)?.close();
    if (!context.mounted) return;
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = GoRouterState.of(context).uri.path;
    final panelWidth = MediaQuery.sizeOf(context).width * 0.56;

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: panelWidth,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MenuHeader(
                  onProfile: () => _leave(context, () async {
                    if (context.mounted) context.go('/profile');
                  }),
                  onSearch: () => _leave(context, onSearch),
                ),
                const SizedBox(height: 16),
                _NavRow(
                  icon: Icons.home_outlined,
                  label: l10n.home,
                  selected: path == '/home',
                  onTap: () =>
                      RyvoSpatialDrawerController.maybeOf(context)?.close(),
                ),
                _NavRow(
                  icon: Icons.calendar_today_outlined,
                  label: l10n.bookings,
                  selected: path == '/bookings',
                  onTap: () => _leave(context, () async {
                    if (context.mounted) context.go('/bookings');
                  }),
                ),
                _NavRow(
                  icon: Icons.directions_car_outlined,
                  label: l10n.myVehicle,
                  onTap: () => _leave(context, () async {
                    if (context.mounted) context.push('/add-vehicle');
                  }),
                ),
                _NavRow(
                  icon: Icons.notifications_outlined,
                  label: l10n.notifications,
                  onTap: () => _leave(context, () async {
                    if (context.mounted) context.push('/notifications');
                  }),
                ),
                _NavRow(
                  icon: Icons.person_outline_rounded,
                  label: l10n.profile,
                  selected: path == '/profile',
                  onTap: () => _leave(context, () async {
                    if (context.mounted) context.go('/profile');
                  }),
                ),
                const SizedBox(height: 8),
                ColoredBox(
                  color: AppColors.divider,
                  child: const SizedBox(height: 1, width: double.infinity),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _RecentRides(
                    onSavedPlaces: () => _leave(context, onSearch),
                    onRecentRide: (address, lat, lng) => _leave(
                      context,
                      () => onRecentRide(address, lat, lng),
                    ),
                    onOpenBookings: () => _leave(context, () async {
                      if (context.mounted) context.go('/bookings');
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                _BottomRow(
                  onNewRide: () => _leave(context, onNewRide),
                  onSettings: () => _leave(context, () async {
                    if (context.mounted) context.go('/profile');
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RideMemory {
  const _RideMemory({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String title;
  final String address;
  final double lat;
  final double lng;
}

List<_RideMemory> _recentRides(List<JobModel> jobs) {
  final ordered = [...jobs]..sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  final seen = <String>{};
  final rides = <_RideMemory>[];
  for (final job in ordered) {
    final address = job.dropoffAddress?.trim() ?? '';
    final lat = job.dropoffLat;
    final lng = job.dropoffLng;
    if (address.isEmpty || lat == null || lng == null) continue;
    if (job.status == 'cancelled' || job.status.startsWith('cancelled')) {
      continue;
    }
    if (!seen.add(address.toLowerCase())) continue;
    final title = address.split(',').first.trim();
    rides.add(
      _RideMemory(
        title: title.isEmpty ? address : title,
        address: address,
        lat: lat,
        lng: lng,
      ),
    );
    if (rides.length == 8) break;
  }
  return rides;
}

class _MenuHeader extends ConsumerWidget {
  const _MenuHeader({required this.onProfile, required this.onSearch});

  final VoidCallback onProfile;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      profileProvider.select((async) => async.valueOrNull),
    );
    final name = profile?.fullName.trim() ?? '';
    final phone = profile?.phone.trim() ?? '';
    final label = name.isEmpty ? AppLocalizations.of(context).profile : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              _DrawerAvatar(
                initials: profile?.initials,
                avatarUrl: profile?.avatarUrl,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RyvoTypography.heading(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RyvoTypography.style(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _HeaderIcon(
              icon: Icons.search_rounded,
              label: 'Search',
              onTap: onSearch,
            ),
            const SizedBox(width: 8),
            _HeaderIcon(
              icon: Icons.close_rounded,
              label: 'Close',
              onTap: () =>
                  RyvoSpatialDrawerController.maybeOf(context)?.close(),
            ),
          ],
        ),
      ],
    );
  }
}

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({this.initials, this.avatarUrl});

  final String? initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final letter = (initials == null || initials!.isEmpty || initials == '?')
        ? null
        : initials;
    final fallback = ColoredBox(
      color: AppColors.obsidian,
      child: Center(
        child: letter == null
            ? const Icon(Icons.person_rounded, size: 18, color: AppColors.white)
            : Text(
                letter,
                style: RyvoTypography.heading(
                  fontSize: 13,
                  color: AppColors.white,
                  letterSpacing: -0.4,
                ),
              ),
      ),
    );
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _RecentRides extends ConsumerWidget {
  const _RecentRides({
    required this.onSavedPlaces,
    required this.onRecentRide,
    required this.onOpenBookings,
  });

  final VoidCallback onSavedPlaces;
  final Future<void> Function(String address, double lat, double lng)
      onRecentRide;
  final VoidCallback onOpenBookings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = _recentRides(
      ref.watch(jobsListProvider.select((async) => async.valueOrNull)) ??
          const <JobModel>[],
    );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _TextLink(label: 'Saved Places', onTap: onSavedPlaces),
        if (rides.isEmpty)
          _TextLink(label: 'Recent Rides', onTap: onOpenBookings)
        else
          for (final ride in rides)
            _TextLink(
              label: ride.title,
              onTap: () => onRecentRide(ride.address, ride.lat, ride.lng),
            ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: RyvoTypography.style(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.onNewRide, required this.onSettings});

  final VoidCallback onNewRide;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onNewRide,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cta,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'New Ride',
                style: RyvoTypography.style(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onCta,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Settings',
          child: GestureDetector(
            onTap: onSettings,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
