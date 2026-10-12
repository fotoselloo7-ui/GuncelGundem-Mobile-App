import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

/// İşletim Sistemi Bildirim İzni Durumu
///
/// Android 13+ `POST_NOTIFICATIONS` ve iOS UNAuthorizationStatus
/// durumlarını tek bir sözleşmede birleştirir.
enum NotificationPermissionStatus {
  /// İzin verildi, bildirim gösterilebilir.
  granted,

  /// İzin reddedildi ancak tekrar istenebilir.
  denied,

  /// Kullanıcı kalıcı olarak reddetti; yalnız sistem ayarlarından açılabilir.
  permanentlyDenied,

  /// Bu platform/sürüm için runtime izni gerekmiyor veya belirlenemedi.
  notApplicable,
}

/// İşletim sistemi bildirim izni köprüsü (MethodChannel).
///
/// Android mevcut native MethodChannel köprüsünü, iOS ise FlutterFire
/// izin API'sini kullanır. Firebase eksikse güvenli biçimde notApplicable döner.
class NotificationPermissionService {
  static const MethodChannel defaultChannel = MethodChannel(
    'tr.guncelgundem/notifications',
  );

  final MethodChannel _channel;

  NotificationPermissionService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  /// Mevcut izin durumunu sorgular (dialog göstermez).
  Future<NotificationPermissionStatus> status() async {
    if (Platform.isIOS) return _iosStatus();
    return _invoke('checkStatus');
  }

  /// İzni ister. Android 13+ üzerinde sistem dialogunu tetikler.
  ///
  /// İzin zaten verilmişse dialog göstermeden [granted] döner.
  Future<NotificationPermissionStatus> request() async {
    if (Platform.isIOS) return _iosRequest();
    return _invoke('request');
  }

  /// Uygulamanın sistem bildirim ayarları ekranını açar.
  ///
  /// Kalıcı reddetme durumunda kullanıcıyı yönlendirmek için kullanılır.
  Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openSettings');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<NotificationPermissionStatus> _iosStatus() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return _mapIosAuthorization(settings.authorizationStatus);
    } catch (_) {
      return NotificationPermissionStatus.notApplicable;
    }
  }

  Future<NotificationPermissionStatus> _iosRequest() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      return _mapIosAuthorization(settings.authorizationStatus);
    } catch (_) {
      return NotificationPermissionStatus.notApplicable;
    }
  }

  static NotificationPermissionStatus _mapIosAuthorization(
    AuthorizationStatus status,
  ) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
      case AuthorizationStatus.ephemeral:
        return NotificationPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return NotificationPermissionStatus.permanentlyDenied;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionStatus.denied;
    }
  }

  Future<NotificationPermissionStatus> _invoke(String method) async {
    try {
      final result = await _channel.invokeMethod<String>(method);
      return _parse(result);
    } on PlatformException {
      return NotificationPermissionStatus.notApplicable;
    } on MissingPluginException {
      // Native köprü yok (iOS/test/eski runtime) — güvenli varsayılan.
      return NotificationPermissionStatus.notApplicable;
    }
  }

  static NotificationPermissionStatus _parse(String? raw) {
    switch (raw) {
      case 'granted':
        return NotificationPermissionStatus.granted;
      case 'denied':
        return NotificationPermissionStatus.denied;
      case 'permanentlyDenied':
        return NotificationPermissionStatus.permanentlyDenied;
      case 'notApplicable':
      default:
        return NotificationPermissionStatus.notApplicable;
    }
  }
}
