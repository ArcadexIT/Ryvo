import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/location/location_service.dart';
import '../../core/location/uk_places_search.dart';
import '../../core/network/api_client.dart';
import '../../core/payments/stripe_config.dart';
import '../../core/network/push_messaging.dart';
import '../../core/network/token_storage.dart';
import '../../core/network/tracking_socket.dart';
import '../../core/router/app_router.dart';
import '../../data/models/app_config.dart';
import '../../data/models/models.dart';
import '../../data/models/support_models.dart';
import '../../data/repositories/repositories.dart';

final appConfigProvider = FutureProvider<AppConfig>((ref) => fetchAppConfig());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final ukPlacesSearchProvider = Provider<UkPlacesSearch>((ref) {
  return UkPlacesSearch(geocoder: ref.watch(locationServiceProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
});

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(apiClientProvider)));

final vehicleRepositoryProvider =
    Provider<VehicleRepository>((ref) => VehicleRepository(ref.watch(apiClientProvider)));

final serviceRepositoryProvider =
    Provider<ServiceRepository>((ref) => ServiceRepository(ref.watch(apiClientProvider)));

final countryRepositoryProvider =
    Provider<CountryRepository>((ref) => CountryRepository(ref.watch(apiClientProvider)));

final jobRepositoryProvider =
    Provider<JobRepository>((ref) => JobRepository(ref.watch(apiClientProvider)));

final walletRepositoryProvider =
    Provider<WalletRepository>((ref) => WalletRepository(ref.watch(apiClientProvider)));

final paymentRepositoryProvider =
    Provider<PaymentRepository>((ref) => PaymentRepository(ref.watch(apiClientProvider)));

final supportRepositoryProvider =
    Provider<SupportRepository>((ref) => SupportRepository(ref.watch(apiClientProvider)));

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  return ref.read(supportRepositoryProvider).listTickets();
});

final customerFaqsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(supportRepositoryProvider).listFaqs();
});

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref.watch(apiClientProvider)));

/// Single shared live-tracking socket for the session.
final trackingSocketProvider = Provider<TrackingSocket>((ref) {
  final socket = TrackingSocket(tokenStorage: ref.watch(tokenStorageProvider));
  ref.onDispose(socket.dispose);
  return socket;
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  return ref.read(notificationRepositoryProvider).list();
});

/// Auth bootstrap — checked on splash.
final authBootstrapProvider = FutureProvider<bool>((ref) async {
  return ref.read(authRepositoryProvider).hasSession();
});

/// Countries enabled by the admin for registration/login. Not gated on auth —
/// needed pre-login for phone country/dial-code selection.
final countriesProvider = FutureProvider<List<Country>>((ref) async {
  return ref.read(countryRepositoryProvider).list();
});

final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);
final selectedServiceProvider = StateProvider<String>((ref) => '');
final bookNowProvider = StateProvider<bool>((ref) => true);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// Pending auth context for OTP / reset flows.
final pendingPhoneProvider = StateProvider<String?>((ref) => null);
final otpPurposeProvider = StateProvider<String>((ref) => 'register');

/// True when this session was created but the phone is not verified yet.
/// The router keeps the user on the OTP screen until verification succeeds.
final needsPhoneVerificationProvider = StateProvider<bool>((ref) => false);

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  return ref.read(profileRepositoryProvider).getProfile();
});

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  ref.watch(profileProvider);
  return ref.read(vehicleRepositoryProvider).list();
});

final serviceCategoriesProvider =
    FutureProvider<List<ServiceCategory>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  final jobType = ref.watch(jobDraftProvider.select((d) => d.jobType));
  final businessType = jobType == 'parcel' ? 'parcel' : 'taxi';

  Object? lastError;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await ref.read(serviceRepositoryProvider).list(businessType: businessType);
    } catch (e) {
      lastError = e;
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }
  Error.throwWithStackTrace(lastError!, StackTrace.current);
});

final walletBalanceProvider = FutureProvider<WalletBalance?>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  final config = ref.watch(appConfigProvider).valueOrNull;
  if (config != null && !config.customerWalletEnabled) return null;
  return ref.read(walletRepositoryProvider).getBalance();
});

final walletTransactionsProvider =
    FutureProvider<List<WalletTransaction>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  final config = ref.watch(appConfigProvider).valueOrNull;
  if (config != null && !config.customerWalletEnabled) return [];
  return ref.read(walletRepositoryProvider).getTransactions();
});

final jobsListProvider = FutureProvider<List<JobModel>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  return ref.read(jobRepositoryProvider).list();
});

