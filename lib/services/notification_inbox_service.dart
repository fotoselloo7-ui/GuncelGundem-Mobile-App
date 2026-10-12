import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/push_notification_model.dart';

class NotificationInboxItem {
  final PushNotificationPayload payload;
  final DateTime receivedAt;
  final bool isRead;

  const NotificationInboxItem({
    required this.payload,
    required this.receivedAt,
    this.isRead = false,
  });

  String get id =>
      payload.pushEventId ??
      '${payload.slug ?? payload.newsId ?? payload.title}_${receivedAt.millisecondsSinceEpoch}';

  NotificationInboxItem copyWith({bool? isRead}) => NotificationInboxItem(
    payload: payload,
    receivedAt: receivedAt,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'payload': payload.toJson(),
    'received_at': receivedAt.toIso8601String(),
    'is_read': isRead,
  };

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return NotificationInboxItem(
      payload: PushNotificationPayload.fromJson(
        rawPayload is Map<String, dynamic>
            ? rawPayload
            : const <String, dynamic>{},
      ),
      receivedAt:
          DateTime.tryParse(json['received_at']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }
}

/// Cihaza gelen push'ların uygulama içindeki kalıcı Bildirim Merkezi.
///
/// Kişisel veri tutmaz; yalnız cihazın kendi SharedPreferences alanında en son
/// 100 bildirimi saklar. Aynı push_event_id tekrar gelirse mükerrer kayıt üretmez.
class NotificationInboxService extends ChangeNotifier {
  NotificationInboxService._();

  static final NotificationInboxService instance = NotificationInboxService._();

  static const _storageKey = 'notification_inbox_v1';
  static const _maxItems = 100;

  final List<NotificationInboxItem> _items = [];
  bool _initialized = false;

  List<NotificationInboxItem> get items =>
      List<NotificationInboxItem>.unmodifiable(_items);

  int get unreadCount => _items.where((item) => !item.isRead).length;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map>()
                  .map((entry) => NotificationInboxItem.fromJson(
                        Map<String, dynamic>.from(entry),
                      )),
            );
        }
      } catch (_) {
        // Bozuk yerel cache bildirim sistemini bozmaz.
      }
    }
    _items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> add(
    PushNotificationPayload payload, {
    bool markRead = false,
  }) async {
    await initialize();
    final identity = payload.pushEventId?.trim();
    if (identity != null && identity.isNotEmpty) {
      final index = _items.indexWhere(
        (item) => item.payload.pushEventId == identity,
      );
      if (index >= 0) {
        if (markRead && !_items[index].isRead) {
          _items[index] = _items[index].copyWith(isRead: true);
          await _persist();
          notifyListeners();
        }
        return;
      }
    }

    _items.insert(
      0,
      NotificationInboxItem(
        payload: payload,
        receivedAt: DateTime.now(),
        isRead: markRead,
      ),
    );
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    await initialize();
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;
    _items[index] = _items[index].copyWith(isRead: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await initialize();
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await initialize();
    if (_items.isEmpty) return;
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }
}
