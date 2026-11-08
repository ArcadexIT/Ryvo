class AppConstants {
  AppConstants._();

  /// NestJS API base URL (includes `/api/v1`).
  ///
  /// `10.0.2.2` only exists inside the Android emulator, and only when a
  /// local API is running. Debug builds used to call it, so `GET /countries`
  /// failed and the dial code never appeared on login, register, or reset
  /// password. Debug and release both use the live API unless API_BASE_URL
  /// is set, for example
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    return 'https://ryvo.arcadexit.com/api/v1';
  }

  /// Socket.IO origin (no `/api/v1`). Gateway namespace is `/tracking`.
  static String get wsBaseUrl {
    const override = String.fromEnvironment('WS_BASE_URL');
    if (override.isNotEmpty) return override;
    var origin = apiBaseUrl;
    if (origin.endsWith('/api/v1')) {
      origin = origin.substring(0, origin.length - '/api/v1'.length);
    }
    return origin;
  }

  /// Same Maps key as the Android manifest. Used for driving directions.
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyD-nDbyA917YSx-Y_jKynqK7rqx54ticec',
  );

  static const tokenKey = 'auth_token';
  static const refreshTokenKey = 'refresh_token';
  static const providerIdKey = 'provider_id';
  static const userIdKey = 'user_id';
}
