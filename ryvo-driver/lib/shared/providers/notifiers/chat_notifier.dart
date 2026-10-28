import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/chat/domain/entities/message_entity.dart';
import '../di_providers.dart';

class ChatUiState {
  final List<MessageEntity> messages;
  final bool isSending;
  const ChatUiState({this.messages = const [], this.isSending = false});
}

class ChatNotifier extends FamilyAsyncNotifier<ChatUiState, String> {
  @override
  Future<ChatUiState> build(String jobId) async {
    ref.read(chatRepositoryProvider).watchMessages(jobId).listen((messages) {
      state = AsyncData(ChatUiState(messages: messages));
    });
    return const ChatUiState();
  }

  Future<void> sendMessage(String text) async {
    final current = state.value?.messages ?? [];
    state = AsyncData(ChatUiState(messages: current, isSending: true));

    final result = await ref.read(chatRepositoryProvider).sendMessage(jobId: arg, text: text);
    result.fold(
      (_) => state = AsyncData(ChatUiState(messages: current)),
      (sent) {
        final updated = current.any((m) => m.id == sent.id) ? current : [...current, sent];
        state = AsyncData(ChatUiState(messages: updated));
      },
    );
  }
}
