import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/di_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

/// Opens in-job chat for the active job (or an explicit [jobId]).
void openJobChat(BuildContext context, WidgetRef ref, {String? jobId}) {
  final id = jobId ?? ref.read(activeJobProvider)?.id;
  if (id == null || id.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).noActiveJobToChatOn, style: GoogleFonts.poppins()),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }
  try {
    ref.read(providerSocketProvider).connect();
  } catch (_) {}
  ref.read(providerSocketProvider).subscribeJob(id);
  context.push('/chat/$id');
}

/// Circular chat action used on navigation / service screens.
class JobChatButton extends ConsumerWidget {
  const JobChatButton({super.key, this.jobId, this.color = AppColors.info, this.size = 44});

  final String? jobId;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => openJobChat(context, ref, jobId: jobId),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(Icons.chat_bubble_outline, color: color, size: size * 0.45),
      ),
    );
  }
}
