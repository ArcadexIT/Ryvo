import 'dart:io';

import '../../core/network/api_client.dart';
import '../../core/network/token_storage.dart';
import '../../core/services/vpic_vehicle_catalog_service.dart';
import '../../core/utils/phone_utils.dart';
import '../models/models.dart';
import '../models/support_models.dart';

class RegisterResult {
  const RegisterResult({this.tokens, this.verificationRequired = false});

  final AuthTokens? tokens;
  final bool verificationRequired;
}

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  Future<AuthTokens> login(String phone, String password) async {
    final tokens = await _api.post<AuthTokens>(
      '/customer/auth/login',
      data: {'phone': normalizePhone(phone), 'password': password},
      parser: (json) => AuthTokens.fromJson(json as Map<String, dynamic>),
    );
    await _persist(tokens);
    return tokens;
  }

  Future<RegisterResult> register({
    required String phone,
    required String password,
    required String fullName,
    String? email,
    bool acceptedTerms = false,
  }) async {
    final result = await _api.post<RegisterResult>(
      '/customer/auth/register',
      data: {
        'phone': normalizePhone(phone),
        'password': password,
        'fullName': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        'acceptedTerms': acceptedTerms,
      },
      parser: (json) {
        final map = Map<String, dynamic>.from(json as Map);
        if (map['accessToken'] is String && map['refreshToken'] is String) {
          return RegisterResult(tokens: AuthTokens.fromJson(map));
        }
        return const RegisterResult(verificationRequired: true);
      },
    );
    final tokens = result.tokens;
    if (tokens != null) await _persist(tokens);
    return result;
  }

  Future<OtpSendResult> sendOtp(String phone, String purpose) => _api.post(
        '/customer/auth/otp/send',
        data: {'phone': normalizePhone(phone), 'purpose': purpose},
        parser: (json) => OtpSendResult.fromJson(json as Map<String, dynamic>),
      );

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) =>
      _api.post(
        '/customer/auth/password/reset',
        data: {
          'phone': normalizePhone(phone),
          'code': code,
          'newPassword': newPassword,
        },
      );

  Future<AuthTokens> verifyOtp(
    String phone,
    String code,
    String purpose,
  ) async {
    final tokens = await _api.post<AuthTokens>(
      '/customer/auth/otp/verify',
      data: {
        'phone': normalizePhone(phone),
        'code': code,
        'purpose': purpose,
      },
      parser: (json) => AuthTokens.fromJson(json as Map<String, dynamic>),
    );
    await _persist(tokens);
    return tokens;
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.post(
          '/customer/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      } catch (_) {}
    }
    await _tokenStorage.clear();
  }

  Future<bool> hasSession() async {
    final refresh = await _tokenStorage.getRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }

  /// Proactively refresh the access token when a refresh token is stored.
  Future<bool> refreshAccessToken() async {
    if (!await hasSession()) return false;
    return _api.refreshSession();
  }

  Future<void> _persist(AuthTokens tokens) => _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
}

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserProfile> getProfile() => _api.get(
        '/customer/profile',
        parser: (json) => UserProfile.fromJson(json as Map<String, dynamic>),
      );

  Future<UserProfile> updateProfile({
    String? fullName,
    String? email,
  }) async {
    await _api.patch(
      '/customer/profile',
      data: {
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
      },
    );
    return getProfile();
  }
}

class VehicleRepository {
  VehicleRepository(this._api, {VpicVehicleCatalogService? catalog})
      : _catalog = catalog ?? VpicVehicleCatalogService();

  final ApiClient _api;
  final VpicVehicleCatalogService _catalog;

