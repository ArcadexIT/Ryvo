import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firebase_initializer.dart';
import '../../core/utils/travel_estimate.dart';
import '../../core/network/push_messaging.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/provider_entity.dart';
import '../../features/job/domain/entities/job_entity.dart';
import '../models/country_entity.dart';
import '../models/app_config.dart';
import 'di_providers.dart';
import 'notifiers/location_notifier.dart';
import '../../features/support/domain/support_entities.dart';
import '../../features/support/data/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.read(dioClientProvider).dio);
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  return ref.read(supportRepositoryProvider).listTickets();
});

final isAuthenticatedProvider = StateProvider<bool>((ref) => false);
final isKycApprovedProvider = StateProvider<bool>((ref) => false);
/// Required documents are uploaded and waiting for admin approval.
final isKycInReviewProvider = StateProvider<bool>((ref) => false);
/// True when the provider has accepted the current agreement version.
/// Defaults to true so legacy APIs (no agreement gate) are not blocked before sync.
final isAgreementAcceptedProvider = StateProvider<bool>((ref) => true);
final isOnlineProvider = StateProvider<bool>((ref) => false);
final showIncomingJobProvider = StateProvider<bool>((ref) => false);

/// Offer id whose countdown already finished. Polling must not open it again.
final dismissedIncomingOfferIdProvider = StateProvider<String?>((ref) => null);

/// Whether this offer should still be shown. A missing expiry uses the server default window.
bool incomingOfferIsOpen(JobEntity? job, String? dismissedOfferId) {
  if (job == null || job.id.isEmpty) return false;
  if (job.id == dismissedOfferId) return false;
  final expiresAt = job.expiresAt;
  if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) return false;
  return true;
}
final selectedRatingProvider = StateProvider<int>((ref) => 0);

/// Phone number carried between register/reset and the OTP screen.
final pendingPhoneProvider = StateProvider<String?>((ref) => null);

/// Purpose of the current OTP flow: 'register' or 'reset_password'.
final otpPurposeProvider = StateProvider<String>((ref) => 'register');

class MockJob {
  final String id;
  final String customerName;
  final String jobType;
  final String serviceDescription;
  final String distance;
  final String eta;
  final String address;
  final String? dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String tripDistance;
  final String? customerPhone;
  final double rating;
  final double payout;
  final String vehicleInfo;
  final JobVehicle? vehicle;
  final String jobRef;
  final bool isHighPriority;
  final double? customerLat;
  final double? customerLng;
  final JobStatusEntity status;
  final DateTime? startedAt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String bookingMode;

  const MockJob({
    required this.id,
    required this.customerName,
    required this.jobType,
    required this.serviceDescription,
    required this.distance,
    required this.eta,
    required this.address,
    this.dropoffAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.tripDistance = '',
    required this.rating,
    required this.payout,
    required this.vehicleInfo,
    this.vehicle,
    required this.jobRef,
    this.isHighPriority = true,
    this.customerLat,
    this.customerLng,
    this.customerPhone,
    this.status = JobStatusEntity.incoming,
    this.startedAt,
    this.createdAt,
    this.completedAt,
    this.customerStartConfirmedAt,
    this.providerStartConfirmedAt,
    this.bookingMode = 'taxi',
  });

  final DateTime? customerStartConfirmedAt;
  final DateTime? providerStartConfirmedAt;
}

final activeJobProvider = StateProvider<MockJob?>((ref) => null);

const mockIncomingJob = MockJob(
  id: 'job-001',
  customerName: 'Customer',
  jobType: 'Ryvo Go',
  serviceDescription: 'Pickup to dropoff',
  distance: '1.2 km',
  eta: '4 mins',
  address: '221 Baker Street, London NW1 6XE',
  dropoffAddress: '10 Downing Street, London',
  tripDistance: '3.4 km',
  rating: 4.7,
  payout: 18.50,
  vehicleInfo: '2020 Toyota Camry • ABC-1234',
  vehicle: JobVehicle(
    type: 'car',
    make: 'Toyota',
    model: 'Camry',
    year: 2020,
    plate: 'ABC-1234',
    transmission: 'auto',
    fuelType: 'petrol',
    color: 'White',
    engineCapacity: '2.5',
  ),
  jobRef: 'JMP-2847',
);

