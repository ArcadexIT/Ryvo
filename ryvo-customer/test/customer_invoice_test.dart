import 'package:flutter_test/flutter_test.dart';
import 'package:ryvo_customer/features/bookings/domain/customer_invoice.dart';
import 'package:ryvo_customer/features/bookings/presentation/invoice_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses an invoice and builds a downloadable pdf', () async {
    final invoice = CustomerInvoice.tryParse({
      'id': 'inv-1',
      'invoiceNumber': 'INV-000010',
      'total': '35.00',
      'issuedAt': '2026-10-12T10:00:00.000Z',
      'email': 'jane@email.com',
      'job': {
        'jobNumber': 'RYVO-20261012-0001',
        'pickupAddress': '12 High Street, London',
        'dropoffAddress': '12 High Street, London',
        'completedAt': '2026-10-12T11:00:00.000Z',
        'serviceCategory': {'name': 'Jump Start', 'slug': 'jump-start'},
        'vehicle': {'make': 'Ford', 'model': 'Focus', 'year': 2018, 'plateNumber': 'AB12 CDE'},
        'provider': {'user': {'fullName': 'Alex Provider'}},
      },
      'payment': {'method': 'stripe', 'status': 'paid', 'paidAt': '2026-10-12T11:05:00.000Z'},
      'customer': {
        'user': {'fullName': 'Jane Smith', 'email': 'jane@email.com', 'phone': '+447700900001'},
      },
    });

    expect(invoice, isNotNull);
    expect(invoice!.amountLabel, '£35.00');
    expect(invoice.statusLabel, 'Paid');
    expect(invoice.paymentMethodLabel, 'Card');
    expect(invoice.vehicleSummary, '2018 Ford Focus · AB12 CDE');
    expect(invoice.dropoffLabel, isNull);
    expect(invoice.billToName, 'Jane Smith');

    final bytes = await buildInvoicePdf(invoice);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });
}
