import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../support/domain/support_entities.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

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
        actions: [IconButton(onPressed: () => context.push('/support/new'), icon: const Icon(Icons.add))],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(supportTicketsProvider);
          await ref.read(supportTicketsProvider.future);
        },
        child: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
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
                        Text(AppLocalizations.of(context).noSupportTicketsYet, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        FilledButton(onPressed: () => context.push('/support/new'), child: Text(AppLocalizations.of(context).createTicket)),
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
                return GestureDetector(
                  onTap: () => context.push('/support/${ticket.id}'),
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
                        Text(ticket.ticketNumber, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        const SizedBox(height: 8),
                        Text(ticket.subject, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                          '${formatTicketCategory(ticket.category)} · ${formatTicketStatus(ticket.status)} · ${_shortDate(ticket.createdAt)}',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}';
}
