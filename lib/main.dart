import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_startup.dart';
import 'data/models/push_notification_model.dart';
import 'services/notification_inbox_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  final payload = PushNotificationPayload.fromJson({
    ...message.data,
    if (message.notification?.title != null)
      'title': message.notification!.title,
    if (message.notification?.body != null)
      'body': message.notification!.body,
  });
  await NotificationInboxService.instance.add(payload);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android google-services.json, iOS GoogleService-Info.plist üzerinden
  // yapılandırılır. iOS plist henüz eklenmemişse uygulama Firebase olmadan açılır.
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (error) {
      if (kDebugMode) debugPrint('[FCM] Firebase init error: $error');
    }
  }

  await NotificationInboxService.instance.initialize();

  final startupCoordinator = AppStartupCoordinator();
  runApp(GuncelGundemApp(startupCoordinator: startupCoordinator));
}
