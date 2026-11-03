import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/app_constants.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              final token = await _tokenStorage.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              error.requestOptions.extra['retried'] = true;
              try {
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              } catch (_) {}
            }
          }
          handler.next(error);
        },
      ),
    );
    _attachLogger(_dio);
  }

  late final Dio _dio;
  final TokenStorage _tokenStorage;

  Dio get dio => _dio;
  TokenStorage get tokenStorage => _tokenStorage;

  /// Refresh access token using the stored refresh token (startup / silent renew).
  Future<bool> refreshSession() => _refreshToken();

  Future<bool> _refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final refreshDio = Dio(
        BaseOptions(baseUrl: AppConstants.apiBaseUrl),
      );
      _attachLogger(refreshDio);
      final response = await refreshDio.post(
        '/customer/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = _unwrap(response.data);
      if (data is! Map<String, dynamic>) return false;

      await _tokenStorage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException catch (e) {
      // Only wipe the session when the refresh token is rejected — not on network blips.
      if (e.response?.statusCode == 401) {
        await _tokenStorage.clear();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? parser,
  }) =>
      _request('GET', path, queryParameters: queryParameters, parser: parser);

  Future<T> post<T>(
    String path, {
    dynamic data,
    T Function(dynamic json)? parser,
  }) =>
      _request('POST', path, data: data, parser: parser);

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic json)? parser,
  }) =>
      _request('PATCH', path, data: data, parser: parser);

  Future<T> delete<T>(
    String path, {
    T Function(dynamic json)? parser,
  }) =>
      _request('DELETE', path, parser: parser);

  /// Upload a file as multipart/form-data.
  /// [path]   – e.g. `/customer/files/upload`
  /// [file]   – local file to upload (field name: `file`)
  /// [folder] – sub-folder hint stored with the object (field name: `folder`)
  Future<Map<String, dynamic>> uploadFile(
    String path,
    File file,
    String folder,
  ) async {
    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    var name = file.path.split('/').last;
    if (!name.contains('.')) {
      name = mime == 'image/png' ? '$name.png' : '$name.jpg';
    }
    final formData = FormData.fromMap({
      'folder': folder,
      'file': await MultipartFile.fromFile(file.path,
          filename: name, contentType: DioMediaType.parse(mime)),
    });
    try {
      // Leave Content-Type unset so Dio can add the multipart boundary.
      final response = await _dio.post<dynamic>(
        path,
        data: formData,
      );
      return (_unwrap(response.data) as Map<String, dynamic>?) ?? {};
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<T> _request<T>(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? parser,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
      );
      final payload = _unwrap(response.data);
      if (parser != null) return parser(payload);
      return payload as T;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map['success'] == false) {
        throw ApiException(
          serverErrorMessage(map) ?? 'Request failed',
          statusCode: _statusCode(map['statusCode']),
        );
      }
      return map['data'];
    }
    return body;
  }

  ApiException _mapError(DioException error) {
    final response = error.response;
    final serverMessage = serverErrorMessage(response?.data);
    final message = serverMessage ?? error.message ?? 'Network error';
    final exception = ApiException(
      message,
      statusCode: response?.statusCode,
    );
    if (kDebugMode) debugPrint('ApiException: $exception');
    return exception;
  }
}

void _attachLogger(Dio dio) {
  if (!kDebugMode) return;
  dio.interceptors.add(
    PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      compact: true,
      maxWidth: 90,
    ),
  );
}

int? _statusCode(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class PaginatedResult<T> {
  PaginatedResult({required this.items, this.meta});

  final List<T> items;
  final Map<String, dynamic>? meta;
}

PaginatedResult<T> parsePaginated<T>(
  dynamic data,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (data is List) {
    return PaginatedResult(
      items: data.whereType<Map<String, dynamic>>().map(fromJson).toList(),
    );
  }
  return PaginatedResult(items: const []);
}
