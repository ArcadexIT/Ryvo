import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// En-route and in-trip driver sheet: plate, avatar, rating, chat, and call.
class DriverTripCard extends StatelessWidget {
  const DriverTripCard({
    super.key,
    required this.name,
    required this.ratingLabel,
    required this.onCall,
    required this.onChat,
    this.plate,
    this.vehicleLine,
    this.headline,
    this.subtitle,
    this.footer,
  });

  final String name;
  final String ratingLabel;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final String? plate;
  final String? vehicleLine;
  final String? headline;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final plateText = plate?.trim() ?? '';

    return Material(
      color: AppColors.modal,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _Handle()),
              if (headline != null) ...[
                const SizedBox(height: 14),
                Text(
                  headline!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RyvoTypography.heading(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.obsidian,
                    child: Text(
                      initials,
                      style: RyvoTypography.heading(
                        fontSize: 16,
                        color: AppColors.white,
                        letterSpacing: -0.4,
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
                            fontSize: 16,
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
                              size: 16,
                              color: AppColors.primary,
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
                      ],
                    ),
                  ),
                  if (plateText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _PlateBadge(plate: plateText),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _RoundAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    tooltip: 'Chat',
                    onTap: onChat,
                  ),
                  const SizedBox(width: 10),
                  _RoundAction(
                    icon: Icons.call_rounded,
                    tooltip: 'Call',
                    onTap: onCall,
                  ),
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) return list.first[0].toUpperCase();
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cta,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        plate.toUpperCase(),
        style: RyvoTypography.style(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.onCta,
          letterSpacing: 1.1,
          height: 1,
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
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
