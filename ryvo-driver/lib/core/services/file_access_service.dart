import 'package:dio/dio.dart';

/// Resolves private S3 file URLs to short-lived presigned GET URLs.
class FileAccessService {
  FileAccessService(this._dio);

  final Dio _dio;

  Future<String> resolveAccessUrl(String fileUrl) async {
    if (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
      return fileUrl;
    }

    final res = await _dio.post('/provider/files/access-url', data: {'fileUrl': fileUrl});
    final body = res.data;
    final data = body is Map && body['data'] is Map
        ? (body['data'] as Map).cast<String, dynamic>()
        : (body as Map).cast<String, dynamic>();
    return data['url'] as String;
  }
}
