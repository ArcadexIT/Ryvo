import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// In-trip sheet: destination, driver, and the actions for this ride.
class DriverTripCard extends StatelessWidget {
  const DriverTripCard({
    super.key,
    required this.name,
    required this.ratingLabel,
    required this.onCall,
    required this.onChat,
    this.plate,
    this.vehicleLine,
    this.kicker,
    this.headline,
    this.subtitle,
    this.share,
    this.footer,
  });

  final String name;
  final String ratingLabel;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final String? plate;
  final String? vehicleLine;
  final String? kicker;
  final String? headline;
  final String? subtitle;
  final Widget? share;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final plateText = plate?.trim() ?? '';
    final place = headline?.trim() ?? '';
    final detail = subtitle?.trim() ?? '';
    final showDetail = detail.isNotEmpty && detail != place;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: AppColors.obsidian.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.modal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _Handle()),
                if (place.isNotEmpty || (kicker?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 12),
                  _Destination(
                    kicker: kicker?.trim() ?? '',
                    place: place,
                    detail: showDetail ? detail : '',
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.obsidian,
                      child: Text(
                        initials,
                        style: RyvoTypography.heading(
                          fontSize: 14,
                          color: AppColors.white,
                          letterSpacing: -0.3,
                        ),
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
                            style: RyvoTypography.style(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                ratingLabel,
                                style: RyvoTypography.eta(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (vehicleLine != null &&
                                  vehicleLine!.trim().isNotEmpty) ...[
                                Text(
                                  '  ·  ',
                                  style: RyvoTypography.style(
                                    fontSize: 13,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    vehicleLine!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RyvoTypography.style(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (plateText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _PlateBadge(plate: plateText),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: Icons.chat_bubble_rounded,
                      tooltip: 'Chat',
                      onTap: onChat,
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: Icons.call_rounded,
                      tooltip: 'Call',
                      onTap: onCall,
                    ),
                    if (share != null) ...[
                      const SizedBox(width: 8),
                      share!,
                    ],
                  ],
                ),
                if (footer != null) ...[
                  const SizedBox(height: 14),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) return list.first[0].toUpperCase();
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.kicker,
    required this.place,
    required this.detail,
  });

  final String kicker;
  final String place;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.textPrimary, width: 1.5),
            ),
            child: const SizedBox(width: 8, height: 8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker.isNotEmpty)
                Text(
                  kicker,
                  style: RyvoTypography.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.1,
                  ),
                ),
              if (place.isNotEmpty) ...[
                if (kicker.isNotEmpty) const SizedBox(height: 2),
                Text(
                  place,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.heading(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _PlateBadge extends StatelessWidget {
  const _PlateBadge({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        plate.toUpperCase(),
        style: RyvoTypography.style(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: 0.8,
          height: 1,
          tabular: true,
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
