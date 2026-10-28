import 'package:dio/dio.dart';
import '../domain/support_entities.dart';

dynamic _unwrap(Response res) {
  final body = res.data;
  if (body is Map && body.containsKey('data')) return body['data'];
  return body;
}

class SupportRepository {
  SupportRepository(this._dio);

  final Dio _dio;

  Future<List<SupportTicket>> listTickets({int page = 1, int limit = 20}) async {
    final data = _unwrap(await _dio.get('/support/tickets', queryParameters: {'page': page, 'limit': limit}));
    if (data is! List) return [];
    return data.whereType<Map>().map((e) => SupportTicket.fromJson(e.cast<String, dynamic>())).toList();
  }

  Future<SupportTicketDetail> getTicket(String id) async {
    final data = _unwrap(await _dio.get('/support/tickets/$id'));
    return SupportTicketDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    String? jobId,
  }) async {
    final data = _unwrap(await _dio.post('/support/tickets', data: {
      'category': category,
      'subject': subject,
      'message': message,
      if (jobId != null) 'jobId': jobId,
    }));
    return SupportTicket.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> reply(String ticketId, String message) async {
    await _dio.post('/support/tickets/$ticketId/messages', data: {'message': message});
  }
}
