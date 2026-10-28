import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/provider_socket.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/i_chat_repository.dart';

MessageEntity _messageFromJson(Map<String, dynamic> m) {
  return MessageEntity(
    id: m['id'] as String? ?? '',
    text: m['text'] as String? ?? '',
    isSent: m['senderType'] == 'provider',
    timestamp: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
    deliveryStatus: m['deliveryStatus'] as String?,
  );
}

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._dio, this._socket);
  final Dio _dio;
  final ProviderSocket _socket;

  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Future<List<MessageEntity>> fetchMessages(String jobId) async {
    final res = await _dio.get('/provider/jobs/$jobId/messages');
    final list = _unwrap(res.data);
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => _messageFromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// REST history + socket realtime + periodic polling (socket can drop on one device).
  Stream<List<MessageEntity>> watchMessages(String jobId) {
    StreamSubscription<Map<String, dynamic>>? socketSub;
    Timer? pollTimer;

    return Stream<List<MessageEntity>>.multi((controller) async {
      await _socket.connect();
      _socket.subscribeJob(jobId);

      Future<void> emitLatest() async {
        try {
          controller.add(await fetchMessages(jobId));
        } catch (_) {}
      }

      await emitLatest();

      socketSub = _socket.onMessage.listen((data) {
        if (data['jobId']?.toString() != jobId) return;
        emitLatest();
      });

      pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => emitLatest());

      controller.onCancel = () async {
        await socketSub?.cancel();
        pollTimer?.cancel();
      };
    });
  }

  Future<MessageEntity> sendMessage({required String jobId, required String text}) async {
    await _socket.connect();
    _socket.subscribeJob(jobId);
    final res = await _dio.post('/provider/jobs/$jobId/messages', data: {'text': text});
    final data = _unwrap(res.data);
    if (data is! Map) throw Exception('Invalid chat response');
    return _messageFromJson(data.cast<String, dynamic>());
  }
}

class ChatRepositoryImpl implements IChatRepository {
  ChatRepositoryImpl(this._remote);
  final ChatRemoteDataSource _remote;

  @override
  Stream<List<MessageEntity>> watchMessages(String jobId) => _remote.watchMessages(jobId);

  @override
  Future<List<MessageEntity>> fetchMessages(String jobId) => _remote.fetchMessages(jobId);

  @override
  Future<Either<Failure, MessageEntity>> sendMessage({
    required String jobId,
    required String text,
  }) async {
    try {
      return Right(await _remote.sendMessage(jobId: jobId, text: text));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
