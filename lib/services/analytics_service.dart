import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/repositories/device_repository.dart';

/// Mobil Analitik Servisi
///
/// FAZ 5 / ANONİM OLAY VE ETKİLEŞİM TAKİBİ
///
/// Gizlilik ve Veri Minimizasyonu:
/// Asla IMEI, telefon numarası, MAC adresi veya kişisel profil toplamaz.
/// Yalnız anonim device_id, campaign_id, event_type ve zaman damgası gönderir.
class AnalyticsService {
  final ApiClient _client;
  final DeviceRepository _deviceRepository;

  /// Bellek içi dedup/debounce tablosu (tekrarlanan widget renderlarında spam engelleme)
  final Set<String> _recentEvents = {};

  AnalyticsService({ApiClient? apiClient, DeviceRepository? deviceRepository})
    : _client = apiClient ?? ApiClient(),
      _deviceRepository = deviceRepository ?? DeviceRepository();

  /// Bildirim Açılışı (Notification Open Tracking)
  Future<bool> trackNotificationOpen({
    required String pushEventId,
    String? campaignId,
    String? newsId,
  }) async {
    final dedupKey = 'open_$pushEventId';
    if (_recentEvents.contains(dedupKey)) {
      return true; // Kısa süre önce zaten gönderildi
    }
    _recentEvents.add(dedupKey);

    final payload = <String, dynamic>{
      'event_type': 'notification_open',
      'push_event_id': pushEventId,
      'occurred_at': DateTime.now().toIso8601String(),
    };
    if (campaignId != null) payload['campaign_id'] = campaignId;
    if (newsId != null) payload['news_id'] = newsId;

    return _sendEvent(payload);
  }

  /// Reklam Gösterimi (Ad Impression Tracking)
  Future<bool> trackAdImpression({
    required String campaignId,
    required String placementId,
    String? newsId,
    String? categoryId,
    String? locationId,
  }) async {
    final dedupKey = 'imp_${campaignId}_$placementId';
    if (_recentEvents.contains(dedupKey)) {
      return true;
    }
    _recentEvents.add(dedupKey);

    final payload = <String, dynamic>{
      'event_type': 'ad_impression',
      'campaign_id': campaignId,
      'placement_id': placementId,
      'occurred_at': DateTime.now().toIso8601String(),
    };
    if (newsId != null) payload['news_id'] = newsId;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (locationId != null) payload['location_id'] = locationId;

    return _sendEvent(payload);
  }

  /// Reklam Tıklaması (Ad Click Tracking)
  Future<bool> trackAdClick({
    required String campaignId,
    required String placementId,
    String? newsId,
    String? categoryId,
    String? locationId,
  }) async {
    final dedupKey =
        'click_${campaignId}_${DateTime.now().millisecondsSinceEpoch ~/ 3000}';
    if (_recentEvents.contains(dedupKey)) {
      return true; // 3 saniye içinde mükerrer tıklama debounce
    }
    _recentEvents.add(dedupKey);

    final payload = <String, dynamic>{
      'event_type': 'ad_click',
      'campaign_id': campaignId,
      'placement_id': placementId,
      'occurred_at': DateTime.now().toIso8601String(),
    };
    if (newsId != null) payload['news_id'] = newsId;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (locationId != null) payload['location_id'] = locationId;

    return _sendEvent(payload);
  }

  Future<bool> _sendEvent(Map<String, dynamic> eventData) async {
    try {
      final deviceId = await _deviceRepository.getDeviceId();
      eventData['device_id'] = deviceId;

      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.analyticsEvents,
        data: eventData,
        fromDataJson: (json) =>
            json is Map<String, dynamic> ? json : const <String, dynamic>{},
      );
      return response.success;
    } catch (_) {
      // Analitik hataları uygulamayı veya UI akışını asla bozmaz
      return false;
    }
  }

  /// Test veya oturum yenileme için önbelleği temizler
  void clearRecentEvents() {
    _recentEvents.clear();
  }
}
