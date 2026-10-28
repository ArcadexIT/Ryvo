import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/providers/app_providers.dart';
import 'package:ryvo_customer/l10n/app_localizations.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Live updates while the screen is open.
    Future.microtask(() async {
      try {
        await ref.read(trackingSocketProvider).connect();
        ref.read(trackingSocketProvider).onNotification.listen((_) {
          if (mounted) ref.invalidate(notificationsProvider);
        });
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(AppLocalizations.of(context).notifications,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider);
              } catch (e) {
                if (context.mounted) showApiError(context, e);
              }
            },
            child: Text(AppLocalizations.of(context).markAllRead,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        color: AppColors.primary,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(AppLocalizations.of(context).failedToLoadNotifications,
                    style: GoogleFonts.poppins(color: AppColors.textSecondary)),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 140),
                  Icon(Icons.notifications_none, size: 64, color: AppColors.grey600),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(AppLocalizations.of(context).noNotificationsYet,
                        style: GoogleFonts.poppins(color: AppColors.textSecondary)),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotificationTile(
                item: items[i],
                onTap: items[i].isRead
                    ? null
                    : () async {
                        try {
                          await ref.read(notificationRepositoryProvider).markRead(items[i].id);
                          ref.invalidate(notificationsProvider);
                        } catch (_) {}
                      },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, this.onTap});

  final NotificationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isRead ? AppColors.surface : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isRead ? AppColors.divider : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(item.body,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
