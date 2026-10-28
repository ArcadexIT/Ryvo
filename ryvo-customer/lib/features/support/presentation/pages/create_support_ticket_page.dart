import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/support_models.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class CreateSupportTicketPage extends ConsumerStatefulWidget {
  const CreateSupportTicketPage({
    super.key,
    this.initialCategory,
    this.jobId,
  });

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
      showApiError(context, AppLocalizations.of(context).pleaseEnterASubjectAndMessage);
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
      if (mounted) showApiError(context, e);
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
              Text(AppLocalizations.of(context).category, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.modal,
                style: GoogleFonts.poppins(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(formatTicketCategory(c))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'general'),
              ),
              const SizedBox(height: 16),
              RyvoTextField(
                controller: _subjectController,
                label: AppLocalizations.of(context).subject,
                hint: AppLocalizations.of(context).briefSummaryOfYourIssue,
                validator: (v) => (v?.trim().isEmpty ?? true) ? AppLocalizations.of(context).required : null,
              ),
              const SizedBox(height: 16),
              RyvoTextField(
                controller: _messageController,
                label: AppLocalizations.of(context).message,
                hint: AppLocalizations.of(context).describeYourIssueInDetail,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                validator: (v) => (v?.trim().isEmpty ?? true) ? AppLocalizations.of(context).required : null,
              ),
              if (widget.jobId != null) ...[
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).linkedToAJob,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 32),
              RyvoButton(
                label: _loading ? AppLocalizations.of(context).submitting : AppLocalizations.of(context).submitTicket,
                onPressed: _loading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
