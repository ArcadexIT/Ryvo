import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/message_entity.dart';

abstract class IChatRepository {
  Stream<List<MessageEntity>> watchMessages(String jobId);
  Future<List<MessageEntity>> fetchMessages(String jobId);
  Future<Either<Failure, MessageEntity>> sendMessage({required String jobId, required String text});
}
