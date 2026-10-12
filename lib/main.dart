import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_startup.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android arka plan isolate'ında Firebase'i hazırlar; UI değiştirmez.
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android: android/app/google-services.json varsayılan Firebase uygulamasını
  // yapılandırır. iOS APNs/GoogleService-Info.plist tamamlanana dek dokunulmaz.
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (error) {
      if (kDebugMode) debugPrint('[FCM] Firebase init error: $error');
    }
  }

  final startupCoordinator = AppStartupCoordinator();
  runApp(GuncelGundemApp(startupCoordinator: startupCoordinator));
}
