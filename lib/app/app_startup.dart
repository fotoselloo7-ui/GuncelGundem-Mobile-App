import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/local_cache_service.dart';
import '../data/models/app_config_model.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/taxonomy_repository.dart';
import '../design/branding_state.dart';
import '../services/version_check_service.dart';
import 'app_config.dart';
import 'bottom_nav_preferences.dart';

/// Başlangıç Durumları
sealed class StartupState extends Equatable {
  const StartupState();

  @override
  List<Object?> get props => [];
}

class StartupInitial extends StartupState {}

class StartupLoading extends StartupState {
  final String step;
  const StartupLoading(this.step);

  @override
  List<Object?> get props => [step];
}

class StartupMaintenance extends StartupState {
  final String? message;
  const StartupMaintenance(this.message);

  @override
  List<Object?> get props => [message];
}

class StartupForceUpdate extends StartupState {
  final String? minimumVersion;
  const StartupForceUpdate(this.minimumVersion);

  @override
  List<Object?> get props => [minimumVersion];
}

class StartupReady extends StartupState {
  final AppConfigModel config;
  final bool needsOnboarding;
  final bool recommendsUpdate;

  const StartupReady({
    required this.config,
    required this.needsOnboarding,
    this.recommendsUpdate = false,
  });

  @override
  List<Object?> get props => [config, needsOnboarding, recommendsUpdate];
}

class StartupFailed extends StartupState {
  final String error;
  const StartupFailed(this.error);

  @override
  List<Object?> get props => [error];
}

/// Uygulama Başlangıç Koordinatörü
///
/// Başlangıç adımlarını sıralı olarak icra eder ve UI için durum üretir.
class AppStartupCoordinator {
  final ConfigRepository _configRepository;
  final LocalCacheService _cacheService;

  static const String onboardingKey = 'user_onboarding_completed_v1';

  AppStartupCoordinator({
    ConfigRepository? configRepository,
    LocalCacheService? cacheService,
  }) : _configRepository = configRepository ?? ConfigRepository(),
       _cacheService = cacheService ?? LocalCacheService.instance;

  /// Başlangıç. Bu metot ARTIK ASLA throw ETMEZ ve her patikada
  /// [StartupReady] / [StartupMaintenance] / [StartupForceUpdate] döner.
  /// Beklenmedik bir hata bile [StartupReady] + bundled default'a düşer;
  /// "Başlatma Hatası" ekranı tamamen devre dışıdır.
  Future<StartupState> start() async {
    try {
      return await _runStart();
    } catch (_) {
      // Son savunma hattı: akışın herhangi bir yerinde beklenmedik bir
      // istisna uçsa bile uygulamayı asla kilitleme. Bundled default ile aç.
      return StartupReady(
        config: AppConfig.bundledDefaultConfig(),
        needsOnboarding: false,
        recommendsUpdate: false,
      );
    }
  }

  Future<StartupState> _runStart() async {
    // 1. Önbellek, yerel depolama ve onboarding bayrağı. Bu adımlar
    //    başarısız olsa bile uygulamayı kilitlemez: güvenli varsayılanlarla
    //    devam ederiz.
    try {
      await _cacheService.init();
    } catch (_) {
      // Diske yazılamıyor olabilir; memory cache devrededir.
    }

    bool onboardingDone = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool(onboardingKey) ?? false;
    } catch (_) {}
    try {
      await BottomNavPreferences.instance.load();
    } catch (_) {}

    // 2. Konfigürasyonu çözümle: Remote → Cache → Bundled Default.
    //    Hiçbir ağ hatası bu uygulamayı artık "Başlatma Hatası" ekranına
    //    kilitlemez. Remote config döndüğünde branding otomatik güncellenir.
    _ResolvedConfig resolved;
    try {
      resolved = await _resolveConfig();
    } catch (_) {
      resolved = _ResolvedConfig(
        AppConfig.bundledDefaultConfig(),
        _ConfigSource.bundled,
      );
    }
    final config = resolved.config;

    // 3. Server-Driven Branding güncelle.
    try {
      BrandingState.instance.updateFromConfig(config);
    } catch (_) {}

    // 4. Bakım Modu (yalnız remote confirmed olduğunda uygulanır — bundled
    //    default'ta maintenanceMode yoktur, bu yüzden ekstra kontrol gereksiz).
    if (config.maintenanceMode) {
      return StartupMaintenance(config.maintenanceMessage);
    }

    // 5. Zorunlu güncelleme denetimi (yalnız remote config varsa güvenli).
    if (resolved.source == _ConfigSource.remote) {
      final versionResult = VersionCheckService.check(
        currentVersion: AppConfig.appVersion,
        config: config,
      );
      if (versionResult.needsForceUpdate) {
        return StartupForceUpdate(versionResult.minimumVersion);
      }
      // 6. İlk kurulumda şehir/kategori taksonomisini önceden ısıt. Süre
      //    sınırlıdır; yavaş ağda onboarding kendi yükleme durumuyla devam
      //    eder — yapay bekleme yoktur.
      if (!onboardingDone) {
        await _prefetchTaxonomy();
      }
      return StartupReady(
        config: config,
        needsOnboarding: !onboardingDone,
        recommendsUpdate: versionResult.recommendsUpdate,
      );
    }

    // Cache veya bundled fallback ile açıldıysak force-update'i uygulamayız
    // (eski kriterle kullanıcıyı yanlışlıkla kilitleyebilirdik).
    return StartupReady(
      config: config,
      needsOnboarding: !onboardingDone,
      recommendsUpdate: false,
    );
  }

  Future<_ResolvedConfig> _resolveConfig() async {
    // Remote: kullanıcı-nazik timeout. İçinde zaten offline-first cache fallback var.
    try {
      final config = await _configRepository.getConfig().timeout(
        AppConfig.startupConfigTimeout,
      );
      return _ResolvedConfig(config, _ConfigSource.remote);
    } catch (_) {
      // Remote yolu başarısız: önce diskteki son başarılı config, sonra bundled.
    }
    try {
      final cached = await _configRepository.getCachedConfig();
      if (cached != null) {
        // Arka planda sessizce yenilemeyi dene; sonucu bekleyen UI yok.
        unawaited(
          _configRepository
              .getConfig(forceRefresh: true)
              .then<void>((_) {})
              .catchError((Object _) {}),
        );
        return _ResolvedConfig(cached, _ConfigSource.cache);
      }
    } catch (_) {}
    unawaited(
      _configRepository
          .getConfig(forceRefresh: true)
          .then<void>((_) {})
          .catchError((Object _) {}),
    );
    return _ResolvedConfig(
      AppConfig.bundledDefaultConfig(),
      _ConfigSource.bundled,
    );
  }

  Future<void> _prefetchTaxonomy() async {
    final taxonomy = TaxonomyRepository();
    try {
      await Future.wait<Object?>([
        taxonomy
            .getLocations()
            .then<Object?>((v) => v)
            .catchError((Object _) => null),
        taxonomy
            .getCategories()
            .then<Object?>((v) => v)
            .catchError((Object _) => null),
      ]).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Zaman aşımı: veriler onboarding içinde yüklenmeye devam eder.
    }
  }

  /// Onboarding tamamlandı olarak işaretler
  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingKey, true);
  }
}

/// Config'in nereden geldiğini startup koordinatörüne aktaran dahili tip.
enum _ConfigSource { remote, cache, bundled }

class _ResolvedConfig {
  final AppConfigModel config;
  final _ConfigSource source;
  const _ResolvedConfig(this.config, this.source);
}
