import 'dart:io';

import 'package:dio/dio.dart';

/// Uploads files to S3 via the API server (multipart) or presigned URL fallback.
class FileUploadService {
  FileUploadService(this._apiDio);

  final Dio _apiDio;

  static final _plainDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  static const _uploadTimeouts = Duration(seconds: 120);

  Future<String> uploadProviderFile({
    required String localPath,
    required String folder,
    String? contentType,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('File not found');
    }

    final rawName = localPath.split('/').last;
    final mime = contentType ?? _guessContentType(rawName);
    final filename = _ensureFilename(rawName, mime);

    // Prefer server-side upload (simpler, clearer errors on mobile).
    try {
      return await _uploadViaApi(
        localPath: localPath,
        folder: folder,
        filename: filename,
        mime: mime,
      );
    } on DioException catch (e) {
      final msg = _extractApiMessage(e);
      if (_isHardFailure(e, msg)) {
        throw Exception(msg ?? _timeoutHint(e));
      }
      // Fall back to presigned direct upload for transient API upload issues.
    } catch (e) {
      final text = e.toString().replaceFirst('Exception: ', '');
      if (!text.contains('404') && !text.toLowerCase().contains('not found')) {
        rethrow;
      }
    }

    return _uploadViaPresign(
      localPath: localPath,
      folder: folder,
      filename: filename,
      mime: mime,
    );
  }

  Future<String> _uploadViaApi({
    required String localPath,
    required String folder,
    required String filename,
    required String mime,
  }) async {
    final formData = FormData.fromMap({
      'folder': folder,
      'file': await MultipartFile.fromFile(
        localPath,
        filename: filename,
        contentType: DioMediaType.parse(mime),
      ),
    });

    // Do NOT set Content-Type manually — Dio must add the multipart boundary.
    final res = await _apiDio.post(
      '/provider/files/upload',
      data: formData,
      options: Options(
        sendTimeout: _uploadTimeouts,
        receiveTimeout: _uploadTimeouts,
        // Avoid inheriting application/json from BaseOptions for this call.
        headers: {Headers.acceptHeader: 'application/json'},
      ),
    );

    final body = res.data;
    final data = body is Map && body['data'] is Map
        ? (body['data'] as Map).cast<String, dynamic>()
        : (body as Map).cast<String, dynamic>();
    final fileUrl = data['fileUrl'] as String?;
    if (fileUrl == null || fileUrl.isEmpty) {
      throw Exception('Upload failed: no fileUrl returned');
    }
    return fileUrl;
  }

  Future<String> _uploadViaPresign({
    required String localPath,
    required String folder,
    required String filename,
    required String mime,
  }) async {
    late final Map<String, dynamic> data;
    try {
      final presignRes = await _apiDio.post(
        '/provider/files/presign',
        data: {
          'folder': folder,
          'filename': filename,
          'contentType': mime,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final body = presignRes.data;
      data = body is Map && body['data'] is Map
          ? (body['data'] as Map).cast<String, dynamic>()
          : (body as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      final msg = _extractApiMessage(e);
      throw Exception(msg ?? _timeoutHint(e) ?? 'Could not prepare upload. Check API AWS S3 settings.');
    }

    final uploadUrl = data['uploadUrl'] as String?;
    final fileUrl = data['fileUrl'] as String?;
    if (uploadUrl == null || fileUrl == null) {
      throw Exception('Could not prepare upload. Invalid presign response.');
    }
    final bytes = await File(localPath).readAsBytes();

    try {
      final putRes = await _plainDio.put(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: {'Content-Type': mime},
          sendTimeout: _uploadTimeouts,
          receiveTimeout: _uploadTimeouts,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      if (putRes.statusCode == null || putRes.statusCode! < 200 || putRes.statusCode! >= 300) {
        throw Exception('S3 upload failed (${putRes.statusCode})');
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) {
        throw Exception(
          'S3 access denied (403). Check IAM s3:PutObject on the uploads bucket.',
        );
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Upload timed out while sending to storage. Check your internet connection and try again.',
        );
      }
      throw Exception('S3 upload failed ($code). ${e.message ?? ''}');
    }

    return fileUrl;
  }

  bool _isHardFailure(DioException e, String? msg) {
    final status = e.response?.statusCode;
    if (status == 400 || status == 401 || status == 413 || status == 422 || status == 503) {
      return true;
    }
    if (msg == null || msg.isEmpty) return false;
    final lower = msg.toLowerCase();
    return lower.contains('s3') ||
        lower.contains('storage') ||
        lower.contains('validation') ||
        lower.contains('file type') ||
        lower.contains('too large') ||
        lower.contains('unauthorized') ||
        lower.contains('timed out') ||
        lower.contains('unreachable');
  }

  String? _timeoutHint(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'Cannot reach API (${_apiDio.options.baseUrl}). '
            'Use the same Wi‑Fi as your computer and run with '
            '--dart-define=API_BASE_URL=http://YOUR_LAN_IP:4000/api/v1';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Upload timed out. Try a smaller photo or check your connection.';
      default:
        return null;
    }
  }

  String? _extractApiMessage(DioException e) {
    try {
      final dynamic err = e.error;
      final message = err?.message;
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}

    final body = e.response?.data;
    if (body is Map) {
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.join(', ');
    }
    if (e.response?.statusCode != null) {
      return 'Upload failed (${e.response!.statusCode})';
    }
    return _timeoutHint(e) ?? e.message;
  }

  String _ensureFilename(String filename, String mime) {
    if (filename.contains('.') && !filename.endsWith('.')) return filename;
    final ext = switch (mime) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/heic' => '.heic',
      'application/pdf' => '.pdf',
      _ => '.jpg',
    };
    final base = filename.isEmpty ? 'upload' : filename;
    return '$base$ext';
  }

  String _guessContentType(String filename) {
    final dot = filename.lastIndexOf('.');
    final ext = dot >= 0 ? filename.substring(dot).toLowerCase() : '';
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
  }
}
