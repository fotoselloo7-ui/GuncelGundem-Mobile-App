import 'package:equatable/equatable.dart';

import 'notification_preference_model.dart';

/// Mobil Cihaz Modeli
class DeviceModel extends Equatable {
  final String deviceId;
  final String platform;
  final String appVersion;
  final String locale;
  final String? pushToken;
  final NotificationPreferenceModel preferences;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeenAt;

  const DeviceModel({
    required this.deviceId,
    required this.platform,
    this.appVersion = '1.0.0',
    this.locale = 'tr_TR',
    this.pushToken,
    this.preferences = const NotificationPreferenceModel(),
    this.createdAt,
    this.updatedAt,
    this.lastSeenAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final rawPrefs = json['preferences'];
    final prefs = rawPrefs is Map<String, dynamic>
        ? NotificationPreferenceModel.fromJson(rawPrefs)
        : const NotificationPreferenceModel();

    return DeviceModel(
      deviceId: (json['device_id'] as String?) ?? '',
      platform: (json['platform'] as String?) ?? 'android',
      appVersion: (json['app_version'] as String?) ?? '1.0.0',
      locale: (json['locale'] as String?) ?? 'tr_TR',
      pushToken: json['push_token'] as String?,
      preferences: prefs,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'platform': platform,
    'app_version': appVersion,
    'locale': locale,
    'push_token': pushToken,
    'preferences': preferences.toJson(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    deviceId,
    platform,
    appVersion,
    locale,
    pushToken,
    preferences,
    createdAt,
    updatedAt,
    lastSeenAt,
  ];
}
