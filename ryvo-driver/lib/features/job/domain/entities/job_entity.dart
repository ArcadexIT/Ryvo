enum JobStatusEntity { incoming, paymentPending, accepted, navigating, arrived, inProgress, completed, declined, cancelled }

/// Customer's vehicle on a job. Providers use this to decide if they can take the request.
class JobVehicle {
  final String type;
  final String make;
  final String model;
  final int? year;
  final String plate;
  final String? transmission;
  final String? fuelType;
  final String? color;
  final String? engineCapacity;

  const JobVehicle({
    this.type = '',
    this.make = '',
    this.model = '',
    this.year,
    this.plate = '',
    this.transmission,
    this.fuelType,
    this.color,
    this.engineCapacity,
  });

  String get headline {
    return [
      if (year != null) '$year',
      if (make.trim().isNotEmpty) make.trim(),
      if (model.trim().isNotEmpty) model.trim(),
    ].join(' ');
  }

  bool get isBlank =>
      headline.isEmpty &&
      plate.trim().isEmpty &&
      type.trim().isEmpty &&
      (transmission?.trim().isEmpty ?? true) &&
      (fuelType?.trim().isEmpty ?? true) &&
      (color?.trim().isEmpty ?? true) &&
      (engineCapacity?.trim().isEmpty ?? true);
}

class JobEntity {
  final String id;
  final String customerName;
  final String jobType;
  final String distance;
  final double payout;
  final String vehicleInfo;
  final JobVehicle? vehicle;
  final String jobRef;
  final JobStatusEntity status;
  final double? customerLat;
  final double? customerLng;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? tripDistanceKm;
  final String? customerPhone;
  final DateTime? startedAt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DateTime? customerStartConfirmedAt;
  final DateTime? providerStartConfirmedAt;
  final double? providerDistanceKm;
  final int? etaMinutes;
  final DateTime? expiresAt;
  final String bookingMode;
  final String jobId;
  final double? offeredPrice;
  final bool isBidRequest;
  final String? recipientOtp;
  final String? parcelSize;
  final String? pickupPhotoUrl;
  final String? dropoffPhotoUrl;

  const JobEntity({
    required this.id,
    required this.customerName,
    required this.jobType,
    required this.distance,
    required this.payout,
    required this.vehicleInfo,
    this.vehicle,
    required this.jobRef,
    this.status = JobStatusEntity.incoming,
    this.customerLat,
    this.customerLng,
    this.pickupAddress,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.tripDistanceKm,
    this.customerPhone,
    this.startedAt,
    this.createdAt,
    this.completedAt,
    this.customerStartConfirmedAt,
    this.providerStartConfirmedAt,
    this.providerDistanceKm,
    this.etaMinutes,
    this.expiresAt,
    this.bookingMode = 'taxi',
    this.jobId = '',
    this.offeredPrice,
    this.isBidRequest = false,
    this.recipientOtp,
    this.parcelSize,
    this.pickupPhotoUrl,
    this.dropoffPhotoUrl,
  });
}
