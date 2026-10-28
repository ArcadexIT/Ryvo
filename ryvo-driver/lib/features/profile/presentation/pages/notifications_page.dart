import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/providers/di_providers.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import 'package:ryvo_driver/l10n/app_localizations.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = ref.read(providerSocketProvider).onNotification.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final dio = ref.read(dioClientProvider).dio;
      final res = await dio.get('/notifications');
      final body = res.data;
      final data = body is Map && body.containsKey('data') ? body['data'] : body;
      final list = (data is Map ? data['items'] : data) as List? ?? [];
      if (!mounted) return;
      setState(() {
        _items = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
      await dio.patch('/notifications/read-all');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).notifications, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(24), child: ShimmerList(count: 5, itemHeight: 72))
          : _items.isEmpty
              ? Center(
                  child: Text(AppLocalizations.of(context).noNotificationsYet,
                      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final n = _items[i];
                      final read = n['readAt'] != null || n['isRead'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: read ? AppColors.surface : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.notifications, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${n['title'] ?? ''}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text('${n['body'] ?? ''}',
                                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
