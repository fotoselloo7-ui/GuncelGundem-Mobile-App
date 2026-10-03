import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/notification_preference_model.dart';

/// Cihaz Kimliği ve Yerel Tercihler Depolama Katmanı
///
/// Anonim rastgele UUID v4 üretir ve yerel olarak saklar.
/// Donanım kimliği, IMEI veya telefon numarası KULLANMAZ.
class DeviceStorage {
  static const String _deviceIdKey = 'app_anonymous_device_uuid_v1';
  static const String _preferencesKey = 'app_local_preferences_v1';
  static const String _pendingSyncKey = 'app_preferences_pending_sync_v1';

  final SharedPreferences? _prefsInstance;

  DeviceStorage({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  /// Cihaz için anonim UUID döner. Yoksa yeni oluşturur ve saklar.
  Future<String> getOrCreateDeviceId() async {
    final prefs = await _getPrefs();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = generateUuidV4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// RFC 4122 uyumlu kriptografik rastgele UUID v4 üretir
  static String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Version 4: bits 12-15 of time_hi_and_version set to 0100
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variant 1: bits 6-7 of clock_seq_hi_and_reserved set to 10
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-'
        '${hex[4]}${hex[5]}-'
        '${hex[6]}${hex[7]}-'
        '${hex[8]}${hex[9]}-'
        '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
  }

  /// Yerel bildirim tercihlerini döner
  Future<NotificationPreferenceModel> getPreferences() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_preferencesKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return NotificationPreferenceModel.fromJson(json);
      } catch (_) {}
    }

    return const NotificationPreferenceModel();
  }

  /// Yerel bildirim tercihlerini günceller
  Future<void> savePreferences(
    NotificationPreferenceModel preferences, {
    bool markPending = true,
  }) async {
    final prefs = await _getPrefs();
    final jsonStr = jsonEncode(preferences.toJson());
    await prefs.setString(_preferencesKey, jsonStr);
    if (markPending) {
      await prefs.setBool(_pendingSyncKey, true);
    }
  }

  /// Sunucuyla senkronize edilmeyi bekleyen yerel değişiklik var mı?
  Future<bool> isPendingSync() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_pendingSyncKey) ?? false;
  }

  /// Bekleyen senkronizasyon bayrağını temizler
  Future<void> clearPendingSync() async {
    final prefs = await _getPrefs();
    await prefs.setBool(_pendingSyncKey, false);
  }
}
