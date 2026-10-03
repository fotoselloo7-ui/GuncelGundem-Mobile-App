import '../../app/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/network/content_availability.dart';
import '../../core/storage/local_cache_service.dart';
import '../../services/api_service.dart';
import '../models/news_detail_model.dart';
import '../models/news_model.dart';

/// Sayfalanmış Haber Yanıtı Taşıyıcısı
class PaginatedNewsResult {
  final List<NewsModel> news;
  final ApiMeta? meta;
  final bool isFromCache;
  final bool isOffline;

  const PaginatedNewsResult({
    required this.news,
    this.meta,
    this.isFromCache = false,
    this.isOffline = false,
  });

  bool get hasMore =>
      meta?.hasMore ?? (news.length >= AppConfig.defaultPageLimit);
  int get page => meta?.page ?? 1;
}

/// Haber Detayı ve Erişilebilirlik Sonucu
class NewsDetailResult {
  final NewsDetailModel? news;
  final ContentAvailability availability;
  final bool isFromCache;

  const NewsDetailResult({
    this.news,
    required this.availability,
    this.isFromCache = false,
  });

  bool get isAvailable => availability == ContentAvailability.available;
  bool get isUnavailable => availability == ContentAvailability.unavailable;
  bool get isOffline => availability == ContentAvailability.cachedOffline;
}

/// Haber Veri Deposu
class NewsRepository {
  final ApiService _apiService;
  final LocalCacheService _cacheService;

  NewsRepository({ApiService? apiService, LocalCacheService? cacheService})
    : _apiService = apiService ?? ApiService(),
      _cacheService = cacheService ?? LocalCacheService.instance;

