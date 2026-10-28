import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const appName = 'Ryvo';

  /// NestJS API base URL (includes `/api/v1`).
  /// Debug builds use the local API. The live server has no SMS sender, so
  /// rider registration fails there with a server error.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (kDebugMode) return 'http://10.0.2.2:4000/api/v1';
    return 'https://ryvo.arcadexit.com/api/v1';
  }

  /// Socket.IO origin (no `/api/v1` suffix). The gateway namespace is `/tracking`.
  static String get wsBaseUrl {
    const override = String.fromEnvironment('WS_BASE_URL');
    if (override.isNotEmpty) return override;
    var origin = apiBaseUrl;
    if (origin.endsWith('/api/v1')) {
      origin = origin.substring(0, origin.length - '/api/v1'.length);
    }
    return origin;
  }

  static const tokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';

  /// Stripe publishable key fall-back (used only when the backend /app-config
  /// fetch fails, e.g. during very first cold start with no network).
  /// Override at build time: --dart-define=STRIPE_KEY=pk_live_...
  static const stripePublishableKeyFallback = String.fromEnvironment(
    'STRIPE_KEY',
    defaultValue: '',
  );

  /// Apple Pay merchant ID from the Apple Developer account, e.g.
  /// `merchant.ryvo.arcadexit.com`. Required before the payment sheet can offer Apple Pay.
  /// `--dart-define=APPLE_MERCHANT_ID=merchant.ryvo.arcadexit.com`
  static const appleMerchantId = String.fromEnvironment(
    'APPLE_MERCHANT_ID',
    defaultValue: 'merchant.ryvo.arcadexit.com',
  );

  /// Same Maps key as the Android manifest and iOS Info.plist.
  /// Places Autocomplete must be enabled on this key.
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyD-nDbyA917YSx-Y_jKynqK7rqx54ticec',
  );
}
