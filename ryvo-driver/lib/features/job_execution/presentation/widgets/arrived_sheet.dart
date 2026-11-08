import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';
import 'swipe_to_confirm.dart';

/// Driver HUD shown once the provider has arrived at pickup.
class ArrivedSheet extends StatelessWidget {
  const ArrivedSheet({
    super.key,
    required this.riderName,
    required this.rating,
    required this.pickup,
    required this.dropoff,
    required this.isParcel,
    required this.navigateLabel,
    required this.confirming,
    required this.uploadingPhoto,
    required this.pickupPhotoUrl,
    required this.onCall,
    required this.onMessage,
    required this.onNavigate,
    required this.onStart,
    required this.onCancel,
    required this.onUploadPhoto,
  });

  final String riderName;
  final double rating;
  final String pickup;
  final String dropoff;
  final bool isParcel;
  final String navigateLabel;
  final ValueListenable<bool> confirming;
  final ValueListenable<bool> uploadingPhoto;
  final ValueListenable<String?> pickupPhotoUrl;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onNavigate;
  final Future<bool> Function() onStart;
  final VoidCallback onCancel;
  final VoidCallback onUploadPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pickupLabel = _compactStopLabel(pickup, 'Pickup');
    final dropoffLabel = _compactStopLabel(dropoff, 'Dropoff');

    return Material(
      color: AppColors.modal,
      elevation: 0,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _Grabber()),
                const SizedBox(height: 16),
                _RiderRow(
                  name: riderName,
                  rating: rating,
                  callTooltip: l10n.callCustomer,
                  messageTooltip: l10n.chatWithCustomer,
                  onCall: onCall,
                  onMessage: onMessage,
                ),
                const SizedBox(height: 18),
                _RouteTimeline(pickup: pickupLabel, dropoff: dropoffLabel),
                if (isParcel) ...[
                  const SizedBox(height: 16),
                  _ParcelPhotoRow(
                    uploadingPhoto: uploadingPhoto,
                    pickupPhotoUrl: pickupPhotoUrl,
                    onUpload: onUploadPhoto,
                  ),
                ],
                const SizedBox(height: 18),
                _NavigateButton(label: navigateLabel, onTap: onNavigate),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: confirming,
                  builder: (context, busy, _) {
                    return SwipeToConfirm(
                      label: busy ? 'STARTING…' : 'SWIPE TO START TRIP',
                      enabled: !busy,
                      busy: busy,
                      onConfirmed: onStart,
                    );
                  },
                ),
                const SizedBox(height: 2),
                Center(
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onCancel();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textHint,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      'Issue with pickup?',
                      style: _hud(
                          size: 13,
                          weight: FontWeight.w600,
                          color: AppColors.textHint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.grey300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.name,
    required this.rating,
    required this.callTooltip,
    required this.messageTooltip,
    required this.onCall,
    required this.onMessage,
  });

  final String name;
  final double rating;
  final String callTooltip;
  final String messageTooltip;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final label = name.trim().isEmpty ? 'Rider' : name.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _hud(
                  size: 20,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              _RatingPill(rating: rating),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _QuickAction(
          icon: Icons.phone_rounded,
          tooltip: callTooltip,
          onTap: onCall,
        ),
        const SizedBox(width: 10),
        _QuickAction(
          icon: Icons.chat_bubble_rounded,
          tooltip: messageTooltip,
          onTap: onMessage,
        ),
      ],
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final value = rating > 0 ? rating.toStringAsFixed(1) : 'New';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.actionSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('★',
                style: _hud(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.warning)),
            const SizedBox(width: 3),
            Text(
              value,
              style: _hud(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
                tabular: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.actionSurface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, size: 22, color: AppColors.lime),
          ),
        ),
      ),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  static const double _row = 22;
  static const double _node = 8;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 16,
            child: Column(
              children: [
                SizedBox(height: (_row - _node) / 2),
                _RouteNode(color: AppColors.primary, circle: true),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: 1.5,
                      child: ColoredBox(color: AppColors.divider),
                    ),
                  ),
                ),
                _RouteNode(color: AppColors.white, circle: false),
                SizedBox(height: (_row - _node) / 2),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _StopLabel(text: pickup),
                const SizedBox(height: 16),
                _StopLabel(text: dropoff),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopLabel extends StatelessWidget {
  const _StopLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _RouteTimeline._row,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _hud(
            size: 14,
            weight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({required this.color, required this.circle});

  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _RouteTimeline._node,
      height: _RouteTimeline._node,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }
}

class _NavigateButton extends StatelessWidget {
  const _NavigateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.actionSurface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.location_north_fill,
                  size: 18, color: AppColors.lime),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _hud(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
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

class _ParcelPhotoRow extends StatelessWidget {
  const _ParcelPhotoRow({
    required this.uploadingPhoto,
    required this.pickupPhotoUrl,
    required this.onUpload,
  });

  final ValueListenable<bool> uploadingPhoto;
  final ValueListenable<String?> pickupPhotoUrl;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: uploadingPhoto,
      builder: (context, uploading, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: pickupPhotoUrl,
          builder: (context, url, _) {
            final uploaded = url != null && url.isNotEmpty;
            final label = uploading
                ? 'Uploading…'
                : uploaded
                    ? 'Photo uploaded'
                    : 'Take pickup photo';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload a pickup photo of the parcel before starting.',
                  style: _hud(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.textSecondary),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: uploading ? null : onUpload,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.lime,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      uploaded
                          ? Icons.check_circle_rounded
                          : Icons.photo_camera_outlined,
                      size: 18,
                    ),
                    label: Text(
                      label,
                      style: _hud(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.lime),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

TextStyle _hud({
  required double size,
  required FontWeight weight,
  required Color color,
  double letterSpacing = 0,
  bool tabular = false,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.2,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

/// Keeps the street line and drops trailing admin noise such as
/// "Dhaka, Dhaka Division, 1212".
String _compactStopLabel(String raw, String fallback) {
  final parts = raw
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return fallback;
  final noisyTail = parts.skip(1).any(_isRegionalNoise);
  final cleaned = noisyTail ? parts.first : parts.take(2).join(', ');
  return cleaned.isEmpty ? fallback : cleaned;
}

bool _isRegionalNoise(String part) {
  final lower = part.toLowerCase();
  if (RegExp(r'^\d{3,6}$').hasMatch(part)) return true;
  const markers = [
    'division',
    'district',
    'province',
    'governorate',
    'prefecture',
    'county'
  ];
  for (final marker in markers) {
    if (lower == marker || lower.endsWith(' $marker')) return true;
  }
  return false;
}