/// Job IDs finished this session — ignored by [fetchAndApplyActiveJob].
final finishedJobIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Nearby providers for the home map. Pass the current pickup coordinates.
final nearbyProvidersProvider = FutureProvider.family<List<NearbyProvider>,
    ({double lat, double lng})>((ref, loc) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  return ref.read(jobRepositoryProvider).nearbyProviders(lat: loc.lat, lng: loc.lng);
});

class JobRequestDraft {
  JobRequestDraft({
    this.serviceCategory,
    this.vehicle,
    this.pickupAddress = 'Locating your position…',
    this.pickupLat = 40.7138,
    this.pickupLng = -74.0040,
    this.pickupRegion,
    this.dropoffAddress = '',
    this.dropoffLat,
    this.dropoffLng,
    this.locationResolved = false,
    this.customerNotes,
    this.estimate,
    this.activeJob,
    this.paymentMethod = 'stripe',
    this.bookingType = 'instant',
    this.scheduledAt,
    this.jobType = 'taxi',
    this.offeredPrice,
    this.recipientName,
    this.recipientPhone,
    this.parcelSize = 'small',
  });

  final ServiceCategory? serviceCategory;
  final Vehicle? vehicle;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;

  /// Secondary line (locality, region) for display.
  final String? pickupRegion;
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;

  /// True once we've obtained a real GPS fix (vs. the fallback default).
  final bool locationResolved;
  final String? customerNotes;
  final FareEstimate? estimate;
  final JobModel? activeJob;
  final String paymentMethod;

  /// `'instant'` or `'scheduled'`.
  final String bookingType;

  /// For scheduled bookings — the desired start time.
  final DateTime? scheduledAt;
  final String jobType;
  final double? offeredPrice;
  final String? recipientName;
  final String? recipientPhone;
  final String parcelSize;

  JobRequestDraft copyWith({
    ServiceCategory? serviceCategory,
    Vehicle? vehicle,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? pickupRegion,
    bool clearPickupRegion = false,
    String? dropoffAddress,
    double? dropoffLat,
    double? dropoffLng,
    bool? locationResolved,
    String? customerNotes,
    FareEstimate? estimate,
    JobModel? activeJob,
    String? paymentMethod,
    String? bookingType,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    bool clearActiveJob = false,
    String? jobType,
    double? offeredPrice,
    String? recipientName,
    String? recipientPhone,
    String? parcelSize,
  }) {
    return JobRequestDraft(
      serviceCategory: serviceCategory ?? this.serviceCategory,
      vehicle: vehicle ?? this.vehicle,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      pickupRegion: clearPickupRegion ? null : (pickupRegion ?? this.pickupRegion),
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      locationResolved: locationResolved ?? this.locationResolved,
      customerNotes: customerNotes ?? this.customerNotes,
      estimate: estimate ?? this.estimate,
      activeJob: clearActiveJob ? null : (activeJob ?? this.activeJob),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bookingType: bookingType ?? this.bookingType,
      scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      jobType: jobType ?? this.jobType,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      parcelSize: parcelSize ?? this.parcelSize,
    );
  }
}

final jobDraftProvider =
    StateProvider<JobRequestDraft>((ref) => JobRequestDraft());

/// True only while this session is inserting a job and taking payment.
/// A home refresh must not cancel that job out from under the payment sheet.
final paymentCheckoutInProgressProvider = StateProvider<bool>((ref) => false);

/// The payment provider accepted the charge, but the job is still
/// `payment_pending`. That row must stay so confirmation can be retried.
final paymentAwaitingConfirmationProvider = StateProvider<bool>((ref) => false);

/// Bumped when the customer moves the pin or confirms a searched place, so a
/// slower GPS fix cannot overwrite that choice.
final pickupEditGenerationProvider = StateProvider<int>((ref) => 0);

/// True when the draft pickup is a confirmed GPS or typed address ready
/// to send to [POST /customer/jobs].
bool isPickupLocationReady(JobRequestDraft draft) {
  final address = draft.pickupAddress.trim();
  return draft.locationResolved &&
      address.isNotEmpty &&
      address != 'Locating your position…';
}