  Future<List<Vehicle>> list() async {
    final data = await _api.get<dynamic>('/customer/vehicles');
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Vehicle.fromJson)
        .toList();
  }

  Future<Vehicle> getById(String id) => _api.get(
        '/customer/vehicles/$id',
        parser: (json) => Vehicle.fromJson(json as Map<String, dynamic>),
      );

  Future<Vehicle> create({
    required String vehicleType,
    required String make,
    required String model,
    required int year,
    required String plateNumber,
    required String transmission,
    required String fuelType,
    String? color,
    String? engineCapacity,
    String? photoUrl,
    bool isDefault = true,
  }) =>
      _api.post(
        '/customer/vehicles',
        data: {
          'vehicleType': vehicleType,
          'make': make,
          'model': model,
          'year': year,
          'plateNumber': plateNumber,
          'transmission': transmission,
          'fuelType': fuelType,
          if (color != null) 'color': color,
          if (engineCapacity != null) 'engineCapacity': engineCapacity,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'isDefault': isDefault,
        },
        parser: (json) => Vehicle.fromJson(json as Map<String, dynamic>),
      );

  Future<Vehicle> update(
    String id, {
    String? vehicleType,
    String? make,
    String? model,
    int? year,
    String? plateNumber,
    String? transmission,
    String? fuelType,
    String? color,
    String? engineCapacity,
    String? photoUrl,
    bool? isDefault,
  }) =>
      _api.patch(
        '/customer/vehicles/$id',
        data: {
          if (vehicleType != null) 'vehicleType': vehicleType,
          if (make != null) 'make': make,
          if (model != null) 'model': model,
          if (year != null) 'year': year,
          if (plateNumber != null) 'plateNumber': plateNumber,
          if (transmission != null) 'transmission': transmission,
          if (fuelType != null) 'fuelType': fuelType,
          if (color != null) 'color': color,
          if (engineCapacity != null) 'engineCapacity': engineCapacity,
          if (photoUrl != null) 'photoUrl': photoUrl,
          if (isDefault != null) 'isDefault': isDefault,
        },
        parser: (json) => Vehicle.fromJson(json as Map<String, dynamic>),
      );

  Future<List<String>> fetchMakes(String vehicleType) =>
      _catalog.fetchMakes(vehicleType);

  Future<List<String>> fetchModels(String vehicleType, String make) =>
      _catalog.fetchModels(vehicleType, make);

  /// Upload a vehicle photo file and return the resulting [fileUrl].
  Future<String> uploadVehiclePhoto(File file) async {
    final result = await _api.uploadFile(
      '/customer/files/upload',
      file,
      'vehicles',
    );
    final url = result['fileUrl'] as String?;
    if (url == null || url.isEmpty) throw Exception('Upload failed: no fileUrl returned');
    return url;
  }
}

class ServiceRepository {
  ServiceRepository(this._api);

  final ApiClient _api;

  Future<List<ServiceCategory>> list({String? businessType}) async {
    final data = await _api.get<dynamic>(
      '/customer/services',
      queryParameters: {
        if (businessType != null) 'businessType': businessType,
      },
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ServiceCategory.fromJson)
        .toList();
  }
}

/// Public reference data — no auth required, safe to call from login/register.
class CountryRepository {
  CountryRepository(this._api);

  final ApiClient _api;

  Future<List<Country>> list() async {
    final data = await _api.get<dynamic>('/countries');
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(Country.fromJson).toList();
  }
}

class JobRepository {
  JobRepository(this._api);

  final ApiClient _api;

