import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../../domain/customer_invoice.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  final _email = TextEditingController();
  bool _loading = true;
  bool _savingEmail = false;
  String? _existingEmail;
  String? _error;
  List<CustomerInvoice> _invoices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile();
      final data = await ref.read(apiClientProvider).get<dynamic>('/customer/invoices');
      if (!mounted) return;
      setState(() {
        _existingEmail = profile.email;
        if (_email.text.isEmpty) _email.text = profile.email ?? '';
        _invoices = data is List ? data.map(CustomerInvoice.tryParse).whereType<CustomerInvoice>().toList() : const [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_invoices.isEmpty) {
        setState(() => _error = error.toString().replaceFirst('ApiException: ', ''));
      } else {
        showApiError(context, error);
      }
    }
  }

  Future<void> _saveEmail() async {
    final value = _email.text.trim();
    if (!value.contains('@')) {
      showApiError(context, 'Enter a valid email address.');
      return;
    }
    setState(() => _savingEmail = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(email: value);
      ref.invalidate(profileProvider);
      if (mounted) setState(() => _existingEmail = value);
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsEmail = _existingEmail == null || _existingEmail!.trim().isEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Invoices', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (needsEmail) ...[
                    _EmailPrompt(
                      controller: _email,
                      saving: _savingEmail,
                      onSave: _saveEmail,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_error != null && _invoices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                    )
                  else if (_invoices.isEmpty)
                    const _EmptyInvoices()
                  else ...[
                    Text(
                      'Tap an invoice to view it and download a PDF.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    ..._invoices.map(
                      (invoice) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InvoiceCard(
                          invoice: invoice,
                          onTap: () => context.push('/invoices/${invoice.id}', extra: invoice),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EmailPrompt extends StatelessWidget {
  const _EmailPrompt({required this.controller, required this.saving, required this.onSave});

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email for invoices', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Add an email address so completed-job invoices can be sent to you.',
            style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@email.com'),
          ),
          const SizedBox(height: 12),
          RyvoButton(
            label: saving ? 'Saving…' : 'Save email',
            isLoading: saving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text('No invoices yet', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'They appear here after a job is completed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});

  final CustomerInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      invoice.serviceName,
      if (invoice.issuedLabel.isNotEmpty) invoice.issuedLabel,
    ].join(' · ');
    final statusColor = _statusColor(invoice.paymentStatus);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(serviceIcon(invoice.serviceSlug, invoice.serviceIcon), color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.invoiceNumber, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(invoice.amountLabel, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(invoice.statusLabel, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.grey400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String? status) {
  return switch (status) {
    'paid' => AppColors.success,
    'refunded' => AppColors.info,
    'failed' => AppColors.error,
    'pending' || 'held' => AppColors.warning,
    _ => AppColors.textSecondary,
  };
}
