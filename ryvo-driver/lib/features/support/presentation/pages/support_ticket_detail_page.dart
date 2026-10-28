import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../support/domain/support_entities.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

final _ticketDetailProvider = FutureProvider.autoDispose.family<SupportTicketDetail, String>((ref, id) {
  return ref.read(supportRepositoryProvider).getTicket(id);
});

class SupportTicketDetailPage extends ConsumerStatefulWidget {
  const SupportTicketDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportTicketDetailPage> createState() => _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends ConsumerState<SupportTicketDetailPage> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).reply(widget.ticketId, text);
      _replyController.clear();
      ref.invalidate(_ticketDetailProvider(widget.ticketId));
      ref.invalidate(supportTicketsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(_ticketDetailProvider(widget.ticketId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: ticketAsync.maybeWhen(
          data: (t) => Text(t.ticketNumber, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          orElse: () => Text(AppLocalizations.of(context).ticket, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ticket) {
          final canReply = ticket.status != 'closed';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket.subject, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('${formatTicketCategory(ticket.category)} · ${formatTicketStatus(ticket.status)}',
                              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                          if (ticket.jobNumber != null)
                            Text('Job: ${ticket.jobNumber}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...ticket.messages.map((msg) {
                      final isAdmin = msg.isFromAdmin;
                      return Align(
                        alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAdmin ? AppColors.surface : AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.senderName ?? (isAdmin ? AppLocalizations.of(context).supportTeam : AppLocalizations.of(context).you),
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(msg.message, style: GoogleFonts.poppins(fontSize: 14)),
                              Text(_formatTime(context, msg.createdAt),
                                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              if (canReply)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          decoration: InputDecoration(hintText: AppLocalizations.of(context).writeAReply, border: OutlineInputBorder()),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : _sendReply,
                        icon: _sending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _formatTime(BuildContext context, DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? AppLocalizations.of(context).pm : AppLocalizations.of(context).am;
  final m = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, $h:$m $ampm';
}
