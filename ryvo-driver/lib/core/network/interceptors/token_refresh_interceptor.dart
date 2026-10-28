import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../constants/app_constants.dart';

class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor(this._dio, this._storage);
  final Dio _dio;
  final FlutterSecureStorage _storage;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Avoid infinite loops when the refresh call itself 401s.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return handler.next(err);

      final response = await _dio.post(
        '/provider/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      // Backend wraps payloads in `{ success, data }`.
      final body = response.data;
      final data = (body is Map && body['data'] is Map) ? body['data'] as Map : body as Map;
      final newToken = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newToken == null) return handler.next(err);

      await _storage.write(key: AppConstants.tokenKey, value: newToken);
      if (newRefresh != null) {
        await _storage.write(key: AppConstants.refreshTokenKey, value: newRefresh);
      }

      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newToken';
      // Multipart bodies can only be sent once. Clone before the retry.
      final requestData = opts.data;
      if (requestData is FormData) {
        opts.data = requestData.clone();
      }
      final retryResponse = await _dio.fetch(opts);
      return handler.resolve(retryResponse);
    } catch (_) {
      return handler.next(err);
    }
  }
}