/// Map a real backend job into the display model used by the existing UI.
/// Pass the provider's live position so distance and ETA are to the pickup,
/// not the job's stored trip length (0 when there is no drop-off).
MockJob mockJobFromEntity(
  JobEntity e, {
  double? providerLat,
  double? providerLng,
}) {
  final hasAddress = e.pickupAddress != null && e.pickupAddress!.trim().isNotEmpty;
  final travel = travelEstimateFor(
    pickupLat: e.customerLat,
    pickupLng: e.customerLng,
    providerLat: providerLat,
    providerLng: providerLng,
    serverDistanceKm: e.providerDistanceKm,
    serverEtaMinutes: e.etaMinutes,
  );
  return MockJob(
    id: e.id,
    customerName: e.customerName,
    jobType: e.jobType,
    serviceDescription: e.jobType,
    distance: travel.distance,
    eta: travel.eta,
    address: hasAddress
        ? e.pickupAddress!.trim()
        : e.customerLat != null
            ? '${e.customerLat!.toStringAsFixed(4)}, ${e.customerLng!.toStringAsFixed(4)}'
            : 'Pickup',
    dropoffAddress: e.dropoffAddress,
    dropoffLat: e.dropoffLat,
    dropoffLng: e.dropoffLng,
    tripDistance: e.tripDistanceKm != null ? formatDistanceKm(e.tripDistanceKm!) : '',
    rating: 0,
    payout: e.payout,
    vehicleInfo: e.vehicleInfo,
    vehicle: e.vehicle,
    jobRef: e.jobRef,
    customerLat: e.customerLat,
    customerLng: e.customerLng,
    customerPhone: e.customerPhone,
    status: e.status,
    startedAt: e.startedAt,
    createdAt: e.createdAt,
    completedAt: e.completedAt,
    customerStartConfirmedAt: e.customerStartConfirmedAt,
    providerStartConfirmedAt: e.providerStartConfirmedAt,
    bookingMode: e.bookingMode,
  );
}

/// Route for the provider to resume an in-progress job.
String? routeForActiveJob(JobStatusEntity status) {
  switch (status) {
    case JobStatusEntity.paymentPending:
      return null;
    case JobStatusEntity.arrived:
      return '/arrived';
    case JobStatusEntity.inProgress:
      return '/in-progress';
    case JobStatusEntity.accepted:
    case JobStatusEntity.navigating:
      return '/navigation';
    case JobStatusEntity.completed:
    case JobStatusEntity.cancelled:
    case JobStatusEntity.declined:
    case JobStatusEntity.incoming:
      return null;
  }
}

void applyActiveJobSession(ProviderContainer container, JobEntity job) {
  if (job.status == JobStatusEntity.paymentPending) {
    // Legacy transitional state — should not occur after pay-before-match.
    container.read(activeJobProvider.notifier).state = mockJobFromEntity(job);
    container.read(providerSocketProvider).setActiveJob(job.id);
    return;
  }

  final route = routeForActiveJob(job.status);
  if (route == null) {
    container.read(activeJobProvider.notifier).state = null;
    container.read(providerSocketProvider).setActiveJob(null);
    return;
  }
  container.read(activeJobProvider.notifier).state = mockJobFromEntity(job);
  container.read(providerSocketProvider).setActiveJob(job.id);
  flushActiveJobLocation(container.read);
}

void flushActiveJobLocation(T Function<T>(ProviderListenable<T> provider) read) {
  final loc = read(locationStreamProvider).valueOrNull;
  final repo = read(locationRepositoryProvider);
  if (loc != null) {
    unawaited(repo.broadcastLocation(loc));
    return;
  }
  unawaited(repo.getCurrentLocation().then((result) {
    result.fold((_) {}, repo.broadcastLocation);
  }));
}

/// Load the provider's active job from the API and restore local session state.
/// Returns the route to resume, or null if there is no active job.
///
/// Uses [ProviderContainer] so this stays safe after splash/login widgets dispose.
Future<String?> restoreActiveJobSession(ProviderContainer container) async {
  try {
    final job = await container.read(jobRepositoryProvider).fetchActiveJob();
    if (job == null) {
      container.read(activeJobProvider.notifier).state = null;
      container.read(providerSocketProvider).setActiveJob(null);
      return null;
    }
    applyActiveJobSession(container, job);
    return routeForActiveJob(job.status);
  } catch (_) {
    return null;
  }
}

