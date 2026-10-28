import 'currency.dart';

class AuthTokens {
  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresIn: json['expiresIn'] as int?,
      );

  final String accessToken;
  final String refreshToken;
  final int? expiresIn;
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.status,
    this.ratingAvg,
    this.vehicles = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? json;
    final vehiclesJson = json['vehicles'] as List<dynamic>? ?? const [];
    return UserProfile(
      id: user['id'] as String,
      fullName: user['fullName'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
      email: user['email'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      status: user['status'] as String?,
      ratingAvg: json['ratingAvg'] != null ? _toDouble(json['ratingAvg']) : null,
      vehicles: vehiclesJson
          .whereType<Map<String, dynamic>>()
          .map(Vehicle.fromJson)
          .toList(),
    );
  }

  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String? status;
  final double? ratingAvg;
  final List<Vehicle> vehicles;

  String get ratingLabel {
    if (ratingAvg == null || ratingAvg! <= 0) return '—';
    return ratingAvg!.toStringAsFixed(1);
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.plateNumber,
    this.vehicleType = 'car',
    this.transmission,
    this.fuelType,
    this.color,
    this.engineCapacity,
    this.photoUrl,
    this.isDefault = false,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        vehicleType: (json['vehicleType'] as String?) ?? 'car',
        make: json['make'] as String,
        model: json['model'] as String,
        year: (json['year'] as num).toInt(),
        plateNumber: (json['plateNumber'] as String).toUpperCase(),
        transmission: json['transmission'] as String?,
        fuelType: json['fuelType'] as String?,
        color: json['color'] as String?,
        engineCapacity: json['engineCapacity'] as String?,
        photoUrl: json['photoUrl'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  final String id;
  final String vehicleType;
  final String make;
  final String model;
  final int year;
  final String plateNumber;
  final String? transmission;
  final String? fuelType;
  final String? color;
  final String? engineCapacity;
  final String? photoUrl;
  final bool isDefault;

  String get displayName => '$year $make $model';
}

class ServiceCategory {
  ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.businessType = 'taxi',
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) =>
      ServiceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        businessType: json['businessType'] as String? ?? 'taxi',
      );

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String businessType;
}

class FareEstimate {
  FareEstimate({
    required this.estimatedFare,
    required this.distanceKm,
    this.durationMin = 0,
    this.pricingRuleId,
  });

  factory FareEstimate.fromJson(Map<String, dynamic> json) => FareEstimate(
        estimatedFare: _toDouble(json['estimatedFare']),
        distanceKm: _toDouble(json['distanceKm']),
        durationMin: json['durationMin'] == null ? 0 : _toDouble(json['durationMin']).round(),
        pricingRuleId: json['pricingRuleId'] as String?,
      );

  final double estimatedFare;
  final double distanceKm;
  final int durationMin;
  final String? pricingRuleId;
}

class JobModel {
  JobModel({
    required this.id,
    required this.jobNumber,
    required this.status,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.estimatedFare,
    this.finalFare,
    this.customerNotes,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.paymentStatus,
    this.customerStartConfirmedAt,
    this.providerStartConfirmedAt,
    this.serviceCategory,
    this.vehicle,
    this.provider,
    this.jobType = 'taxi',
    this.offeredPrice,
    this.recipientName,
    this.recipientPhone,
    this.parcelSize,
    this.recipientOtp,
    this.pickupPhotoUrl,
    this.dropoffPhotoUrl,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) => JobModel(
        id: json['id'] as String,
        jobNumber: json['jobNumber'] as String,
        status: json['status'] as String,
        pickupAddress: json['pickupAddress'] as String? ?? '',
        pickupLat: _toDouble(json['pickupLat']),
        pickupLng: _toDouble(json['pickupLng']),
        dropoffAddress: json['dropoffAddress'] as String?,
        dropoffLat: json['dropoffLat'] != null ? _toDouble(json['dropoffLat']) : null,
        dropoffLng: json['dropoffLng'] != null ? _toDouble(json['dropoffLng']) : null,
        estimatedFare: json['estimatedFare'] != null
            ? _toDouble(json['estimatedFare'])
            : null,
        finalFare:
            json['finalFare'] != null ? _toDouble(json['finalFare']) : null,
        customerNotes: json['customerNotes'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse('${json['completedAt']}')
            : null,
        cancelledAt: json['cancelledAt'] != null
            ? DateTime.tryParse('${json['cancelledAt']}')
            : null,
        paymentStatus: json['payment'] is Map
            ? '${(json['payment'] as Map)['status'] ?? ''}'.trim().toLowerCase()
            : null,
        customerStartConfirmedAt: json['customerStartConfirmedAt'] != null
            ? DateTime.tryParse(json['customerStartConfirmedAt'] as String)
            : null,
        providerStartConfirmedAt: json['providerStartConfirmedAt'] != null
            ? DateTime.tryParse(json['providerStartConfirmedAt'] as String)
            : null,
        serviceCategory: json['serviceCategory'] is Map<String, dynamic>
            ? ServiceCategory.fromJson(
                json['serviceCategory'] as Map<String, dynamic>,
              )
            : null,
        vehicle: json['vehicle'] is Map<String, dynamic>
            ? Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>)
            : null,
        provider: json['provider'] is Map
            ? ProviderSummary.fromJson(
                Map<String, dynamic>.from(json['provider'] as Map),
              )
            : null,
        jobType: json['jobType'] as String? ?? 'taxi',
        offeredPrice: json['offeredPrice'] != null ? _toDouble(json['offeredPrice']) : null,
        recipientName: json['recipientName'] as String?,
        recipientPhone: json['recipientPhone'] as String?,
        parcelSize: json['parcelSize'] as String?,
        recipientOtp: json['recipientOtp'] as String?,
        pickupPhotoUrl: json['pickupPhotoUrl'] as String?,
        dropoffPhotoUrl: json['dropoffPhotoUrl'] as String?,
      );

  final String id;
  final String jobNumber;
  final String status;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? estimatedFare;
  final double? finalFare;
  final String? customerNotes;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// `pending`, `held`, `paid`, `failed`, or `refunded` when the job includes payment.
  final String? paymentStatus;
  final DateTime? customerStartConfirmedAt;
  final DateTime? providerStartConfirmedAt;
  final ServiceCategory? serviceCategory;
  final Vehicle? vehicle;
  final ProviderSummary? provider;
  final String jobType;
  final double? offeredPrice;
  final String? recipientName;
  final String? recipientPhone;
  final String? parcelSize;
  final String? recipientOtp;
  final String? pickupPhotoUrl;
  final String? dropoffPhotoUrl;

  double get displayFare => finalFare ?? estimatedFare ?? offeredPrice ?? 0;
}

class JobBidModel {
  JobBidModel({
    required this.id,
    required this.amount,
    required this.kind,
    required this.status,
    this.providerName,
    this.ratingAvg,
  });

