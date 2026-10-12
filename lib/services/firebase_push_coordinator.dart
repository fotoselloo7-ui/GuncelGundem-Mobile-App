import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../app/app_config.dart';
import '../data/models/push_notification_model.dart';
import '../data/repositories/device_repository.dart';
import 'notification_permission_service.dart';
import 'notification_inbox_service.dart';
import 'push_service.dart';

/// Android/iOS Firebase Messaging köprüsü.
///
/// Mevcut onboarding bildirim izni ve cihaz tercihlerini kullanır.
/// iOS plist/APNs yapılandırılana kadar güvenle pasif kalır.
class FirebasePushCoordinator {
  FirebasePushCoordinator._();

  static final FirebasePushCoordinator instance = FirebasePushCoordinator._();

  final DeviceRepository _devices = DeviceRepository();
  final NotificationPermissionService _permissions =
      NotificationPermissionService();
  final PushService _push = PushService();
  final NotificationInboxService _inbox = NotificationInboxService.instance;
  final StreamController<PushNotificationPayload> _foreground =
      StreamController<PushNotificationPayload>.broadcast();

  bool _started = false;
  bool _syncing = false;

  Stream<PendingNotificationIntent> get onNotificationClicked =>
      _push.onNotificationClicked;

  Stream<PushNotificationPayload> get onForegroundNotification =>
      _foreground.stream;

  Future<void> start() async {
    if (!(Platform.isAndroid || Platform.isIOS) ||
        _started ||
        Firebase.apps.isEmpty) {
      return;
    }
    _started = true;
    try {
      await _inbox.initialize();
      await _push.initialize(isNativeFirebaseConfigured: true);

      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_sendToken(token)),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_openNotification(message)),
      );
      FirebaseMessaging.onMessage.listen((message) {
        final payload = _parsePayload(message);
        unawaited(_inbox.add(payload));
        _foreground.add(payload);
      });

      // Kapalı uygulama bir bildirime dokunularak açılmış olabilir.
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        await _openNotification(initialMessage);
      }

      await syncToken();
    } catch (error) {
      if (kDebugMode) debugPrint('[FCM] Startup error: $error');
      // Firebase sorunu haber uygulamasının açılmasını engellemez.
    }
  }

  /// Uygulama açılışında, resume'da ve onboarding sonunda çağrılır.
  /// Bildirim izni olmayan kullanıcıdan otomatik izin istemez.
  Future<void> syncToken() async {
    if (!_started || _syncing || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    try {
      if (!await _isNotificationsEnabled()) return;
      // Apple FCM token isteğinden önce APNs tokenının hazır olması gerekir.
      if (Platform.isIOS &&
          await FirebaseMessaging.instance.getAPNSToken() == null) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendToken(token);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[FCM] Token retrieval error: $error');
    }
  }

  Future<bool> _isNotificationsEnabled() async {
    final prefs = await _devices.getPreferences();
    if (!prefs.notificationsEnabled) return false;
    return await _permissions.status() == NotificationPermissionStatus.granted;
  }

  Future<void> _sendToken(String token) async {
    if (token.trim().isEmpty || _syncing) return;
    _syncing = true;
    try {
      if (!await _isNotificationsEnabled()) return;
      // Mevcut 4 tester için de önce cihazı idempotent kaydetmeyi deneriz.
      // Sunucu erişilemiyorsa sonraki açılış/resume yeniden dener.
      await _devices.registerDevice(
        appVersion: AppConfig.appVersion,
        locale: 'tr_TR',
      );
      final registered = await _push.handleTokenRefresh(token);
      if (!registered && kDebugMode) {
        debugPrint('[FCM] Token could not be saved to mobile API.');
      }
    } catch (error) {
      if (kDebugMode) debugPrint('[FCM] Token sync error: $error');
    } finally {
      _syncing = false;
    }
  }

  PushNotificationPayload _parsePayload(RemoteMessage message) {
    return PushNotificationPayload.fromJson({
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    });
  }

  Future<void> openForegroundPayload(PushNotificationPayload payload) =>
      _push.handleNotificationOpen(payload);

  Future<void> _openNotification(RemoteMessage message) async {
    try {
      final payload = _parsePayload(message);
      await _inbox.add(payload, markRead: true);
      await _push.handleNotificationOpen(payload);
    } catch (error) {
      if (kDebugMode) debugPrint('[FCM] Notification open error: $error');
    }
  }
}
