import 'package:flutter/foundation.dart';

import '../data/models/app_config_model.dart';
import '../data/models/home_model.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/home_repository.dart';
import '../data/repositories/taxonomy_repository.dart';
import '../design/branding_state.dart';

/// Senkronizasyon Koordinatörü
///
/// Uygulama başlangıcı (startup) ve ön plana gelme (resume) durumlarında
/// dinamik marka, ana sayfa akışı, taksonomi ve cihaz tercihlerinin
/// ETag ve TTL tabanlı akıllı senkronizasyonunu yönetir.
/// Sürekli polling yapmaz, ağ tasarrufu sağlar.
class SyncCoordinator {
  static SyncCoordinator? _instance;
  static SyncCoordinator get instance => _instance ??= SyncCoordinator._();

  SyncCoordinator._() : this();

  final ConfigRepository _configRepository;
  final HomeRepository _homeRepository;
  final TaxonomyRepository _taxonomyRepository;
  final DeviceRepository _deviceRepository;
  final BrandingState _brandingState;

  DateTime? _lastSyncTime;
  final Duration resumeThreshold;

  SyncCoordinator({
    ConfigRepository? configRepository,
    HomeRepository? homeRepository,
    TaxonomyRepository? taxonomyRepository,
    DeviceRepository? deviceRepository,
    BrandingState? brandingState,
    this.resumeThreshold = const Duration(seconds: 60),
  }) : _configRepository = configRepository ?? ConfigRepository(),
       _homeRepository = homeRepository ?? HomeRepository(),
       _taxonomyRepository = taxonomyRepository ?? TaxonomyRepository(),
       _deviceRepository = deviceRepository ?? DeviceRepository(),
       _brandingState = brandingState ?? BrandingState.instance;

  DateTime? get lastSyncTime => _lastSyncTime;

  /// Uygulama Başlangıç Senkronizasyonu (Startup)
  ///
  /// Sıralı akış:
  /// 1. GET /config revalidate -> BrandingState güncelle
  /// 2. Categories & Locations revalidate (Gerekirse)
  /// 3. Device preferences temizle (kaldırılmış ID'leri ayıkla)
  /// 4. Varsa pending bildirim tercihlerini sunucuya gönder
  /// 5. Home refresh (Authoritative replace)
  Future<SyncResult> syncOnStartup({bool force = false}) async {
    AppConfigModel? config;
    HomeModel? home;
    bool configUpdated = false;
    bool homeUpdated = false;

    // 1. Config Revalidate & Dynamic Branding
    try {
      config = await _configRepository.getConfig(forceRefresh: force);
      _brandingState.updateFromConfig(config);
      configUpdated = true;
    } catch (e) {
      if (kDebugMode) {
        print('[SyncCoordinator] Config sync error: $e');
      }
      config = await _configRepository.getCachedConfig();
      if (config != null) {
        _brandingState.updateFromConfig(config);
      }
    }

    // 2. Taksonomi Revalidate & Tercih Temizliği
    try {
      final categories = await _taxonomyRepository.getCategories(
        forceRefresh: force,
      );
      final locations = await _taxonomyRepository.getLocations(
        forceRefresh: force,
      );

      final validCatIds = categories.map((c) => c.id).toList();
      final validLocIds = <String>[];
      for (final p in locations) {
        validLocIds.add(p.id);
        for (final d in p.districts) {
          validLocIds.add(d.id);
        }
      }

      await _deviceRepository.sanitizePreferencesAgainstTaxonomy(
        validCategoryIds: validCatIds,
        validLocationIds: validLocIds,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[SyncCoordinator] Taxonomy sync error: $e');
      }
    }

    // 3. Bekleyen Tercihleri Eşle
    try {
      await _deviceRepository.syncPendingPreferences();
    } catch (_) {}

    // 4. Home Revalidate (Authoritative replace)
    try {
      home = await _homeRepository.getHome(forceRefresh: force);
      homeUpdated = true;
    } catch (e) {
      if (kDebugMode) {
        print('[SyncCoordinator] Home sync error: $e');
      }
      home = await _homeRepository.getCachedHome();
    }

    _lastSyncTime = DateTime.now();

    return SyncResult(
      config: config,
      home: home,
      configUpdated: configUpdated,
      homeUpdated: homeUpdated,
    );
  }

  /// Uygulama Ön Plana Geldiğinde Senkronizasyon (App Resume)
  ///
  /// Eşik süresi (resumeThreshold - varsayılan 60sn) aşılmadıysa istek yapmaz.
  /// Süre aşıldıysa config ve home'u ETag ile revalidate eder.
  Future<bool> syncOnResume() async {
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < resumeThreshold) {
      // Eşik süresi henüz dolmadı, gereksiz ağ trafiği oluşturma
      return false;
    }

    try {
      // 1. Config revalidate & branding update
      final config = await _configRepository.getConfig();
      _brandingState.updateFromConfig(config);

      // 2. Home revalidate
      await _homeRepository.getHome();

      // 3. Varsa bekleyen offline tercihleri gönder
      await _deviceRepository.syncPendingPreferences();

      _lastSyncTime = DateTime.now();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[SyncCoordinator] Resume sync failed: $e');
      }
      return false;
    }
  }
}

/// Senkronizasyon Sonucu
class SyncResult {
  final AppConfigModel? config;
  final HomeModel? home;
  final bool configUpdated;
  final bool homeUpdated;

  const SyncResult({
    this.config,
    this.home,
    this.configUpdated = false,
    this.homeUpdated = false,
  });
}
