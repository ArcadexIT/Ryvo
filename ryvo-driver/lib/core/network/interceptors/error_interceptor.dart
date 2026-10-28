import 'package:dio/dio.dart';
import '../../errors/failure.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = _mapError(err);
    handler.reject(DioException(
      requestOptions: err.requestOptions,
      error: failure,
      type: err.type,
      response: err.response,
    ));
  }

  Failure _mapError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'Cannot reach the server. Check Wi‑Fi / API URL and try again.',
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(
          'Request timed out. Try again with a smaller image or better connection.',
        );
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        final data = err.response?.data;
        final msg = _messageOf(data);
        if (status == 401) return AuthFailure(msg ?? 'Unauthorized');
        if (status == 422) return ValidationFailure(msg ?? 'Validation error');
        return ServerFailure(msg ?? 'Server error ($status)');
      default:
        return ServerFailure(err.message ?? 'Unknown error');
    }
  }
}

String? _messageOf(dynamic data) {
  if (data is! Map) return null;
  final msg = data['message'];
  if (msg is String) return msg;
  if (msg is Map) {
    final nested = msg['message'] ?? msg['code'];
    return nested?.toString();
  }
  return msg?.toString();
}
