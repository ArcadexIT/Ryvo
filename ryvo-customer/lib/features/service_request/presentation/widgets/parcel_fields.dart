import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import 'ride_tile.dart' show rideSelectionColor;

/// Recipient inputs and package-size cards for a parcel request.
class ParcelFields extends StatelessWidget {
  const ParcelFields({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.size,
    required this.onSize,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String size;
  final ValueChanged<String> onSize;

  static const _sizes = [
    (id: 'small', label: 'Small', hint: 'Up to 2 kg', icon: 18.0),
    (id: 'medium', label: 'Medium', hint: 'Up to 10 kg', icon: 22.0),
    (id: 'large', label: 'Large', hint: 'Up to 25 kg', icon: 26.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Package size'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _sizes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SizeCard(
                    label: _sizes[i].label,
                    hint: _sizes[i].hint,
                    iconSize: _sizes[i].icon,
                    selected: size == _sizes[i].id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSize(_sizes[i].id);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Recipient'),
          const SizedBox(height: 8),
          _FilledField(
            controller: nameController,
            hint: 'Recipient name',
            icon: CupertinoIcons.person,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),
          _FilledField(
            controller: phoneController,
            hint: 'Recipient phone',
            icon: CupertinoIcons.phone,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: RyvoTypography.style(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: -0.1,
      ),
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.label,
    required this.hint,
    required this.iconSize,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final double iconSize;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = rideSelectionColor();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surface
              : AppColors.surface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 28,
              child: Icon(
                CupertinoIcons.cube_box,
                size: iconSize,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: RyvoTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RyvoTypography.distance(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilledField extends StatelessWidget {
  const _FilledField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: color == Colors.transparent
              ? BorderSide.none
              : BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: RyvoTypography.style(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
      cursorColor: AppColors.focusBorder,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        hintText: hint,
        hintStyle: RyvoTypography.style(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textHint,
          letterSpacing: -0.2,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        isDense: true,
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(AppColors.focusBorder, 1.5),
      ),
    );
  }
}