/// Current authenticated provider profile (from `/provider/profile`).
final providerProfileProvider = FutureProvider<ProviderEntity?>((ref) async {
  final repo = ref.read(authRepositoryProvider);
  if (repo is AuthRepositoryImpl) return repo.currentProvider();
  return null;
});

/// Provider's registered vehicle (from `/provider/vehicle`).
final providerVehicleProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final res = await ref.read(dioClientProvider).dio.get('/provider/vehicle');
    final body = res.data;
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    return data is Map ? data.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
});

/// Provider bank accounts for payouts (from `/provider/bank-accounts`).
final bankAccountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ref.read(dioClientProvider).dio.get('/provider/bank-accounts');
    final body = res.data;
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  } catch (_) {
    return [];
  }
});

/// Provider withdrawal / payout history (from `/provider/payouts`).
final payoutsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ref.read(dioClientProvider).dio.get('/provider/payouts', queryParameters: {'limit': 20});
    final body = res.data;
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  } catch (_) {
    return [];
  }
});

/// Countries enabled by the admin for registration/login. Public endpoint —
/// works pre-login for phone country/dial-code selection.
final countriesProvider = FutureProvider<List<CountryEntity>>((ref) async {
  final res = await ref.read(dioClientProvider).dio.get('/countries');
  final body = res.data;
  final data = body is Map && body.containsKey('data') ? body['data'] : body;
  final list = data is List ? data : const [];
  return list.whereType<Map>().map((e) => CountryEntity.fromJson(e.cast<String, dynamic>())).toList();
});

/// Public app config (OTP flags, etc.) — fetched at startup before auth.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    final res = await ref.read(dioClientProvider).dio.get('/app-config');
    final body = res.data;
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    if (data is Map) {
      return AppConfig.fromJson(data.cast<String, dynamic>());
    }
  } catch (_) {}
  return AppConfig.fallback;
});

/// Real login: authenticate, persist tokens, connect realtime + push, and
/// set the router gate flags. Returns an error message on failure.
Future<String?> providerSignIn(ProviderContainer container, String phone, String password) async {
  final result = await container.read(authRepositoryProvider).login(phone: phone, password: password);
  final provider = result.fold((_) => null, (p) => p);
  if (provider == null) {
    return result.fold((f) => f.message, (_) => 'Authentication failed');
  }
  container.read(isAuthenticatedProvider.notifier).state = true;
  container.read(isKycApprovedProvider.notifier).state = provider.kycApproved;
  await _postAuth(container);
  return null;
}

/// Restore a persisted session on startup.
Future<void> providerBootstrap(ProviderContainer container) async {
  final session = container.read(sessionManagerProvider);
  if (!await session.hasSession()) return;

  container.read(isAuthenticatedProvider.notifier).state = true;

  final repo = container.read(authRepositoryProvider);
  if (repo is! AuthRepositoryImpl) {
    await _postAuth(container);
    return;
  }

  final provider = await repo.currentProvider();
  if (provider != null) {
    container.read(isKycApprovedProvider.notifier).state = provider.kycApproved;
    final stayAvailable = provider.onlineStatus == 'online' || provider.onlineStatus == 'busy';
    if (stayAvailable && provider.kycApproved) {
      container.read(isOnlineProvider.notifier).state = true;
      container.read(availabilityNotifierProvider.notifier).restore(true);
      container.read(locationNotifierProvider);
    }
  }
  await _postAuth(container);
}

/// Upload provider avatar after registration.
Future<String?> providerUploadAvatar(ProviderContainer container, String localPath) async {
  try {
    final uploads = container.read(fileUploadServiceProvider);
    final fileUrl = await uploads.uploadProviderFile(localPath: localPath, folder: 'avatars');
    await container.read(dioClientProvider).dio.patch('/provider/profile', data: {'avatarUrl': fileUrl});
    return null;
  } catch (e) {
    return e.toString().replaceFirst('Exception: ', '');
  }
}