  /// Haber Listesi Getirir (Deduplication + Authoritative Replace)
  Future<PaginatedNewsResult> getNews({
    int page = 1,
    int limit = 15,
    String? category,
    String? tag,
    String? author,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'cache_news_p${page}_l${limit}_c${category ?? ''}_t${tag ?? ''}_a${author ?? ''}';
    final cachedEntry = await _cacheService.get(cacheKey);
    final etag = forceRefresh ? null : cachedEntry?.etag;
    final cachedPayload = cachedEntry?.payload;

    try {
      final response = await _apiService.getNews(
        page: page,
        limit: limit,
        category: category,
        tag: tag,
        author: author,
        etag: etag,
        cachedPayload: cachedPayload,
      );

      final rawItems = response.data ?? const [];
      // Duplicate news ID engelle
      final seenIds = <String>{};
      final uniqueItems = <NewsModel>[];
      for (final item in rawItems) {
        if (seenIds.add(item.id)) {
          uniqueItems.add(item);
        }
      }

      // Authoritative replace: Server yanıtı önbelleği tamamen replace eder
      if (!response.isFromCache) {
        await _cacheService.set(
          cacheKey,
          uniqueItems.map((e) => e.toJson()).toList(),
          etag: response.etag,
          ttl: AppConfig.newsListCacheTtl,
        );
      }

      return PaginatedNewsResult(
        news: uniqueItems,
        meta: response.meta,
        isFromCache: response.isFromCache,
      );
    } catch (_) {
      if (cachedPayload is List) {
        final cachedItems = cachedPayload
            .whereType<Map<String, dynamic>>()
            .map((json) => NewsModel.fromJson(json))
            .toList();
        return PaginatedNewsResult(news: cachedItems, isFromCache: true);
      }
      rethrow;
    }
  }

  /// Haber Detayı Getirir
  ///
  /// Sunucu 404 Not Found dönerse stale cache silinir ve istisna fırlatılır.
  Future<NewsDetailModel> getNewsDetail(
    String slugOrId, {
    bool forceRefresh = false,
  }) async {
    final result = await getNewsDetailWithAvailability(
      slugOrId,
      forceRefresh: forceRefresh,
    );

    if (result.isAvailable && result.news != null) {
      return result.news!;
    }

    if (result.isOffline && result.news != null) {
      return result.news!;
    }

    throw const NotFoundException(
      message: 'Haber bulunamadı veya yayından kaldırıldı.',
    );
  }

  /// Haber Detayını ve Durumunu Getirir (ContentAvailability)
  ///
  /// Sunucu 404 dönerse:
  /// 1. Stale news detail cache silinir.
  /// 2. Tüm liste ve ana sayfa önbelleklerinden silinir.
  /// 3. ContentAvailability.unavailable döner.
  Future<NewsDetailResult> getNewsDetailWithAvailability(
    String slugOrId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'cache_news_detail_$slugOrId';
    final cachedEntry = await _cacheService.get(cacheKey);
    final etag = forceRefresh ? null : cachedEntry?.etag;
    final cachedPayload = cachedEntry?.payload;

    try {
      final response = await _apiService.getNewsDetail(
        slugOrId,
        etag: etag,
        cachedPayload: cachedPayload,
      );

      if (response.data != null) {
        if (!response.isFromCache) {
          await _cacheService.set(
            cacheKey,
            response.data!.toJson(),
            etag: response.etag,
            ttl: AppConfig.newsDetailCacheTtl,
          );
        }
        return NewsDetailResult(
          news: response.data!,
          availability: ContentAvailability.available,
          isFromCache: response.isFromCache,
        );
      }
    } on NotFoundException {
      // KRİTİK: Sunucu 404 verdiğinde stale cache'i yok et
      await _cacheService.purgeNewsItem(slugOrId);
      return const NewsDetailResult(
        news: null,
        availability: ContentAvailability.unavailable,
      );
    } catch (_) {
      if (cachedPayload is Map<String, dynamic>) {
        return NewsDetailResult(
          news: NewsDetailModel.fromJson(cachedPayload),
          availability: ContentAvailability.cachedOffline,
          isFromCache: true,
        );
      }
      rethrow;
    }

    return const NewsDetailResult(
      news: null,
      availability: ContentAvailability.unavailable,
    );
  }

  /// Kategori Haberleri
  Future<PaginatedNewsResult> getArchive({
    int page = 1,
    int limit = 16,
    String? feed,
  }) => _cachedPage(
    'cache_news_archive_${feed ?? 'latest'}_p${page}_l$limit',
    page: page,
    limit: limit,
    request: (etag, payload) => feed == 'most_read'
        ? _apiService.getTrending(
            page: page,
            limit: limit,
            etag: etag,
            cachedPayload: payload,
          )
        : _apiService.getArchiveNews(
            page: page,
            limit: limit,
            feed: feed,
            etag: etag,
            cachedPayload: payload,
          ),
  );

  /// Kategori Haberleri
  Future<PaginatedNewsResult> getCategoryNews(
    String slug, {
    int page = 1,
    int limit = 15,
  }) => _cachedPage(
    'cache_news_category_${Uri.encodeComponent(slug)}_p${page}_l$limit',
    page: page,
    limit: limit,
    request: (etag, payload) => _apiService.getCategoryNews(
      slug,
      page: page,
      limit: limit,
      etag: etag,
      cachedPayload: payload,
    ),
  );

  /// Existing backend's paginated Son Dakika route, not the capped /breaking slot.
  Future<PaginatedNewsResult> getBreakingPage({int page = 1, int limit = 15}) =>
      getCategoryNews('son-dakika', page: page, limit: limit);

  /// Arama
  Future<PaginatedNewsResult> search(
    String query, {
    int page = 1,
    int limit = 15,
  }) {
    final clean = query.trim();
    if (clean.runes.length < 2) {
      return Future.value(
        const PaginatedNewsResult(news: [], meta: ApiMeta(hasMore: false)),
      );
    }
    return _cachedPage(
      'cache_news_search_${Uri.encodeComponent(clean)}_p${page}_l$limit',
      page: page,
      limit: limit,
      request: (etag, payload) => _apiService.search(
        clean,
        page: page,
        limit: limit,
        etag: etag,
        cachedPayload: payload,
      ),
    );
  }

  /// Reuses LocalCacheService and the existing list payload format. Metadata is
  /// saved alongside the page so offline/304 retains has_more, page and total.
  Future<PaginatedNewsResult> _cachedPage(
    String key, {
    required int page,
    required int limit,
    required Future<ApiResponse<List<NewsModel>>> Function(String?, dynamic)
    request,
  }) async {
    final cached = await _cacheService.get(key);
    final metaEntry = await _cacheService.get('${key}_meta');
    final savedMeta = metaEntry?.payload is Map<String, dynamic>
        ? ApiMeta.fromJson(metaEntry!.payload as Map<String, dynamic>)
        : null;
    try {
      final response = await request(cached?.etag, cached?.payload);
      if (!response.isSuccess) throw StateError('Haber akışı alınamadı.');
      final items = response.data ?? const <NewsModel>[];
      final unique = <String, NewsModel>{};
      for (final item in items) {
        unique[item.id.isNotEmpty ? item.id : item.slug] = item;
      }
      final meta =
          response.meta ??
          (response.isFromCache ? savedMeta : null) ??
          ApiMeta(page: page, limit: limit, hasMore: items.length >= limit);
      if (!response.isFromCache) {
        await _cacheService.set(
          key,
          unique.values.map((e) => e.toJson()).toList(),
          etag: response.etag,
          ttl: AppConfig.newsListCacheTtl,
        );
        await _cacheService.set(
          '${key}_meta',
          meta.toJson(),
          ttl: AppConfig.newsListCacheTtl,
        );
      }
      return PaginatedNewsResult(
        news: unique.values.toList(),
        meta: meta,
        isFromCache: response.isFromCache,
      );
    } on NotFoundException {
      await _cacheService.remove(key);
      await _cacheService.remove('${key}_meta');
      rethrow;
    } catch (_) {
      if (cached?.payload is! List) rethrow;
      final items = (cached!.payload as List)
          .whereType<Map<String, dynamic>>()
          .map(NewsModel.fromJson)
          .toList();
      return PaginatedNewsResult(
        news: items,
        meta:
            savedMeta ??
            ApiMeta(page: page, limit: limit, hasMore: items.length >= limit),
        isFromCache: true,
        isOffline: true,
      );
    }
  }

  /// Lokasyon Haberleri
  Future<PaginatedNewsResult> getLocationNews(
    String slug, {
    String? district,
    int? hours,
    int page = 1,
    int limit = 15,
  }) async {
    final response = await _apiService.getLocationNews(
      slug,
      district: district,
      hours: hours,
      page: page,
      limit: limit,
    );
    return PaginatedNewsResult(
      news: response.data ?? const [],
      meta: response.meta,
      isFromCache: response.isFromCache,
    );
  }

  /// Trendler
  Future<List<NewsModel>> getTrending({int limit = 10}) async {
    final response = await _apiService.getTrending(limit: limit);
    return response.data ?? const [];
  }

  /// Son Dakika
  Future<List<NewsModel>> getBreaking({int limit = 10}) async {
    final response = await _apiService.getBreaking(limit: limit);
    return response.data ?? const [];
  }
}