  Future<FareEstimate> estimateFare({
    required String serviceCategoryId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) =>
      _api.post(
        '/customer/jobs/estimate-fare',
        data: {
          'serviceCategoryId': serviceCategoryId,
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'dropoffLat': dropoffLat,
          'dropoffLng': dropoffLng,
        },
        parser: (json) => FareEstimate.fromJson(json as Map<String, dynamic>),
      );

  Future<JobModel> createJob({
    String? vehicleId,
    required String serviceCategoryId,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String dropoffAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String paymentMethod,
    String? stripePaymentMethodId,
    String? customerNotes,
    String bookingType = 'instant',
    DateTime? scheduledAt,
    String jobType = 'taxi',
    double? offeredPrice,
    String? recipientName,
    String? recipientPhone,
    String? parcelSize,
    String? parcelNotes,
  }) =>
      _api.post(
        '/customer/jobs',
        data: {
          if (vehicleId != null) 'vehicleId': vehicleId,
          'serviceCategoryId': serviceCategoryId,
          'pickupAddress': pickupAddress,
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'dropoffAddress': dropoffAddress,
          'dropoffLat': dropoffLat,
          'dropoffLng': dropoffLng,
          'paymentMethod': paymentMethod,
          if (stripePaymentMethodId != null) 'stripePaymentMethodId': stripePaymentMethodId,
          if (customerNotes != null && customerNotes.isNotEmpty)
            'customerNotes': customerNotes,
          'bookingType': bookingType,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          'jobType': jobType,
          if (offeredPrice != null) 'offeredPrice': offeredPrice,
          if (recipientName != null) 'recipientName': recipientName,
          if (recipientPhone != null) 'recipientPhone': recipientPhone,
          if (parcelSize != null) 'parcelSize': parcelSize,
          if (parcelNotes != null) 'parcelNotes': parcelNotes,
        },
        parser: (json) => JobModel.fromJson(json as Map<String, dynamic>),
      );

  Future<List<JobModel>> list({int page = 1, int limit = 20}) async {
    final data = await _api.get<dynamic>(
      '/customer/jobs',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(JobModel.fromJson)
        .toList();
  }

  /// Returns the customer's in-progress job, or null if none is active.
  Future<JobModel?> fetchActiveJob() async {
    try {
      final data = await _api.get<dynamic>('/customer/jobs/active');
      if (data is! Map<String, dynamic>) return null;
      return JobModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<JobModel> getJob(String id) => _api.get(
        '/customer/jobs/$id',
        parser: (json) => JobModel.fromJson(json as Map<String, dynamic>),
      );

  Future<List<JobBidModel>> listBids(String jobId) async {
    final data = await _api.get<dynamic>('/customer/jobs/$jobId/bids');
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => JobBidModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<JobModel> acceptBid(String jobId, String bidId) => _api.post(
        '/customer/jobs/$jobId/bids/$bidId/accept',
        parser: (json) => JobModel.fromJson(json as Map<String, dynamic>),
      );

  Future<JobModel> confirmJobStart(String id) => _api.post(
        '/customer/jobs/$id/confirm-start',
        parser: (json) => JobModel.fromJson(json as Map<String, dynamic>),
      );

  Future<JobModel> cancelJob(String id, {String? reason}) => _api.patch(
        '/customer/jobs/$id/cancel',
        data: {if (reason != null) 'reason': reason},
        parser: (json) => JobModel.fromJson(json as Map<String, dynamic>),
      );

  Future<({String url, bool reused})> shareTrip(String id) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/customer/jobs/$id/share',
      parser: (json) => Map<String, dynamic>.from(json as Map),
    );
    return (url: data['url'] as String, reused: data['reused'] == true);
  }

  Future<void> stopSharingTrip(String id) async {
    await _api.delete<dynamic>('/customer/jobs/$id/share');
  }

  Future<List<NearbyProvider>> nearbyProviders({
    required double lat,
    required double lng,
    double? radiusKm,
  }) async {
    final data = await _api.get<dynamic>(
      '/customer/providers/nearby',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        if (radiusKm != null) 'radiusKm': radiusKm,
      },
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(NearbyProvider.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> messages(String jobId) async {
    final data = await _api.get<dynamic>('/customer/jobs/$jobId/messages');
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> sendMessage(String jobId, String text) => _api.post(
        '/customer/jobs/$jobId/messages',
        data: {'text': text},
        parser: (json) => json as Map<String, dynamic>,
      );

  Future<void> rateJob(String jobId, int score, {String? comment}) => _api.post(
        '/customer/ratings',
        data: {
          'jobId': jobId,
          'score': score,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
        parser: (json) => json,
      );
}

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<List<NotificationItem>> list({int page = 1, int limit = 30}) async {
    final data = await _api.get<dynamic>(
      '/notifications',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  Future<void> markRead(String id) => _api.patch('/notifications/$id/read');

  Future<void> markAllRead() => _api.patch('/notifications/read-all');

  Future<void> registerFcmToken(String token) =>
      _api.post('/notifications/fcm-token', data: {
        'fcmToken': token,
        if (Platform.isIOS)
          'platform': 'ios'
        else if (Platform.isAndroid)
          'platform': 'android',
      });
}

class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  Future<WalletBalance> getBalance() => _api.get(
        '/customer/wallet/balance',
        parser: (json) => WalletBalance.fromJson(json as Map<String, dynamic>),
      );

  Future<List<WalletTransaction>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get<dynamic>(
      '/customer/wallet/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(WalletTransaction.fromJson)
        .toList();
  }

  Future<WalletBalance> topUp(double amount, {String? description}) async {
    await _api.post(
      '/customer/wallet/top-up',
      data: {
        'amount': amount,
        if (description != null) 'description': description,
      },
    );
    return getBalance();
  }
}

class PaymentRepository {
  PaymentRepository(this._api);

  final ApiClient _api;

  Future<void> payWithWallet(String jobId) async {
    await _api.post('/customer/payments/job/$jobId/wallet');
  }

  Future<void> payWithCash(String jobId) async {
    await _api.post('/customer/payments/job/$jobId/cash');
  }

  Future<void> confirmStripePayment(String jobId, {String? paymentIntentId}) =>
      _api.post(
        '/customer/payments/job/$jobId/confirm',
        data: {
          if (paymentIntentId != null) 'paymentIntentId': paymentIntentId,
        },
      );

  Future<Map<String, dynamic>> createSetupIntent() => _api.post(
        '/customer/payments/setup-intent',
        parser: (json) => json as Map<String, dynamic>,
      );

  Future<Map<String, dynamic>> createIntent(String jobId, double amount) =>
      _api.post(
        '/customer/payments/intent',
        data: {'jobId': jobId, 'amount': amount},
        parser: (json) => json as Map<String, dynamic>,
      );
}

class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<SupportTicket>> listTickets({int page = 1, int limit = 20}) async {
    final data = await _api.get<dynamic>(
      '/support/tickets',
      queryParameters: {'page': page, 'limit': limit},
    );
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }

  Future<SupportTicketDetail> getTicket(String id) => _api.get(
        '/support/tickets/$id',
        parser: (json) => SupportTicketDetail.fromJson(json as Map<String, dynamic>),
      );

  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    String? jobId,
    String? priority,
  }) =>
      _api.post(
        '/support/tickets',
        data: {
          'category': category,
          'subject': subject,
          'message': message,
          if (jobId != null) 'jobId': jobId,
          if (priority != null) 'priority': priority,
        },
        parser: (json) => SupportTicket.fromJson(json as Map<String, dynamic>),
      );

  Future<void> reply(String ticketId, String message) => _api.post(
        '/support/tickets/$ticketId/messages',
        data: {'message': message},
      );

  Future<List<Map<String, dynamic>>> listFaqs() async {
    final data = await _api.get<dynamic>('/customer/cms/faqs');
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().toList();
  }
}

class LegalDocument {
  const LegalDocument({
    required this.key,
    required this.title,
    required this.content,
    this.updatedAt,
  });

  final String key;
  final String title;
  final String content;
  final String? updatedAt;

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class LegalRepository {
  LegalRepository(this._api);

  final ApiClient _api;

  Future<LegalDocument> get(String key) => _api.get(
        '/legal/$key',
        parser: (json) => LegalDocument.fromJson(json as Map<String, dynamic>),
      );
}
