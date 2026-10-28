import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/support_models.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

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
      if (mounted) showApiError(context, e);
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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString(), style: GoogleFonts.poppins(color: AppColors.error))),
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
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ticket.subject, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          Text(
                            '${formatTicketCategory(ticket.category)} · ${formatTicketStatus(ticket.status)}',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (ticket.jobNumber != null) ...[
                            const SizedBox(height: 4),
                            Text('Job: ${ticket.jobNumber}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...ticket.messages.map((msg) => _MessageBubble(message: msg)),
                  ],
                ),
              ),
              if (canReply)
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context).writeAReply,
                            hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sending ? null : _sendReply,
                        icon: _sending
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, color: AppColors.primary),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppLocalizations.of(context).thisTicketIsClosedCreateANewTicketIfYouNeedMoreH,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.isFromAdmin;
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin ? AppColors.surface : AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isAdmin ? AppColors.divider : AppColors.primary.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName ?? (isAdmin ? AppLocalizations.of(context).supportTeam : AppLocalizations.of(context).you),
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(message.message, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, h:mm a').format(message.createdAt),
              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
