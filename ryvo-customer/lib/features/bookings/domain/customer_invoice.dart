import 'package:intl/intl.dart';

import '../../../data/models/models.dart';

class CustomerInvoice {
  const CustomerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.total,
    this.issuedAt,
    this.sentAt,
    this.email,
    this.serviceName = 'Ride',
    this.serviceSlug,
    this.serviceIcon,
    this.jobNumber,
    this.pickupAddress,
    this.dropoffAddress,
    this.completedAt,
    this.vehicleYear,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.plateNumber,
    this.providerName,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.paymentMethod,
    this.paymentStatus,
    this.paidAt,
  });

  final String id;
  final String invoiceNumber;
  final double total;
  final DateTime? issuedAt;
  final DateTime? sentAt;
  final String? email;
  final String serviceName;
  final String? serviceSlug;
  final String? serviceIcon;
  final String? jobNumber;
  final String? pickupAddress;
  final String? dropoffAddress;
  final DateTime? completedAt;
  final int? vehicleYear;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? plateNumber;
  final String? providerName;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? paidAt;

  String get amountLabel => formatMoney(total);

  String get issuedLabel => _formatDate(issuedAt);

  String get paidLabel => _formatDate(paidAt);

  String get completedLabel => _formatDate(completedAt);

  String get statusLabel => switch (paymentStatus) {
        'paid' => 'Paid',
        'refunded' => 'Refunded',
        'failed' => 'Failed',
        'held' => 'Authorised',
        'pending' => 'Pending',
        _ => 'Issued',
      };

  String get paymentMethodLabel => switch (paymentMethod) {
        'stripe' => 'Card',
        'wallet' => 'Wallet',
        'cash' => 'Cash',
        null || '' => '',
        _ => paymentMethod!,
      };

  String get billToName => _clean(customerName) ?? 'Customer';

  String? get billToEmail {
    final value = _clean(customerEmail) ?? _clean(email);
    return value;
  }

  String? get billToPhone => _clean(customerPhone);

  String? get vehicleSummary {
    final name = [
      if (vehicleYear != null) '$vehicleYear',
      if (_clean(vehicleMake) != null) vehicleMake!.trim(),
      if (_clean(vehicleModel) != null) vehicleModel!.trim(),
    ].join(' ');
    final plate = _clean(plateNumber);
    if (name.isEmpty) return plate;
    if (plate == null) return name;
    return '$name · $plate';
  }

  String? get locationLabel => _clean(pickupAddress);

  String? get dropoffLabel {
    final dropoff = _clean(dropoffAddress);
    if (dropoff == null || dropoff == locationLabel) return null;
    return dropoff;
  }

  String? get providerLabel => _clean(providerName);

  static CustomerInvoice? tryParse(dynamic json) {
    final map = _asMap(json);
    if (map == null) return null;
    final id = map['id']?.toString() ?? '';
    final number = map['invoiceNumber']?.toString() ?? '';
    if (id.isEmpty || number.isEmpty) return null;

    final job = _asMap(map['job']);
    final service = _asMap(job?['serviceCategory']);
    final vehicle = _asMap(job?['vehicle']);
    final providerUser = _asMap(_asMap(job?['provider'])?['user']);
    final customerUser = _asMap(_asMap(map['customer'])?['user']);
    final payment = _asMap(map['payment']);
    final yearRaw = vehicle?['year'];

    return CustomerInvoice(
      id: id,
      invoiceNumber: number,
      total: _toAmount(map['total']),
      issuedAt: _date(map['issuedAt']),
      sentAt: _date(map['sentAt']),
      email: map['email']?.toString(),
      serviceName: _clean(service?['name']?.toString()) ?? 'Ride',
      serviceSlug: service?['slug']?.toString(),
      serviceIcon: service?['icon']?.toString(),
      jobNumber: job?['jobNumber']?.toString(),
      pickupAddress: job?['pickupAddress']?.toString(),
      dropoffAddress: job?['dropoffAddress']?.toString(),
      completedAt: _date(job?['completedAt']),
      vehicleYear: yearRaw is num ? yearRaw.toInt() : int.tryParse('${yearRaw ?? ''}'),
      vehicleMake: vehicle?['make']?.toString(),
      vehicleModel: vehicle?['model']?.toString(),
      vehicleColor: vehicle?['color']?.toString(),
      plateNumber: vehicle?['plateNumber']?.toString(),
      providerName: providerUser?['fullName']?.toString(),
      customerName: customerUser?['fullName']?.toString(),
      customerEmail: customerUser?['email']?.toString(),
      customerPhone: customerUser?['phone']?.toString(),
      paymentMethod: payment?['method']?.toString(),
      paymentStatus: payment?['status']?.toString(),
      paidAt: _date(payment?['paidAt']),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return DateFormat('d MMM yyyy').format(date.toLocal());
}

String? _clean(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

double _toAmount(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
