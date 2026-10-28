import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../support/domain/support_entities.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../../../../shared/widgets/ryvo_text_field.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class CreateSupportTicketPage extends ConsumerStatefulWidget {
  const CreateSupportTicketPage({super.key, this.initialCategory, this.jobId});

  final String? initialCategory;
  final String? jobId;

  @override
  ConsumerState<CreateSupportTicketPage> createState() => _CreateSupportTicketPageState();
}

class _CreateSupportTicketPageState extends ConsumerState<CreateSupportTicketPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _category = 'general';
  bool _loading = false;

  static const _categories = ['general', 'technical', 'payment', 'job_issue', 'account'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && _categories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).pleaseEnterSubjectAndMessage)));
      return;
    }

    setState(() => _loading = true);
    try {
      final ticket = await ref.read(supportRepositoryProvider).createTicket(
            category: _category,
            subject: subject,
            message: message,
            jobId: widget.jobId,
          );
      ref.invalidate(supportTicketsProvider);
      if (!mounted) return;
      context.go('/support/${ticket.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).newTicket, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.modal,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(formatTicketCategory(c)))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'general'),
              ),
              const SizedBox(height: 16),
              RyvoTextField(controller: _subjectController, label: AppLocalizations.of(context).subject, hint: AppLocalizations.of(context).briefSummary),
              const SizedBox(height: 16),
              RyvoTextField(controller: _messageController, label: AppLocalizations.of(context).message, hint: AppLocalizations.of(context).describeYourIssue, maxLines: 6),
              const SizedBox(height: 32),
              RyvoButton(label: _loading ? AppLocalizations.of(context).submitting : AppLocalizations.of(context).submitTicket, onPressed: _loading ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
