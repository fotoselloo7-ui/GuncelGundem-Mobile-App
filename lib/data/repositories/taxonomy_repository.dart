import '../../app/app_config.dart';
import '../../core/storage/local_cache_service.dart';
import '../../services/api_service.dart';
import '../models/category_model.dart';
import '../models/location_model.dart';

/// Kategori ve Lokasyon Taksonomisi Veri Deposu
class TaxonomyRepository {
  final ApiService _apiService;
  final LocalCacheService _cacheService;

  static const String categoriesCacheKey = 'cache_categories_v1';
  static const String locationsCacheKey = 'cache_locations_v1';

  TaxonomyRepository({ApiService? apiService, LocalCacheService? cacheService})
    : _apiService = apiService ?? ApiService(),
      _cacheService = cacheService ?? LocalCacheService.instance;

  /// Kategorileri Getirir
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    final cachedEntry = await _cacheService.get(categoriesCacheKey);
    final etag = forceRefresh ? null : cachedEntry?.etag;
    final cachedPayload = cachedEntry?.payload;

    try {
      final response = await _apiService.getCategories(
        etag: etag,
        cachedPayload: cachedPayload,
      );

      final items = response.data ?? const [];
      if (!response.isFromCache) {
        await _cacheService.set(
          categoriesCacheKey,
          items.map((c) => c.toJson()).toList(),
          etag: response.etag,
          ttl: AppConfig.categoriesCacheTtl,
        );
      }
      return items;
    } catch (_) {
      if (cachedPayload is List) {
        return cachedPayload
            .whereType<Map<String, dynamic>>()
            .map((c) => CategoryModel.fromJson(c))
            .toList();
      }
      rethrow;
    }
  }

  /// Lokasyonları Getirir (81 İl ve İlçeleri)
  Future<List<LocationProvinceModel>> getLocations({
    bool forceRefresh = false,
  }) async {
    final cachedEntry = await _cacheService.get(locationsCacheKey);
    final etag = forceRefresh ? null : cachedEntry?.etag;
    final cachedPayload = cachedEntry?.payload;

    try {
      final response = await _apiService.getLocations(
        etag: etag,
        cachedPayload: cachedPayload,
      );

      final items = response.data ?? const [];
      if (!response.isFromCache && items.isNotEmpty) {
        await _cacheService.set(
          locationsCacheKey,
          items.map((p) => p.toJson()).toList(),
          etag: response.etag,
          ttl: AppConfig.locationsCacheTtl,
        );
      }
      return items;
    } catch (_) {
      if (cachedPayload is List) {
        return cachedPayload
            .whereType<Map<String, dynamic>>()
            .map((p) => LocationProvinceModel.fromJson(p))
            .toList();
      }
      rethrow;
    }
  }

  /// Şehir seçim ekranları için dayanıklı yükleme.
  ///
  /// Geçici yavaşlık/boş yanıt tek seferde nihai hata sayılmaz: kısa bir
  /// beklemeden sonra ETag'siz (forceRefresh) bir kez daha denenir. Önbellek
  /// geri dönüşü [getLocations] içinde zaten uygulanır.
  Future<List<LocationProvinceModel>> getLocationsResilient() async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final items = await getLocations(forceRefresh: attempt > 0);
        if (items.isNotEmpty) return items;
      } catch (e) {
        lastError = e;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    if (lastError != null) throw lastError;
    return const [];
  }
}
