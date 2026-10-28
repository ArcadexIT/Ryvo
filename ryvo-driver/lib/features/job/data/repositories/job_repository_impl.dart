import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/provider_socket.dart';
import '../../../../core/utils/travel_estimate.dart';
import '../../domain/entities/job_entity.dart';
import '../../domain/repositories/i_job_repository.dart';

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

double? _positiveKm(dynamic v) {
  if (v == null) return null;
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  if (n == null || n <= 0) return null;
  return n;
}

int? _positiveInt(dynamic v) {
  if (v == null) return null;
  final n = v is num ? v.round() : int.tryParse('$v');
  if (n == null || n <= 0) return null;
  return n;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

JobStatusEntity _statusFromString(String? s) {
  switch (s) {
    case 'searching':
      return JobStatusEntity.incoming;
    case 'payment_pending':
      return JobStatusEntity.paymentPending;
    case 'matched':
      return JobStatusEntity.accepted;
    case 'provider_en_route':
      return JobStatusEntity.navigating;
    case 'arrived':
      return JobStatusEntity.arrived;
    case 'in_progress':
      return JobStatusEntity.inProgress;
    case 'completed':
      return JobStatusEntity.completed;
    case 'cancelled_by_customer':
    case 'cancelled_by_provider':
    case 'cancelled_by_admin':
      return JobStatusEntity.cancelled;
    default:
      return JobStatusEntity.incoming;
  }
}

String? _clean(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

JobVehicle? _vehicleFromJson(Map<String, dynamic>? vehicle) {
  if (vehicle == null) return null;
  final yearRaw = vehicle['year'];
  final year = yearRaw is num ? yearRaw.toInt() : int.tryParse('${yearRaw ?? ''}');
  final parsed = JobVehicle(
    type: _clean(vehicle['vehicleType']) ?? '',
    make: _clean(vehicle['make']) ?? '',
    model: _clean(vehicle['model']) ?? '',
    year: year,
    plate: (_clean(vehicle['plateNumber']) ?? '').toUpperCase(),
    transmission: _clean(vehicle['transmission']),
    fuelType: _clean(vehicle['fuelType']),
    color: _clean(vehicle['color']),
    engineCapacity: _clean(vehicle['engineCapacity']),
  );
  return parsed.isBlank ? null : parsed;
}

String _statusToString(JobStatusEntity s) {
  switch (s) {
    case JobStatusEntity.navigating:
      return 'provider_en_route';
    case JobStatusEntity.arrived:
      return 'arrived';
    case JobStatusEntity.inProgress:
      return 'in_progress';
    case JobStatusEntity.completed:
      return 'completed';
    default:
      return s.name;
  }
}

JobEntity _jobFromJson(Map<String, dynamic> data, {String? overrideId, DateTime? expiresAt}) {
  final sc = (data['serviceCategory'] as Map?)?.cast<String, dynamic>();
  final vehicle = (data['vehicle'] as Map?)?.cast<String, dynamic>();
  final customerUser =
      ((data['customer'] as Map?)?['user'] as Map?)?.cast<String, dynamic>();
  final earning = (data['providerEarning'] as Map?)?.cast<String, dynamic>();
  final travelKm = _positiveKm(data['providerDistanceKm']);
  final etaMinutes = _positiveInt(data['etaMinutes']);
  final parsedVehicle = _vehicleFromJson(vehicle);
  final vehicleLabel = parsedVehicle == null
      ? ''
      : [
          parsedVehicle.headline,
          if (parsedVehicle.plate.isNotEmpty) parsedVehicle.plate,
        ].where((s) => s.trim().isNotEmpty).join(' • ');

  final netEarning = earning?['netAmount'];
  final payout = netEarning != null
      ? _toD(netEarning)
      : _toD(data['finalFare'] ?? data['estimatedFare']);

  return JobEntity(
    id: overrideId ?? data['id'] as String? ?? '',
    customerName: (data['riderFirstName'] as String?) ??
        (data['customerName'] as String?) ??
        (customerUser?['fullName'] as String?) ??
        'Rider',
    jobType: sc?['name'] as String? ?? 'Ride',
    distance: travelKm != null ? formatDistanceKm(travelKm) : '',
    providerDistanceKm: travelKm,
    etaMinutes: etaMinutes,
    payout: payout,
    vehicleInfo: vehicleLabel,
    vehicle: parsedVehicle,
    jobRef: data['jobNumber'] as String? ?? '',
    status: _statusFromString(data['status'] as String?),
    customerLat: _toD(data['pickupLat']),
    customerLng: _toD(data['pickupLng']),
    pickupAddress: data['pickupAddress'] as String?,
    dropoffAddress: data['dropoffAddress'] as String?,
    dropoffLat: data['dropoffLat'] != null ? _toD(data['dropoffLat']) : null,
    dropoffLng: data['dropoffLng'] != null ? _toD(data['dropoffLng']) : null,
    tripDistanceKm: _positiveKm(data['tripDistanceKm'] ?? data['distanceKm']),
    customerPhone: customerUser?['phone'] as String?,
    startedAt: data['startedAt'] != null
        ? DateTime.tryParse(data['startedAt'] as String)
        : null,
    createdAt: data['createdAt'] != null
        ? DateTime.tryParse(data['createdAt'] as String)
        : null,
    completedAt: data['completedAt'] != null
        ? DateTime.tryParse(data['completedAt'] as String)
        : null,
    customerStartConfirmedAt: data['customerStartConfirmedAt'] != null
        ? DateTime.tryParse(data['customerStartConfirmedAt'] as String)
        : null,
    providerStartConfirmedAt: data['providerStartConfirmedAt'] != null
        ? DateTime.tryParse(data['providerStartConfirmedAt'] as String)
        : null,
    expiresAt: expiresAt ?? _parseDate(data['expiresAt']),
    bookingMode: data['jobType'] as String? ?? 'taxi',
    jobId: data['id'] as String? ?? overrideId ?? '',
    offeredPrice: data['offeredPrice'] != null ? _toD(data['offeredPrice']) : null,
    isBidRequest: data['jobType'] == 'bidding',
    recipientOtp: data['recipientOtp'] as String?,
    parcelSize: data['parcelSize'] as String?,
    pickupPhotoUrl: data['pickupPhotoUrl'] as String?,
    dropoffPhotoUrl: data['dropoffPhotoUrl'] as String?,
  );
}

class JobRemoteDataSource {
  JobRemoteDataSource(this._dio, this._socket);
  final Dio _dio;
  final ProviderSocket _socket;

  dynamic _data(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<JobEntity?> fetchTopOffer() async {
    final res = await _dio.get('/provider/offers');
    final list = _data(res);
    if (list is List && list.isNotEmpty) {
      final offer = (list.first as Map).cast<String, dynamic>();
      final job = (offer['job'] as Map).cast<String, dynamic>();
      if (job['status'] == 'searching') {
        return _jobFromJson(
          job,
          overrideId: offer['id'] as String?,
          expiresAt: _parseDate(offer['expiresAt']),
        );
      }
    }
    final bidsRes = await _dio.get('/provider/bids/open');
    final bids = _data(bidsRes);
    if (bids is! List || bids.isEmpty) return null;
    final job = (bids.first as Map).cast<String, dynamic>();
    if (job['status'] != 'searching') return null;
    return _jobFromJson(job, expiresAt: DateTime.now().add(const Duration(seconds: 120)));
  }

  Future<JobEntity?> fetchActive() async {
    final res = await _dio.get('/provider/jobs/active');
    final data = _data(res);
    if (data is! Map) {
      _socket.setActiveJob(null);
      return null;
    }
    final job = _jobFromJson(data.cast<String, dynamic>());
    // Scope live location to this job so the customer receives updates.
    _socket.setActiveJob(job.id);
    return job;
  }

  /// Incoming offers via WebSocket, with REST polling every 3s as fallback
  /// (needed when the app is backgrounded on the same device as the customer app).
  Stream<JobEntity?> watchIncomingJob() {
    StreamSubscription<Map<String, dynamic>>? socketSub;
    Timer? pollTimer;

    return Stream<JobEntity?>.multi((controller) async {
      Future<void> emitLatest() async {
        try {
          controller.add(await fetchTopOffer());
        } catch (_) {
          controller.add(null);
        }
      }

      await emitLatest();

      socketSub = _socket.onIncomingJob.listen((payload) {
        final job = (payload['job'] as Map?)?.cast<String, dynamic>();
        if (job != null && job['status'] == 'searching') {
          controller.add(_jobFromJson(
            job,
            overrideId: payload['offerId'] as String?,
            expiresAt: _parseDate(payload['expiresAt']),
          ));
        }
      });

      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => emitLatest());

      controller.onCancel = () async {
        await socketSub?.cancel();
        pollTimer?.cancel();
      };
    });
  }

  Stream<JobEntity?> watchActiveJob() async* {
    try {
      yield await fetchActive();
    } catch (_) {
      yield null;
    }
    await for (final _ in _socket.onJobStatus) {
      try {
        yield await fetchActive();
      } catch (_) {}
    }
  }

  Future<JobEntity> acceptOffer(String offerId) async {
    try {
      final res = await _dio.post('/provider/offers/$offerId/accept');
      final active = await fetchActive();
      if (active != null) return active;
      final data = _data(res);
      return _jobFromJson((data as Map).cast<String, dynamic>());
    } catch (_) {
      await _dio.post('/provider/jobs/$offerId/bids', data: {
        'kind': 'accept',
        'amount': 1,
      });
      final active = await fetchActive();
      if (active != null) return active;
      throw Exception('Waiting for the rider to accept your bid');
    }
  }

  Future<void> rejectOffer(String offerId, {JobEntity? incoming}) async {
    if (incoming?.isBidRequest == true) return;
    await _dio.post('/provider/offers/$offerId/reject');
  }

  Future<void> counterBid(String jobId, double amount) async {
    await _dio.post('/provider/jobs/$jobId/bids', data: {
      'kind': 'counter',
      'amount': amount,
    });
  }

  Future<void> uploadParcelPickup(String jobId, String fileUrl) async {
    await _dio.post('/provider/jobs/$jobId/parcel/pickup-photo', data: {'fileUrl': fileUrl});
  }

  Future<void> deliverParcel(String jobId, {String? fileUrl, String? otp}) async {
    await _dio.post('/provider/jobs/$jobId/parcel/deliver', data: {
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (otp != null) 'otp': otp,
    });
  }

  Future<void> updateStatus(String jobId, JobStatusEntity status) async {
    await _dio.patch('/provider/jobs/$jobId/status', data: {'status': _statusToString(status)});
  }

  Future<JobEntity> confirmJobStart(String jobId) async {
    final res = await _dio.post('/provider/jobs/$jobId/confirm-start');
    final data = _data(res);
    if (data is Map) return _jobFromJson(data.cast<String, dynamic>());
    final active = await fetchActive();
    if (active != null) return active;
    throw Exception('Could not confirm job start');
  }

  Future<void> cancelJob(String jobId, {String? reason}) async {
    await _dio.patch('/provider/jobs/$jobId/cancel', data: {
      if (reason != null) 'reason': reason,
    });
  }

  Future<JobEntity?> fetchJobDetail(String jobId) async {
    final res = await _dio.get('/provider/jobs/$jobId');
    final data = _data(res);
    if (data is! Map) return null;
    return _jobFromJson(data.cast<String, dynamic>());
  }
}

class JobRepositoryImpl implements IJobRepository {
  JobRepositoryImpl(this._remote);
  final JobRemoteDataSource _remote;

  @override
  Stream<JobEntity?> watchIncomingJob() => _remote.watchIncomingJob();

  @override
  Stream<JobEntity?> watchActiveJob() => _remote.watchActiveJob();

  @override
  Future<JobEntity?> fetchActiveJob() => _remote.fetchActive();

  @override
  Future<JobEntity?> fetchJobDetail(String jobId) => _remote.fetchJobDetail(jobId);

  @override
  Future<Either<Failure, JobEntity>> acceptJob(String jobId) async {
    try {
      return Right(await _remote.acceptOffer(jobId)); // incoming id is offer id or job id
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> declineJob(String jobId) async {
    try {
      await _remote.rejectOffer(jobId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateJobStatus(String jobId, JobStatusEntity status) async {
    try {
      await _remote.updateStatus(jobId, status);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, JobEntity>> confirmJobStart(String jobId) async {
    try {
      return Right(await _remote.confirmJobStart(jobId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelJob(String jobId, {String? reason}) async {
    try {
      await _remote.cancelJob(jobId, reason: reason);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> counterBid(String jobId, double amount) async {
    try {
      await _remote.counterBid(jobId, amount);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> uploadParcelPickup(String jobId, String fileUrl) async {
    try {
      await _remote.uploadParcelPickup(jobId, fileUrl);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deliverParcel(String jobId, {String? fileUrl, String? otp}) async {
    try {
      await _remote.deliverParcel(jobId, fileUrl: fileUrl, otp: otp);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