/// Register a new provider, authenticate, and connect realtime + push.
Future<({String? error, String? avatarWarning})> providerRegister(
  ProviderContainer container, {
  required String name,
  required String phone,
  required String email,
  required String password,
  String? avatarLocalPath,
}) async {
  final result = await container
      .read(authRepositoryProvider)
      .register(name: name, phone: phone, email: email, password: password);
  final provider = result.fold((_) => null, (p) => p);
  if (provider == null) {
    return (error: result.fold((f) => f.message, (_) => 'Registration failed'), avatarWarning: null);
  }
  container.read(isAuthenticatedProvider.notifier).state = true;
  container.read(isKycApprovedProvider.notifier).state = provider.kycApproved;
  await _postAuth(container);
  String? avatarWarning;
  if (avatarLocalPath != null && avatarLocalPath.isNotEmpty) {
    avatarWarning = await providerUploadAvatar(container, avatarLocalPath);
  }
  return (error: null, avatarWarning: avatarWarning);
}

/// Send an OTP code for the given purpose ('register' | 'reset_password').
Future<String?> providerSendOtp(WidgetRef ref, String phone, String purpose) async {
  try {
    await ref.read(dioClientProvider).dio.post('/provider/auth/otp/send', data: {
      'phone': phone,
      'purpose': purpose,
    });
    return null;
  } catch (e) {
    return 'Could not send code';
  }
}

/// Verify a registration OTP.
Future<String?> providerVerifyOtp(WidgetRef ref, String phone, String otp) async {
  final result = await ref.read(authRepositoryProvider).verifyOtp(phone: phone, otp: otp);
  return result.fold((f) => f.message, (_) => null);
}

/// Reset the password using a verification code.
Future<String?> providerResetPassword(
  WidgetRef ref, {
  required String phone,
  required String code,
  required String newPassword,
}) async {
  try {
    await ref.read(dioClientProvider).dio.post('/provider/auth/password/reset', data: {
      'phone': phone,
      'code': code,
      'newPassword': newPassword,
    });
    return null;
  } catch (e) {
    return 'Could not reset password';
  }
}

Future<void> providerSignOut(WidgetRef ref) async {
  if (ref.read(isOnlineProvider) || ref.read(availabilityNotifierProvider)) {
    try {
      await ref.read(availabilityNotifierProvider.notifier).setOnline(false);
    } catch (_) {}
  }
  await ref.read(authRepositoryProvider).logout();
  ref.read(providerSocketProvider).disconnect();
  ref.read(isAuthenticatedProvider.notifier).state = false;
  ref.read(isKycApprovedProvider.notifier).state = false;
  ref.read(isKycInReviewProvider.notifier).state = false;
  ref.read(isAgreementAcceptedProvider.notifier).state = false;
  ref.read(isOnlineProvider.notifier).state = false;
  ref.read(activeJobProvider.notifier).state = null;
}

Future<void> _postAuth(ProviderContainer container) async {
  try {
    await container.read(providerSocketProvider).connect();
  } catch (_) {}
  await _registerFcm(container);
  container.read(jobNotifierProvider);
  await restoreActiveJobSession(container);
  try {
    final result = await container.read(kycRepositoryProvider).getKycStatus();
    result.fold((_) {}, (kyc) {
      container.read(isKycApprovedProvider.notifier).state = kyc.isApproved;
      container.read(isAgreementAcceptedProvider.notifier).state = kyc.agreementAccepted;
      container.read(isKycInReviewProvider.notifier).state =
          !kyc.isApproved && kyc.missingDocTypes.isEmpty && kyc.documents.isNotEmpty;
    });
  } catch (_) {}
}

Future<void> _registerFcm(ProviderContainer container) async {
  if (!PushMessaging.instance.isAvailable) {
    await FirebaseInitializer.initialize();
  }
  try {
    final token = await PushMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await container.read(dioClientProvider).dio.post(
        '/notifications/fcm-token',
        data: {'fcmToken': token},
      );
    }
    PushMessaging.instance.onTokenRefresh.listen((t) async {
      try {
        await container.read(dioClientProvider).dio.post(
          '/notifications/fcm-token',
          data: {'fcmToken': t},
        );
      } catch (_) {}
    });
  } catch (_) {}
}
