import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

final _faqsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioClientProvider).dio.get('/provider/faqs');
  final body = res.data;
  final data = body is Map && body.containsKey('data') ? body['data'] : body;
  final list = data as List? ?? [];
  return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
});

class HelpSupportPage extends ConsumerWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(_faqsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).helpSupport, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionCard(
              icon: Icons.confirmation_number_outlined,
              title: AppLocalizations.of(context).mySupportTickets,
              subtitle: AppLocalizations.of(context).viewTicketsAndChatWithOurTeam,
              onTap: () => context.push('/support/tickets'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.add_comment_outlined,
              title: AppLocalizations.of(context).contactSupport,
              subtitle: AppLocalizations.of(context).openANewTicketForHelp,
              onTap: () => context.push('/support/new'),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context).faq, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            faqs.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(AppLocalizations.of(context).couldNotLoadFAQs,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
              data: (list) => Column(
                children: list.map((faq) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ExpansionTile(
                      title: Text('${faq['question'] ?? faq['q'] ?? ''}',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.grey500,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text('${faq['answer'] ?? faq['a'] ?? ''}',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).quickContact, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.build_outlined,
              title: AppLocalizations.of(context).technicalSupport,
              subtitle: AppLocalizations.of(context).appIssuesBugsCrashes,
              onTap: () => context.push('/support/new?category=technical'),
            ),
            const SizedBox(height: 8),
            _ContactTile(
              icon: Icons.payments_outlined,
              title: AppLocalizations.of(context).paymentSupport,
              subtitle: AppLocalizations.of(context).earningsWithdrawalsFees,
              onTap: () => context.push('/support/new?category=payment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey500),
          ],
        ),
      ),
    );
  }
}
