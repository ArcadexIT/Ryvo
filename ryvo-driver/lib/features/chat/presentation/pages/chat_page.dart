import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/chat_bubble.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String jobId;
  const ChatPage({super.key, required this.jobId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _connectChatSocket();
    });
  }

  Future<void> _connectChatSocket() async {
    try {
      await ref.read(providerSocketProvider).connect();
    } catch (_) {}
    if (!mounted) return;
    ref.read(providerSocketProvider).subscribeJob(widget.jobId);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(chatNotifierProvider(widget.jobId).notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatNotifierProvider(widget.jobId));
    final activeJob = ref.watch(activeJobProvider);
    final title = activeJob?.customerName ?? AppLocalizations.of(context).customer;
    final jobRef = activeJob?.jobRef;
    final messages = chat.value?.messages ?? const [];
    final isSending = chat.value?.isSending ?? false;
    final isLoading = chat.isLoading && messages.isEmpty;

    ref.listen(chatNotifierProvider(widget.jobId), (_, next) {
      if ((next.value?.messages.length ?? 0) > 0) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(
              jobRef != null && jobRef.isNotEmpty ? 'Job $jobRef' : AppLocalizations.of(context).liveChat,
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context).noMessagesYetSayHiToYourCustomer,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          return ChatBubble(
                            message: m.text,
                            isSent: m.isSent,
                            timestamp: _time(m.timestamp),
                            status: m.isSent ? m.deliveryStatus : null,
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !isSending,
                      style: GoogleFonts.poppins(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).typeAMessage,
                        hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isSending ? null : _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSending ? AppColors.divider : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSending ? Icons.hourglass_top : Icons.send,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
