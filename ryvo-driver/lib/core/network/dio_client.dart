import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/jwt_interceptor.dart';
import 'interceptors/token_refresh_interceptor.dart';

class DioClient {
  DioClient({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.addAll([
      JwtInterceptor(_storage),
      TokenRefreshInterceptor(_dio, _storage),
      ErrorInterceptor(),
    ]);
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  Dio get dio => _dio;
}
