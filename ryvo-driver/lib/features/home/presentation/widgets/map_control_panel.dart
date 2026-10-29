import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Floating map controls — current location, zoom, follow mode, fit route.
class MapControlPanel extends StatelessWidget {
  final VoidCallback onMyLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool followEnabled;
  final VoidCallback onToggleFollow;
  final bool locating;
  final VoidCallback? onFitRoute;
  final bool showFitRoute;

  const MapControlPanel({
    super.key,
    required this.onMyLocation,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.followEnabled,
    required this.onToggleFollow,
    this.locating = false,
    this.onFitRoute,
    this.showFitRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = R.w(context, 44).clamp(40.0, 48.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFitRoute && onFitRoute != null) ...[
          _MapControlButton(
            size: size,
            icon: Icons.route_outlined,
            tooltip: AppLocalizations.of(context).showFullRoute,
            onTap: onFitRoute!,
          ),
          const SizedBox(height: 8),
        ],
        _MapControlButton(
          size: size,
          icon: Icons.add,
          tooltip: AppLocalizations.of(context).zoomIn,
          onTap: onZoomIn,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          size: size,
          icon: Icons.remove,
          tooltip: AppLocalizations.of(context).zoomOut,
          onTap: onZoomOut,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          size: size,
          icon: followEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
          tooltip: followEnabled ? AppLocalizations.of(context).followingYourLocation : AppLocalizations.of(context).followMyLocation,
          active: followEnabled,
          onTap: onToggleFollow,
        ),
        const SizedBox(height: 8),
        _MapControlButton(
          size: size,
          icon: locating ? Icons.hourglass_top : Icons.my_location,
          tooltip: AppLocalizations.of(context).goToCurrentLocation,
          active: locating,
          onTap: locating ? null : onMyLocation,
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  const _MapControlButton({
    required this.size,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : const Color(0xE6141C2B),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: R.sp(context, 20),
            color: active ? AppColors.navy : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Compact GPS status chip for the map overlay.
class MapLocationStatusChip extends StatelessWidget {
  final bool hasFix;
  final bool isLoading;
  final bool hasError;
  final String? areaLabel;

  const MapLocationStatusChip({
    super.key,
    required this.hasFix,
    this.isLoading = false,
    this.hasError = false,
    this.areaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = hasError
        ? (Icons.location_off_outlined, 'Location unavailable', AppColors.error)
        : isLoading
            ? (Icons.location_searching, 'Locating…', AppColors.warning)
            : hasFix
                ? (Icons.location_on, areaLabel ?? AppLocalizations.of(context).gpsActive, AppColors.success)
                : (Icons.location_disabled_outlined, 'Waiting for GPS', AppColors.textHint);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.w(context, 12), vertical: R.h(context, 8)),
      decoration: BoxDecoration(
        color: const Color(0xE6141C2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: R.sp(context, 14), color: color),
          SizedBox(width: R.w(context, 6)),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: R.sp(context, 12),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
