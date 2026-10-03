import 'package:equatable/equatable.dart';

/// Mobil Başlangıç ve Yapılandırma Modeli
class AppConfigModel extends Equatable {
  final String apiVersion;
  final String siteName;
  final String? shortName;
  final String? tagline;
  final String? siteUrl;
  final String? logoUrl;
  final String? logoMobileUrl;
  final String? faviconUrl;
  final Map<String, String>? colors;
  final Map<String, String>? socialLinks;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? minimumAppVersion;
  final String? recommendedAppVersion;
  final bool forceUpdate;
  final Map<String, bool>? features;

  const AppConfigModel({
    required this.apiVersion,
    required this.siteName,
    this.shortName,
    this.tagline,
    this.siteUrl,
    this.logoUrl,
    this.logoMobileUrl,
    this.faviconUrl,
    this.colors,
    this.socialLinks,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minimumAppVersion,
    this.recommendedAppVersion,
    this.forceUpdate = false,
    this.features,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parseStringMap(dynamic map) {
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return null;
    }

    Map<String, bool>? parseBoolMap(dynamic map) {
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return null;
    }

    return AppConfigModel(
      apiVersion: (json['api_version'] as String?) ?? 'v1',
      siteName: (json['site_name'] as String?) ?? 'Güncel Gündem',
      shortName: json['short_name'] as String?,
      tagline: json['tagline'] as String?,
      siteUrl: json['site_url'] as String?,
      logoUrl: json['logo_url'] as String?,
      logoMobileUrl: json['logo_mobile_url'] as String?,
      faviconUrl: json['favicon_url'] as String?,
      colors: parseStringMap(json['colors']),
      socialLinks: parseStringMap(json['social_links']),
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message'] as String?,
      minimumAppVersion: json['minimum_app_version'] as String?,
      recommendedAppVersion: json['recommended_app_version'] as String?,
      forceUpdate: json['force_update'] as bool? ?? false,
      features: parseBoolMap(json['features']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'api_version': apiVersion,
      'site_name': siteName,
      'short_name': shortName,
      'tagline': tagline,
      'site_url': siteUrl,
      'logo_url': logoUrl,
      'logo_mobile_url': logoMobileUrl,
      'favicon_url': faviconUrl,
      'colors': colors,
      'social_links': socialLinks,
      'maintenance_mode': maintenanceMode,
      'maintenance_message': maintenanceMessage,
      'minimum_app_version': minimumAppVersion,
      'recommended_app_version': recommendedAppVersion,
      'force_update': forceUpdate,
      'features': features,
    };
  }

  @override
  List<Object?> get props => [
    apiVersion,
    siteName,
    shortName,
    tagline,
    siteUrl,
    logoUrl,
    logoMobileUrl,
    faviconUrl,
    colors,
    socialLinks,
    maintenanceMode,
    maintenanceMessage,
    minimumAppVersion,
    recommendedAppVersion,
    forceUpdate,
    features,
  ];
}