  factory JobBidModel.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'] is Map ? json['provider'] as Map : null;
    final user = provider?['user'] is Map ? provider!['user'] as Map : null;
    return JobBidModel(
      id: json['id'] as String,
      amount: _toDouble(json['amount']),
      kind: json['kind'] as String? ?? 'accept',
      status: json['status'] as String? ?? 'pending',
      providerName: user?['fullName'] as String?,
      ratingAvg: provider?['ratingAvg'] != null ? _toDouble(provider!['ratingAvg']) : null,
    );
  }

  final String id;
  final double amount;
  final String kind;
  final String status;
  final String? providerName;
  final double? ratingAvg;
}

class ProviderSummary {
  ProviderSummary({
    this.fullName,
    this.ratingAvg,
    this.phone,
    this.currentLat,
    this.currentLng,
  });

  factory ProviderSummary.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ProviderSummary(
      fullName: user?['fullName'] as String?,
      phone: user?['phone'] as String?,
      ratingAvg: json['ratingAvg'] != null
          ? _toDouble(json['ratingAvg'])
          : null,
      currentLat: json['currentLat'] != null ? _toDouble(json['currentLat']) : null,
      currentLng: json['currentLng'] != null ? _toDouble(json['currentLng']) : null,
    );
  }

  final String? fullName;
  final double? ratingAvg;
  final String? phone;
  final double? currentLat;
  final double? currentLng;
}

class WalletBalance {
  WalletBalance({required this.balance, this.currency = 'GBP'});

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
        balance: _toDouble(json['balance']),
        currency: json['currency'] as String? ?? 'GBP',
      );

  final double balance;
  final String currency;
}

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: _toDouble(json['amount']),
        balanceAfter: _toDouble(json['balanceAfter']),
        description: json['description'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  final String id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? description;
  final DateTime? createdAt;

  bool get isCredit =>
      type == 'top_up' || type == 'refund' || type == 'admin_adjustment';
}

class NearbyProvider {
  NearbyProvider({
    required this.id,
    required this.fullName,
    this.lat,
    this.lng,
    this.ratingAvg,
    this.distanceKm,
    this.etaMinutes,
  });

  factory NearbyProvider.fromJson(Map<String, dynamic> json) => NearbyProvider(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? 'Driver',
        lat: json['lat'] != null ? _toDouble(json['lat']) : null,
        lng: json['lng'] != null ? _toDouble(json['lng']) : null,
        ratingAvg: json['ratingAvg'] != null ? _toDouble(json['ratingAvg']) : null,
        distanceKm: json['distanceKm'] != null ? _toDouble(json['distanceKm']) : null,
        etaMinutes: json['etaMinutes'] != null ? (json['etaMinutes'] as num).toInt() : null,
      );

  final String id;
  final String fullName;
  final double? lat;
  final double? lng;
  final double? ratingAvg;
  final double? distanceKm;
  final int? etaMinutes;
}

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'info',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;
}

class OtpSendResult {
  OtpSendResult({this.message, this.debugCode});

  factory OtpSendResult.fromJson(Map<String, dynamic> json) => OtpSendResult(
        message: json['message'] as String?,
        debugCode: json['debugCode'] as String?,
      );

  final String? message;
  final String? debugCode;
}

/// A country enabled by the admin for registration/login (phone dial code + flag).
class Country {
  Country({
    required this.name,
    required this.code,
    required this.code3,
    required this.numeric,
    required this.dialCode,
    required this.icon,
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        code3: json['code3'] as String? ?? '',
        numeric: json['numeric'] as String? ?? '',
        dialCode: json['dialCode'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
      );

  final String name;
  final String code;
  final String code3;
  final String numeric;
  final String dialCode;
  final String icon;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String formatMoney(double amount) {
  final currency = ActiveCurrency.current;
  return '${currency.symbol}${amount.toStringAsFixed(currency.decimals)}';
}

String formatJobStatus(String status) {
  return switch (status) {
    'searching' => 'Finding a driver',
    'matched' => 'Driver assigned',
    'provider_en_route' => 'Driver on the way',
    'arrived' => 'Driver arrived',
    'in_progress' => 'Trip in progress',
    'completed' => 'Trip complete',
    'cancelled_by_customer' => 'Cancelled',
    'cancelled_by_provider' => 'Cancelled',
    'cancelled_by_admin' => 'Cancelled',
    'no_provider_found' => 'No driver',
    'payment_pending' => 'Payment Pending',
    _ => status,
  };
}