/// Resolves the device's current location and writes it into [jobDraftProvider].
/// Returns null on success, or a user-facing error message on failure.
Future<String?> refreshPickupLocation(WidgetRef ref) async {
  final generation = ref.read(pickupEditGenerationProvider);
  final current = ref.read(jobDraftProvider);
  if (ref.read(paymentCheckoutInProgressProvider)) return null;
  // A confirmed pickup must stay put until the new fix arrives. Clearing it
  // here made ride requests fail with "Confirm a pickup address".
  if (!isPickupLocationReady(current)) {
    ref.read(jobDraftProvider.notifier).state = current.copyWith(
      pickupAddress: 'Locating your position…',
      locationResolved: false,
    );
  }
  try {
    final resolved = await ref.read(locationServiceProvider).getCurrentLocation();
    if (ref.read(pickupEditGenerationProvider) != generation) return null;
    final latest = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state = latest.copyWith(
      pickupLat: resolved.lat,
      pickupLng: resolved.lng,
      pickupAddress: resolved.address ?? resolved.shortAddress ?? 'Current location',
      pickupRegion: resolved.region,
      clearPickupRegion: resolved.region == null,
      locationResolved: true,
    );
    return null;
  } on LocationFailure catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not determine your location. Please try again.';
  }
}

/// Reverse-geocodes a map pin and writes it into [jobDraftProvider].
/// Returns null on success, or a user-facing error message on failure.
Future<String?> applyPickupCoordinates(WidgetRef ref, double lat, double lng) async {
  try {
    final resolved = await ref.read(locationServiceProvider).reverseGeocode(lat, lng);
    final latest = ref.read(jobDraftProvider);
    final address = resolved.address ??
        resolved.shortAddress ??
        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    ref.read(jobDraftProvider.notifier).state = latest.copyWith(
      pickupLat: lat,
      pickupLng: lng,
      pickupAddress: address,
      pickupRegion: resolved.region,
      clearPickupRegion: resolved.region == null,
      locationResolved: true,
    );
    return null;
  } catch (_) {
    final latest = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state = latest.copyWith(
      pickupLat: lat,
      pickupLng: lng,
      pickupAddress: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
      clearPickupRegion: true,
      locationResolved: true,
    );
    return null;
  }
}

/// Geocodes a typed address and writes it into [jobDraftProvider].
/// Returns null on success, or a user-facing error message on failure.
Future<String?> applyManualPickupAddress(WidgetRef ref, String query) async {
  try {
    final draft = ref.read(jobDraftProvider);
    final bias = UkSearchBias.resolve(
      lat: draft.pickupLat,
      lng: draft.pickupLng,
      locationResolved: draft.locationResolved,
    );
    final resolved = await ref.read(ukPlacesSearchProvider).resolve(
          query: query,
          biasLat: bias.lat,
          biasLng: bias.lng,
          sessionToken: newPlacesSessionToken(),
        );
    final latest = ref.read(jobDraftProvider);
    ref.read(jobDraftProvider.notifier).state = latest.copyWith(
      pickupLat: resolved.lat,
      pickupLng: resolved.lng,
      pickupAddress: resolved.address ?? resolved.shortAddress ?? query.trim(),
      pickupRegion: resolved.region,
      clearPickupRegion: resolved.region == null,
      locationResolved: true,
    );
    return null;
  } on LocationFailure catch (e) {
    return e.message;
  } on PlacesLookupException catch (e) {
    return e.message;
  } catch (_) {
    return 'Could not find that address. Try a more specific one.';
  }
}

Future<void> bootstrapAuth(WidgetRef ref) async {
  final auth = ref.read(authRepositoryProvider);
  if (!await auth.hasSession()) {
    ref.read(isAuthenticatedProvider.notifier).state = false;
    return;
  }

  final refreshed = await auth.refreshAccessToken();
  if (!refreshed) {
    await auth.logout();
    ref.read(isAuthenticatedProvider.notifier).state = false;
    return;
  }

  ref.read(isAuthenticatedProvider.notifier).state = true;
  await _syncPhoneVerification(ref);
  ref.invalidate(serviceCategoriesProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(vehiclesProvider);
  ref.invalidate(jobsListProvider);
  // Socket + FCM must not block splash navigation on a slow cold start.
  unawaited(_afterLogin(ref));
}

/// Unverified accounts must finish the OTP step before the rest of the app.
Future<void> _syncPhoneVerification(WidgetRef ref) async {
  try {
    final profile = await ref.read(profileRepositoryProvider).getProfile();
    final pending = profile.status == 'pending_verification';
    ref.read(needsPhoneVerificationProvider.notifier).state = pending;
    if (!pending) return;
    ref.read(pendingPhoneProvider.notifier).state = profile.phone;
    ref.read(otpPurposeProvider.notifier).state = 'register';
    try {
      await ref.read(authRepositoryProvider).sendOtp(profile.phone, 'register');
    } catch (_) {
      // The OTP screen still opens. Resend shows the error.
    }
  } catch (_) {}
}

Future<void> signIn(WidgetRef ref, String phone, String password) async {
  await ref.read(authRepositoryProvider).login(phone, password);
  await _syncPhoneVerification(ref);
  ref.read(isAuthenticatedProvider.notifier).state = true;
  ref.invalidate(profileProvider);
  ref.invalidate(vehiclesProvider);
  ref.invalidate(walletBalanceProvider);
  ref.invalidate(jobsListProvider);
  ref.invalidate(serviceCategoriesProvider);
  await _afterLogin(ref);
}

/// Public entry point for post-auth side effects (used after OTP verify).
Future<void> afterLogin(WidgetRef ref) => _afterLogin(ref);

bool _fcmRefreshListening = false;

/// Registers the device FCM token with the API when push is ready and user is logged in.
Future<void> syncFcmToken(WidgetRef ref) async {
  if (!ref.read(isAuthenticatedProvider)) return;

  try {
    await PushMessaging.instance.whenReady();
    final token = await PushMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await ref.read(notificationRepositoryProvider).registerFcmToken(token);
      debugPrint('FCM token registered with API');
    } else {
      debugPrint('FCM token not available — will retry on token refresh');
    }

    if (!_fcmRefreshListening) {
      _fcmRefreshListening = true;
      final container = _providerContainerFromNavigator();
      if (container == null) return;
      PushMessaging.instance.onTokenRefresh.listen((t) {
        if (!container.read(isAuthenticatedProvider)) return;
        container
            .read(notificationRepositoryProvider)
            .registerFcmToken(t)
            .catchError((_) {});
      });
    }
  } catch (e) {
    debugPrint('FCM token registration skipped: $e');
  }
}

