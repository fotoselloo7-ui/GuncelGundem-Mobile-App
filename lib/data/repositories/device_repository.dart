import 'dart:io';

import '../../core/storage/device_storage.dart';
import '../../services/api_service.dart';
import '../models/device_model.dart';
import '../models/notification_preference_model.dart';

/// Mobil Cihaz ve Bildirim Tercihleri Veri Deposu
///
/// UI bağımsızdır, hiçbir Widget import etmez.
/// Anonim UUID yönetimi, yerel tercihler ve sunucu senkronizasyonunu koordine eder.
class DeviceRepository {
  final ApiService _apiService;
  final DeviceStorage _storage;

  DeviceRepository({ApiService? apiService, DeviceStorage? storage})
    : _apiService = apiService ?? ApiService(),
      _storage = storage ?? DeviceStorage();

  /// Anonim cihaz kimliğini döner (yoksa üretir ve saklar)
  Future<String> getDeviceId() async {
    return _storage.getOrCreateDeviceId();
  }

  /// Yerel bildirim tercihlerini okur
  Future<NotificationPreferenceModel> getPreferences() async {
    return _storage.getPreferences();
  }

  /// Bekleyen senkronizasyon var mı?
  Future<bool> isPendingSync() async {
    return _storage.isPendingSync();
  }

  /// Cihazı sunucuya kaydeder veya senkronize eder (Startup/Onboarding)
  Future<DeviceModel?> registerDevice({
    String? platform,
    String? appVersion,
    String? locale,
  }) async {
    final deviceId = await getDeviceId();
    final prefs = await getPreferences();
    final detectedPlatform =
        platform ??
        (Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : 'android');

    final payload = <String, dynamic>{
      'device_id': deviceId,
      'platform': detectedPlatform,
      'preferences': prefs.toJson(),
    };
    if (appVersion != null) {
      payload['app_version'] = appVersion;
    }
    if (locale != null) {
      payload['locale'] = locale;
    }

    try {
      final response = await _apiService.registerDevice(payload);
      await _storage.clearPendingSync();
      return response.data;
    } catch (_) {
      // Offline veya sunucu hatasında yerelde saklanmaya devam eder
      return null;
    }
  }

  /// Bildirim tercihlerini günceller (Offline-first & Dirty flag)
  Future<bool> updatePreferences(
    NotificationPreferenceModel newPreferences,
  ) async {
    // 1. Önce anında yerel depoya kaydet ve pending olarak işaretle
    await _storage.savePreferences(newPreferences, markPending: true);

    // 2. Çevrimiçi ise hemen sunucuya gönder
    try {
      final deviceId = await getDeviceId();
      final response = await _apiService.updateDevice(deviceId, {
        'preferences': newPreferences.toJson(),
      });

      if (response.success) {
        await _storage.clearPendingSync();
        return true;
      }
    } catch (_) {
      // Ağ hatası durumunda yerel kayıt korunur ve pending kalır
    }

    return false;
  }

  /// Bekleyen tercih değişikliklerini sunucuya senkronize eder
  Future<bool> syncPendingPreferences() async {
    final pending = await _storage.isPendingSync();
    if (!pending) return true;

    try {
      final deviceId = await getDeviceId();
      final prefs = await _storage.getPreferences();

      final response = await _apiService.updateDevice(deviceId, {
        'preferences': prefs.toJson(),
      });

      if (response.success) {
        await _storage.clearPendingSync();
        return true;
      }
    } catch (_) {
      // Yeniden deneme sonraki resume/online anına bırakılır
    }

    return false;
  }

  /// Sunucudan gelen güncel kategoriler ve lokasyonlar ile yerel tercihleri temizler
  ///
  /// Kaldırılan/pasif yapılan ID'ler local preference'dan güvenle silinir.
  Future<void> sanitizePreferencesAgainstTaxonomy({
    List<String>? validCategoryIds,
    List<String>? validLocationIds,
  }) async {
    final prefs = await getPreferences();
    bool modified = false;

    List<String> cleanedCategoryIds = prefs.categoryIds;
    if (validCategoryIds != null && validCategoryIds.isNotEmpty) {
      final validSet = validCategoryIds.toSet();
      final filtered = prefs.categoryIds
          .where((id) => validSet.contains(id))
          .toList();
      if (filtered.length != prefs.categoryIds.length) {
        cleanedCategoryIds = filtered;
        modified = true;
      }
    }

    List<String> cleanedLocationIds = prefs.locationIds;
    if (validLocationIds != null && validLocationIds.isNotEmpty) {
      final validSet = validLocationIds.toSet();
      final filtered = prefs.locationIds
          .where((id) => validSet.contains(id))
          .toList();
      if (filtered.length != prefs.locationIds.length) {
        cleanedLocationIds = filtered;
        modified = true;
      }
    }

    if (modified) {
      final updated = prefs.copyWith(
        categoryIds: cleanedCategoryIds,
        locationIds: cleanedLocationIds,
      );
      await _storage.savePreferences(updated, markPending: true);
    }
  }

  /// Push token'ını sunucuya senkronize eder
  Future<bool> updatePushToken(String token) async {
    try {
      final deviceId = await getDeviceId();
      final response = await _apiService.updateDevice(deviceId, {
        'push_token': token,
      });
      return response.success;
    } catch (_) {
      return false;
    }
  }
}
