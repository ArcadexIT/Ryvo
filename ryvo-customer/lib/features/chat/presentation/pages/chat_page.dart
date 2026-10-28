import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class _ChatMessage {
  _ChatMessage({required this.id, required this.text, required this.isSent, required this.time});
  final String id;
  final String text;
  final bool isSent;
  final DateTime time;
}

class ChatPage extends ConsumerStatefulWidget {
  final String jobId;
  const ChatPage({super.key, required this.jobId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    final socket = ref.read(trackingSocketProvider);
    socket.subscribeJob(widget.jobId);
    _sub = socket.onMessage.listen((data) {
      if (data['jobId'] != widget.jobId) return;
      _add(_fromMap(data));
    });
  }

  _ChatMessage _fromMap(Map<String, dynamic> m) => _ChatMessage(
        id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: m['text'] as String? ?? '',
        isSent: m['senderType'] == 'customer',
        time: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Future<void> _load() async {
    try {
      final list = await ref.read(jobRepositoryProvider).messages(widget.jobId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list.map(_fromMap));
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(_ChatMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      final res = await ref.read(jobRepositoryProvider).sendMessage(widget.jobId, text);
      _add(_fromMap(res));
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDraftProvider).activeJob;
    final title = job?.provider?.fullName ?? AppLocalizations.of(context).provider;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context).noMessagesYet,
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _Bubble(message: _messages[i], time: _time(_messages[i].time)),
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
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
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send, color: Colors.black, size: 20),
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

class _Bubble extends StatelessWidget {
  final _ChatMessage message;
  final String time;
  const _Bubble({required this.message, required this.time});

  @override
  Widget build(BuildContext context) {
    final isSent = message.isSent;
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSent ? AppColors.primary.withOpacity(0.2) : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
          border: Border.all(color: isSent ? AppColors.primary.withOpacity(0.3) : AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
            const SizedBox(height: 4),
            Text(time, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}