ProviderContainer? _providerContainerFromNavigator() {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return null;
  return ProviderScope.containerOf(context, listen: false);
}

/// Container-based variant safe to call from async callbacks after widgets dispose.
Future<void> syncFcmTokenWithContainer(ProviderContainer container) async {
  if (!container.read(isAuthenticatedProvider)) return;

  try {
    await PushMessaging.instance.whenReady();
    final token = await PushMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await container.read(notificationRepositoryProvider).registerFcmToken(token);
      debugPrint('FCM token registered with API');
    } else {
      debugPrint('FCM token not available — will retry on token refresh');
    }

    if (!_fcmRefreshListening) {
      _fcmRefreshListening = true;
      PushMessaging.instance.onTokenRefresh.listen((t) {
        if (!container.read(isAuthenticatedProvider)) return;
        container
            .read(notificationRepositoryProvider)
            .registerFcmToken(t)
            .catchError((_) {});
      });
    }
  } catch (e) {
    debugPrint('FCM token registration skipped: $e');
  }
}

/// Post-auth side effects: open the realtime socket and register the FCM token.
Future<void> _afterLogin(WidgetRef ref) async {
  try {
    await ref.read(trackingSocketProvider).connect();
  } catch (_) {}
  await syncFcmToken(ref);
}

Future<void> signOut(WidgetRef ref) async {
  await ref.read(authRepositoryProvider).logout();
  ref.read(isAuthenticatedProvider.notifier).state = false;
  ref.read(needsPhoneVerificationProvider.notifier).state = false;
  ref.read(pendingPhoneProvider.notifier).state = null;
  ref.read(finishedJobIdsProvider.notifier).state = {};
  ref.read(paymentCheckoutInProgressProvider.notifier).state = false;
  ref.read(paymentAwaitingConfirmationProvider.notifier).state = false;
  ref.read(jobDraftProvider.notifier).state = JobRequestDraft();
  ref.invalidate(profileProvider);
}

void showApiError(BuildContext context, Object error) {
  final message = switch (error) {
    RyvoStripeConfigException(:final message) => message,
    StripeException(:final error) =>
      error.localizedMessage ?? 'Payment failed. Please try again.',
    _ => error.toString().replaceFirst('ApiException: ', ''),
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
    ),
  );
}

IconData serviceIcon(String? slug, String? icon) {
  return switch (slug ?? icon) {
    'ryvo-go' || 'directions_car' => Icons.directions_car_outlined,
    'comfort' || 'airline_seat_recline_extra' => Icons.airline_seat_recline_extra,
    'xl' || 'airport_shuttle' => Icons.airport_shuttle,
    'jump-start' || 'bolt' => Icons.bolt,
    _ => Icons.directions_car_outlined,
  };
}

Color jobStatusColor(String status) {
  return switch (status) {
    'completed' => const Color(0xFF22C55E),
    'searching' || 'matched' || 'provider_en_route' || 'in_progress' =>
      const Color(0xFF32BB78),
    'cancelled_by_customer' ||
    'cancelled_by_provider' ||
    'cancelled_by_admin' ||
    'no_provider_found' =>
      const Color(0xFFEF4444),
    _ => const Color(0xFF94A3B8),
  };
}
