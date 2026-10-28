import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/customer_invoice.dart';

Future<Uint8List> buildInvoicePdf(CustomerInvoice invoice) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'));
  final doc = pw.Document();
  const ink = PdfColor.fromInt(0xFF111827);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const line = PdfColor.fromInt(0xFFE5E7EB);
  const brand = PdfColor.fromInt(0xFF32BB78);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: pw.BoxDecoration(
                color: ink,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RYVO',
                          style: pw.TextStyle(color: brand, fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Ride', style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.6),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(invoice.invoiceNumber, style: pw.TextStyle(color: brand, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      if (invoice.issuedLabel.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(invoice.issuedLabel, style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 22),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _block('Billed to', [
                    invoice.billToName,
                    if (invoice.billToEmail != null) invoice.billToEmail!,
                    if (invoice.billToPhone != null) invoice.billToPhone!,
                  ], ink, muted),
                ),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: _block('Job', [
                    invoice.serviceName,
                    if (invoice.jobNumber != null) invoice.jobNumber!,
                    if (invoice.completedLabel.isNotEmpty) 'Completed ${invoice.completedLabel}',
                  ], ink, muted),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            if (invoice.vehicleSummary != null ||
                invoice.locationLabel != null ||
                invoice.dropoffLabel != null ||
                invoice.providerLabel != null)
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8F9FA),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  children: [
                    if (invoice.vehicleSummary != null) _metaRow('Vehicle', invoice.vehicleSummary!, ink, muted),
                    if (invoice.locationLabel != null) _metaRow('Pickup', invoice.locationLabel!, ink, muted),
                    if (invoice.dropoffLabel != null) _metaRow('Drop-off', invoice.dropoffLabel!, ink, muted),
                    if (invoice.providerLabel != null) _metaRow('Driver', invoice.providerLabel!, ink, muted),
                  ],
                ),
              ),
            pw.SizedBox(height: 22),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 1))),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Description', style: pw.TextStyle(color: muted, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  pw.Text('Amount', style: pw.TextStyle(color: muted, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: line, width: 1))),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(invoice.serviceName, style: pw.TextStyle(color: ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('Completed ride', style: pw.TextStyle(color: muted, fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.Text(invoice.amountLabel, style: pw.TextStyle(color: ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFFFF7ED),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total', style: pw.TextStyle(color: ink, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(invoice.amountLabel, style: pw.TextStyle(color: ink, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(_paymentLine(invoice), style: pw.TextStyle(color: muted, fontSize: 10)),
            pw.Spacer(),
            pw.Container(height: 1, color: line),
            pw.SizedBox(height: 10),
            pw.Text(
              'Ryvo Ltd  ·  Thank you for choosing RYVO.',
              style: pw.TextStyle(color: muted, fontSize: 9),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'This invoice is for a completed RYVO ride.',
              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _block(String title, List<String> lines, PdfColor ink, PdfColor muted) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title.toUpperCase(), style: pw.TextStyle(color: muted, fontSize: 9, fontWeight: pw.FontWeight.bold, letterSpacing: 0.6)),
      pw.SizedBox(height: 6),
      ...lines.map(
        (line) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(line, style: pw.TextStyle(color: ink, fontSize: 11)),
        ),
      ),
    ],
  );
}

pw.Widget _metaRow(String label, String value, PdfColor ink, PdfColor muted) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 72, child: pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 10))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(color: ink, fontSize: 10))),
      ],
    ),
  );
}

String _paymentLine(CustomerInvoice invoice) {
  final method = invoice.paymentMethodLabel;
  final status = invoice.statusLabel;
  final paid = invoice.paidLabel;
  if (method.isEmpty && paid.isEmpty) return 'Status: $status';
  if (method.isEmpty) return '$status${paid.isEmpty ? '' : ' on $paid'}';
  if (paid.isEmpty) return '$status · $method';
  return '$status · $method · $paid';
}
