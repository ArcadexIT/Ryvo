import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/support_models.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class SupportTicketsPage extends ConsumerWidget {
  const SupportTicketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).myTickets, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            onPressed: () => context.push('/support/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(supportTicketsProvider);
          await ref.read(supportTicketsProvider.future);
        },
        child: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(e.toString(), style: GoogleFonts.poppins(color: AppColors.error)),
              ),
            ],
          ),
          data: (tickets) {
            if (tickets.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.support_agent_outlined, size: 56, color: AppColors.grey500),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context).noSupportTicketsYet, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(AppLocalizations.of(context).needHelpCreateATicketAndOurTeamWillRespond, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => context.push('/support/new'),
                          child: Text(AppLocalizations.of(context).createTicket),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ticket = tickets[index];
                return _TicketCard(
                  ticket: ticket,
                  onTap: () => context.push('/support/${ticket.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  Color _statusColor() {
    return switch (ticket.status) {
      'open' => AppColors.info,
      'in_progress' => AppColors.primary,
      'resolved' => AppColors.success,
      'closed' => AppColors.grey500,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ticket.ticketNumber, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formatTicketStatus(ticket.status),
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(ticket.subject, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              '${formatTicketCategory(ticket.category)} · ${DateFormat('MMM d, yyyy').format(ticket.createdAt)}',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
