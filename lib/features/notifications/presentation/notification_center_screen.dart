import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/branding_state.dart';
import '../../../services/firebase_push_coordinator.dart';
import '../../../services/notification_inbox_service.dart';
import '../../home/presentation/home_widgets.dart';
import 'notification_preferences_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inbox = NotificationInboxService.instance;
    final brand = BrandingState.instance;

    return Theme(
      data: homeTheme(brand),
      child: AnimatedBuilder(
        animation: inbox,
        builder: (context, _) {
          final items = inbox.items;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              toolbarHeight: 64,
              iconTheme: const IconThemeData(color: homeNavy),
              shape: const Border(bottom: BorderSide(color: homeLine)),
              title: const Text(
                'Bildirimler',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: homeNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                if (inbox.unreadCount > 0)
                  IconButton(
                    tooltip: 'Tümünü okundu işaretle',
                    onPressed: () => unawaited(inbox.markAllRead()),
                    icon: const Icon(Icons.done_all_rounded),
                  ),
                IconButton(
                  tooltip: 'Bildirim Ayarları',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: items.isEmpty
                ? const _EmptyInbox()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final payload = item.payload;
                      return Material(
                        color: item.isRead
                            ? Colors.white
                            : brand.primaryColor.withValues(alpha: 0.055),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: item.isRead
                                ? homeLine
                                : brand.primaryColor.withValues(alpha: 0.22),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            await inbox.markRead(item.id);
                            if (!context.mounted) return;
                            await FirebasePushCoordinator.instance
                                .openForegroundPayload(payload);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: payload.breaking
                                        ? brand.primaryColor
                                        : homeNavy,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    payload.breaking
                                        ? Icons.bolt_rounded
                                        : Icons.notifications_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              payload.title.isEmpty
                                                  ? 'Güncel Gündem'
                                                  : payload.title,
                                              style: const TextStyle(
                                                color: homeNavy,
                                                fontSize: 14,
                                                height: 1.35,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(
                                                left: 8,
                                                top: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: brand.primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (payload.body.trim().isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          payload.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: homeMuted,
                                            fontSize: 12.5,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        _relativeTime(item.receivedAt),
                                        style: const TextStyle(
                                          color: homeMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  static String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xffeef2f7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: homeMuted,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Henüz bildirim yok',
            style: TextStyle(
              color: homeNavy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Son Dakika ve takip ettiğiniz haber bildirimleri burada toplanır.',
            textAlign: TextAlign.center,
            style: TextStyle(color: homeMuted, height: 1.45),
          ),
        ],
      ),
    ),
  );
}
