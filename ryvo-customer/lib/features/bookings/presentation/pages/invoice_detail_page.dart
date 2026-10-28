import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/widgets/ryvo_button.dart';
import '../../domain/customer_invoice.dart';
import '../invoice_pdf.dart';

class InvoiceDetailPage extends ConsumerStatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId, this.initial});

  final String invoiceId;
  final CustomerInvoice? initial;

  @override
  ConsumerState<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends ConsumerState<InvoiceDetailPage> {
  CustomerInvoice? _invoice;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _invoice = widget.initial;
    _loading = widget.initial == null;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).get<dynamic>('/customer/invoices/${widget.invoiceId}');
      final parsed = CustomerInvoice.tryParse(data);
      if (!mounted) return;
      setState(() {
        if (parsed != null) _invoice = parsed;
        _error = parsed == null && _invoice == null ? 'Invoice could not be loaded.' : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _invoice == null ? error.toString().replaceFirst('ApiException: ', '') : null;
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final invoice = _invoice;
    if (invoice == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await buildInvoicePdf(invoice);
      await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber}.pdf');
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Invoice', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (invoice != null)
            IconButton(
              tooltip: 'Download PDF',
              onPressed: _downloading ? null : _download,
              icon: const Icon(Icons.file_download_outlined),
            ),
        ],
      ),
      body: _loading && invoice == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : invoice == null
              ? _ErrorState(message: _error ?? 'Invoice could not be loaded.', onRetry: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                })
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          _InvoiceSheet(invoice: invoice),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: RyvoButton(
                          label: 'Download PDF',
                          isLoading: _downloading,
                          prefixIcon: const Icon(Icons.file_download_outlined, size: 20),
                          onPressed: _download,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.grey400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: Text('Try again', style: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}

class _InvoiceSheet extends StatelessWidget {
  const _InvoiceSheet({required this.invoice});

  final CustomerInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(AppColors.isDark ? 0.35 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(invoice: invoice),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Party(
                    title: 'Billed to',
                    lines: [
                      invoice.billToName,
                      if (invoice.billToEmail != null) invoice.billToEmail!,
                      if (invoice.billToPhone != null) invoice.billToPhone!,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Party(
                    title: 'Job',
                    lines: [
                      invoice.serviceName,
                      if (invoice.jobNumber != null) invoice.jobNumber!,
                      if (invoice.completedLabel.isNotEmpty) 'Completed ${invoice.completedLabel}',
                    ],
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          if (_hasDetails) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _DashedDivider(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                children: [
                  if (invoice.vehicleSummary != null) _DetailRow(label: 'Vehicle', value: invoice.vehicleSummary!),
                  if (invoice.locationLabel != null) _DetailRow(label: 'Pickup', value: invoice.locationLabel!),
                  if (invoice.dropoffLabel != null) _DetailRow(label: 'Drop-off', value: invoice.dropoffLabel!),
                  if (invoice.providerLabel != null) _DetailRow(label: 'Driver', value: invoice.providerLabel!),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: _DashedDivider(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Description', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textHint, letterSpacing: 0.4)),
                const Spacer(),
                Text('Amount', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textHint, letterSpacing: 0.4)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(serviceIcon(invoice.serviceSlug, invoice.serviceIcon), color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.serviceName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('Completed ride', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Text(invoice.amountLabel, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(AppColors.isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text('Total', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Spacer(),
                  Text(invoice.amountLabel, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                Icon(_statusIcon(invoice.paymentStatus), size: 16, color: _statusColor(invoice.paymentStatus)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _paymentSentence(invoice),
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Text(
              'Ryvo Ltd  ·  Thank you for choosing RYVO.',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasDetails =>
      invoice.vehicleSummary != null ||
      invoice.locationLabel != null ||
      invoice.dropoffLabel != null ||
      invoice.providerLabel != null;
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice});

  final CustomerInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final wordmark = GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, height: 1, letterSpacing: -0.6, color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 6, color: AppColors.primary),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      style: wordmark,
                      children: [
                        const TextSpan(text: 'J'),
                        TextSpan(text: 'o', style: wordmark.copyWith(color: AppColors.primary)),
                        const TextSpan(text: 'mp'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _StatusPill(label: invoice.statusLabel, status: invoice.paymentStatus),
                ],
              ),
              const SizedBox(height: 18),
              Text('INVOICE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: AppColors.textHint)),
              const SizedBox(height: 4),
              Text(invoice.invoiceNumber, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Text(invoice.amountLabel, style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w700, height: 1.05, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                invoice.issuedLabel.isEmpty ? 'Amount charged' : 'Issued ${invoice.issuedLabel}',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: GoogleFonts.poppins(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Party extends StatelessWidget {
  const _Party({required this.title, required this.lines, this.alignEnd = false});

  final String title;
  final List<String> lines;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.7, color: AppColors.textHint)),
        const SizedBox(height: 6),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              style: GoogleFonts.poppins(fontSize: 13, height: 1.35, color: AppColors.textPrimary, fontWeight: lines.first == line ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 6.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1.5,
              margin: const EdgeInsets.only(right: gap),
              color: AppColors.divider,
            ),
          ),
        );
      },
    );
  }
}

Color _statusColor(String? status) {
  return switch (status) {
    'paid' => AppColors.success,
    'refunded' => AppColors.info,
    'failed' => AppColors.error,
    'pending' || 'held' => AppColors.warning,
    _ => AppColors.primary,
  };
}

IconData _statusIcon(String? status) {
  return switch (status) {
    'paid' => Icons.check_circle_outline,
    'refunded' => Icons.undo,
    'failed' => Icons.error_outline,
    _ => Icons.receipt_long_outlined,
  };
}

String _paymentSentence(CustomerInvoice invoice) {
  final method = invoice.paymentMethodLabel;
  final status = invoice.statusLabel;
  final paid = invoice.paidLabel;
  if (method.isEmpty && paid.isEmpty) return status;
  if (method.isEmpty) return paid.isEmpty ? status : '$status on $paid';
  if (paid.isEmpty) return '$status with $method';
  return '$status with $method on $paid';
}
