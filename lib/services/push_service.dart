import 'dart:async';

import '../data/models/push_notification_model.dart';
import '../data/repositories/device_repository.dart';
import 'analytics_service.dart';

/// Firebase / FCM Push Servisi Durumu
enum PushServiceStatus {
  /// Firebase yapılandırma dosyaları mevcut ve servis hazır
  ready,

  /// google-services.json veya GoogleService-Info.plist eksik
  firebaseConfigurationRequired,

  /// İşletim sistemi bildirim izni verilmedi
  permissionDenied,

  /// Hata durumu
  error,
}

/// Mobil Push Bildirim Servisi
///
/// FAZ 5 / FIREBASE PUSH VE BİLDİRİM KOORDİNASYONU
///
/// White-label ve güvenli mimari:
/// Native Firebase kimlik bilgileri eksikse ASLA çökmez,
/// [PushServiceStatus.firebaseConfigurationRequired] durumunu raporlar.
class PushService {
  final DeviceRepository _deviceRepository;
  final AnalyticsService _analyticsService;

  PushServiceStatus _status = PushServiceStatus.firebaseConfigurationRequired;
  String? _currentToken;

  /// Bildirim tıklandığında UI katmanını haberdar eden yayın akışı (Stream)
  final StreamController<PendingNotificationIntent>
  _notificationClickController =
      StreamController<PendingNotificationIntent>.broadcast();

  PushService({
    DeviceRepository? deviceRepository,
    AnalyticsService? analyticsService,
  }) : _deviceRepository = deviceRepository ?? DeviceRepository(),
       _analyticsService = analyticsService ?? AnalyticsService();

  /// Mevcut servis durumu
  PushServiceStatus get status => _status;

  /// Bildirim tıklama olay akışı
  Stream<PendingNotificationIntent> get onNotificationClicked =>
      _notificationClickController.stream;

  /// Mevcut token (maskelenmiş önizleme ile)
  String? get maskedToken {
    if (_currentToken == null || _currentToken!.length < 10) return null;
    return '${_currentToken!.substring(0, 6)}...${_currentToken!.substring(_currentToken!.length - 4)}';
  }

  /// Servisi başlatır
  Future<PushServiceStatus> initialize({
    bool isNativeFirebaseConfigured = false,
  }) async {
    if (!isNativeFirebaseConfigured) {
      _status = PushServiceStatus.firebaseConfigurationRequired;
      return _status;
    }

    _status = PushServiceStatus.ready;
    return _status;
  }

  /// Kullanıcıdan işletim sistemi seviyesinde bildirim izni talep eder
  Future<bool> requestPermission({
    bool permissionGrantedBySystem = true,
  }) async {
    if (!permissionGrantedBySystem) {
      _status = PushServiceStatus.permissionDenied;
      return false;
    }

    if (_status != PushServiceStatus.ready) {
      // Firebase konfigürasyonu bekleniyor ise durumu koru
      return true;
    }

    return true;
  }

  /// FCM Token alındığında veya yenilendiğinde sunucuya kaydeder
  ///
  /// Mevcut kullanıcı tercihlerini (kategoriler, lokasyonlar, sessiz saatler)
  /// ASLA ezmez, yalnız push_token alanını güvenle günceller.
  Future<bool> handleTokenRefresh(String newToken) async {
    if (newToken.trim().isEmpty) return false;

    _currentToken = newToken;

    // Sunucuya cihaz token senkronizasyonu
    final success = await _deviceRepository.updatePushToken(newToken);
    return success;
  }

  /// Cihaza gelen bildirim verisini işler
  PushNotificationPayload parseIncomingPayload(Map<String, dynamic> rawData) {
    return PushNotificationPayload.fromJson(rawData);
  }

  /// Kullanıcı bildirime tıkladığında çalışır
  ///
  /// 1. Anonim open tracking analiz eventini gönderir.
  /// 2. İlgili habere veya sayfaya yönlendirme intent'ini yayına verir.
  Future<void> handleNotificationOpen(PushNotificationPayload payload) async {
    final pushEventId = payload.pushEventId;
    if (pushEventId != null && pushEventId.isNotEmpty) {
      // Güvenli asenkron analytics bildirimi (hata fırlatmaz)
      unawaited(
        _analyticsService.trackNotificationOpen(
          pushEventId: pushEventId,
          campaignId: pushEventId,
          newsId: payload.newsId,
        ),
      );
    }

    final intent = PendingNotificationIntent.fromPayload(payload);
    _notificationClickController.add(intent);
  }

  /// Kaynakları serbest bırakır
  void dispose() {
    _notificationClickController.close();
  }
}
