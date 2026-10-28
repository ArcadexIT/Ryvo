import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'secure_network_image.dart';

class ProviderAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const ProviderAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 44,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return SecureNetworkImage(
        fileUrl: avatarUrl,
        width: radius * 2,
        height: radius * 2,
        borderRadius: BorderRadius.circular(radius),
        errorWidget: _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surface,
      child: Text(
        _initials,
        style: GoogleFonts.poppins(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
