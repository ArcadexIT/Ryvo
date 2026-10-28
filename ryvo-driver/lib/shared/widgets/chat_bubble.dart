import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isSent;
  final String timestamp;
  final String? status;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSent,
    required this.timestamp,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSent ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
          border: Border.all(color: isSent ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp,
                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint),
                ),
                if (isSent && status != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    status!,
                    style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
