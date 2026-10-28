import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/providers/app_providers.dart';

class LegalDocumentPage extends ConsumerWidget {
  const LegalDocumentPage({super.key, required this.documentKey});

  final String documentKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final document = ref.watch(legalDocumentProvider(documentKey));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          document.maybeWhen(
            data: (doc) => doc.title,
            orElse: () => documentKey == 'privacy' ? l10n.privacyPolicy : l10n.termsAndConditions,
          ),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: document.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.couldNotLoadThisDocument,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(legalDocumentProvider(documentKey)),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (doc) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (_formatUpdated(doc.updatedAt) case final updated?)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '${l10n.lastUpdated}: $updated',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
                ),
              ),
            ..._blocks(doc.content),
          ],
        ),
      ),
    );
  }

  List<Widget> _blocks(String content) {
    final widgets = <Widget>[];
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final paragraph = <String>[];
    final bullets = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      widgets.add(_paragraph(paragraph.join(' ')));
      widgets.add(const SizedBox(height: 12));
      paragraph.clear();
    }

    void flushBullets() {
      if (bullets.isEmpty) return;
      for (final item in bullets) {
        widgets.add(_bullet(item));
      }
      widgets.add(const SizedBox(height: 8));
      bullets.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        flushParagraph();
        flushBullets();
        continue;
      }
      if (line.startsWith('## ')) {
        flushParagraph();
        flushBullets();
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 12, bottom: 8),
          child: Text(
            line.substring(3).trim(),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        bullets.add(line.substring(2).trim());
        continue;
      }
      flushBullets();
      paragraph.add(line);
    }
    flushParagraph();
    flushBullets();
    return widgets;
  }

  Widget _paragraph(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 14, height: 1.55, color: AppColors.textSecondary),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 8),
            child: Icon(Icons.circle, size: 6, color: AppColors.primary),
          ),
          Expanded(child: _paragraph(text)),
        ],
      ),
    );
  }

}

final legalDocumentProvider = FutureProvider.family<LegalDocument, String>((ref, key) {
  return ref.watch(legalRepositoryProvider).get(key);
});

String? _formatUpdated(String? value) {
  if (value == null || value.isEmpty) return null;
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return null;
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
