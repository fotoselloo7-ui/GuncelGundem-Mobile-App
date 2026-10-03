import '../../app/app_config.dart';
import '../../core/storage/local_cache_service.dart';
import '../../services/api_service.dart';
import '../models/app_config_model.dart';

/// Mobil Konfigürasyon Veri Deposu
///
/// Stale-while-revalidate ve ETag desteği ile konfigürasyonu yönetir.
class ConfigRepository {
  final ApiService _apiService;
  final LocalCacheService _cacheService;

  static const String cacheKey = 'cache_config_v1';

  ConfigRepository({ApiService? apiService, LocalCacheService? cacheService})
    : _apiService = apiService ?? ApiService(),
      _cacheService = cacheService ?? LocalCacheService.instance;

  /// Önbellekteki konfigürasyonu okur (Varsa anında döner)
  Future<AppConfigModel?> getCachedConfig() async {
    final entry = await _cacheService.get(cacheKey);
    if (entry != null && entry.payload is Map<String, dynamic>) {
      return AppConfigModel.fromJson(entry.payload as Map<String, dynamic>);
    }
    return null;
  }

  /// Konfigürasyonu getirir (Stale-While-Revalidate)
  Future<AppConfigModel> getConfig({bool forceRefresh = false}) async {
    final cachedEntry = await _cacheService.get(cacheKey);
    final etag = forceRefresh ? null : cachedEntry?.etag;
    final cachedPayload = cachedEntry?.payload;

    try {
      final response = await _apiService.getConfig(
        etag: etag,
        cachedPayload: cachedPayload,
      );

      if (response.data != null) {
        // Yeni veri geldiyse veya 304 ile cached data teyit edildiyse
        if (!response.isFromCache) {
          await _cacheService.set(
            cacheKey,
            response.data!.toJson(),
            etag: response.etag,
            ttl: AppConfig.configCacheTtl,
          );
        } else if (response.etag != null) {
          await _cacheService.updateEtag(cacheKey, response.etag!);
        }
        return response.data!;
      }
    } catch (_) {
      // Ağ hatasında önbellekte veri varsa onu kullan
      if (cachedPayload is Map<String, dynamic>) {
        return AppConfigModel.fromJson(cachedPayload);
      }
      rethrow;
    }

    throw StateError('Konfigürasyon verisi alınamadı.');
  }
}
