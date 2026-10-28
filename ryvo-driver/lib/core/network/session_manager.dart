import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Central store for the provider session: auth tokens + provider/user ids.
class SessionManager {
  SessionManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.tokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  Future<void> saveIds({String? providerId, String? userId}) async {
    if (providerId != null) {
      await _storage.write(key: AppConstants.providerIdKey, value: providerId);
    }
    if (userId != null) {
      await _storage.write(key: AppConstants.userIdKey, value: userId);
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: AppConstants.tokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: AppConstants.refreshTokenKey);
  Future<String?> getProviderId() => _storage.read(key: AppConstants.providerIdKey);
  Future<String?> getUserId() => _storage.read(key: AppConstants.userIdKey);

  Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.providerIdKey);
    await _storage.delete(key: AppConstants.userIdKey);
  }
}
