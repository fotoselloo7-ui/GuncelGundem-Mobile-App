import 'package:flutter/services.dart';

/// İşletim Sistemi Bildirim İzni Durumu
///
/// Android 13+ (API 33) `POST_NOTIFICATIONS` runtime izni ve daha eski
/// sürümlerdeki bildirim açık/kapalı durumunu tek bir sözleşmede birleştirir.
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
/// Firebase / FCM mimarisinden bağımsızdır. Native katman mevcut değilse
/// (ör. iOS, test ortamı veya eski cihaz) ASLA çökmez; güvenli bir
/// [NotificationPermissionStatus.notApplicable] döner.
class NotificationPermissionService {
  static const MethodChannel defaultChannel = MethodChannel(
    'tr.guncelgundem/notifications',
  );

  final MethodChannel _channel;

  NotificationPermissionService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  /// Mevcut izin durumunu sorgular (dialog göstermez).
  Future<NotificationPermissionStatus> status() async {
    return _invoke('checkStatus');
  }

  /// İzni ister. Android 13+ üzerinde sistem dialogunu tetikler.
  ///
  /// İzin zaten verilmişse dialog göstermeden [granted] döner.
  Future<NotificationPermissionStatus> request() async {
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
