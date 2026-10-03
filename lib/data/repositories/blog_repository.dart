import 'dart:convert';

import '../../app/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/network/content_availability.dart';
import '../../core/storage/local_cache_service.dart';
import '../../services/api_service.dart';
import '../models/blog_article_model.dart';
import '../models/blog_category_model.dart';

class PaginatedBlogResult {
  final BlogPageModel data;
  final bool isFromCache;
  final bool isOffline;
  const PaginatedBlogResult({
    required this.data,
    this.isFromCache = false,
    this.isOffline = false,
  });
  List<BlogArticleModel> get articles => data.items;
  BlogCategoryModel? get category => data.category;
  int get page => data.page;
  bool get hasMore => data.hasMore;
}

class BlogDetailResult {
  final BlogArticleModel? article;
  final ContentAvailability availability;
  final bool isFromCache;
  const BlogDetailResult({
    this.article,
    required this.availability,
    this.isFromCache = false,
  });
}

/// Same ApiService, ETag revalidation and LocalCacheService as news repositories.
/// Cache payloads preserve the blog's nested pagination and category metadata.
class BlogRepository {
  final ApiService _apiService;
  final LocalCacheService _cacheService;
  static const categoriesCacheKey = 'cache_blog_categories_v1';
  BlogRepository({ApiService? apiService, LocalCacheService? cacheService})
    : _apiService = apiService ?? ApiService(),
      _cacheService = cacheService ?? LocalCacheService.instance;

  Future<PaginatedBlogResult> getArticles({
    int page = 1,
    int perPage = 20,
    String? category,
    String? locationId,
    String? query,
    bool forceRefresh = false,
  }) {
    final key =
        'cache_blog_list_${jsonEncode([page, perPage, category, locationId, query])}';
    return _getPage(
      key,
      forceRefresh,
      (etag, cached) => _apiService.getBlogArticles(
        page: page,
        perPage: perPage,
        category: category,
        locationId: locationId,
        query: query,
        etag: etag,
        cachedPayload: cached,
      ),
    );
  }

  Future<PaginatedBlogResult> getCategoryArticles(
    String slug, {
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) => _getPage(
    'cache_blog_category_${jsonEncode([slug, page, perPage])}',
    forceRefresh,
    (etag, cached) => _apiService.getBlogCategoryArticles(
      slug,
      page: page,
      perPage: perPage,
      etag: etag,
      cachedPayload: cached,
    ),
  );

  Future<PaginatedBlogResult> _getPage(
    String key,
    bool forceRefresh,
    Future<ApiResponse<BlogPageModel>> Function(String?, dynamic) fetch,
  ) async {
    final entry = await _cacheService.get(key);
    try {
      final response = await fetch(
        forceRefresh ? null : entry?.etag,
        entry?.payload,
      );
      final data = response.data;
      if (!response.isSuccess || data == null) {
        throw const ParseException('Blog listesi alınamadı.');
      }
      if (!response.isFromCache) {
        await _cacheService.set(
          key,
          data.toJson(),
          etag: response.etag,
          ttl: AppConfig.newsListCacheTtl,
        );
      }
      return PaginatedBlogResult(data: data, isFromCache: response.isFromCache);
    } on NotFoundException {
      await _cacheService.remove(key);
      rethrow;
    } catch (_) {
      if (entry?.payload is Map<String, dynamic>) {
        return PaginatedBlogResult(
          data: BlogPageModel.fromJson(entry!.payload),
          isFromCache: true,
          isOffline: true,
        );
      }
      rethrow;
    }
  }

  Future<List<BlogCategoryModel>?> getCachedCategories() async {
    final entry = await _cacheService.get(categoriesCacheKey);
    return entry == null
        ? null
        : BlogCategoryTreeModel.fromJson(entry.payload).roots;
  }

  Future<List<BlogCategoryModel>> getCategories({
    bool forceRefresh = false,
  }) async {
    final entry = await _cacheService.get(categoriesCacheKey);
    try {
      final response = await _apiService.getBlogCategories(
        etag: forceRefresh ? null : entry?.etag,
        cachedPayload: entry?.payload,
      );
      final tree = response.data;
      if (!response.isSuccess || tree == null) {
        throw const ParseException('Blog kategorileri alınamadı.');
      }
      // Authoritative replacement, including an empty tree: deleted/inactive
      // categories must not survive in a previously cached snapshot.
      if (!response.isFromCache) {
        await _cacheService.set(
          categoriesCacheKey,
          tree.toJson(),
          etag: response.etag,
          ttl: AppConfig.categoriesCacheTtl,
        );
      }
      return tree.roots;
    } on NotFoundException {
      await _cacheService.remove(categoriesCacheKey);
      rethrow;
    } catch (_) {
      if (entry != null) {
        return BlogCategoryTreeModel.fromJson(entry.payload).roots;
      }
      rethrow;
    }
  }

  Future<BlogArticleModel> getArticleDetail(
    String slugOrId, {
    bool forceRefresh = false,
  }) async {
    final result = await getArticleDetailWithAvailability(
      slugOrId,
      forceRefresh: forceRefresh,
    );
    if (result.article != null) return result.article!;
    throw const NotFoundException(
      message: 'Blog içeriği bulunamadı veya yayından kaldırıldı.',
    );
  }

  Future<BlogDetailResult> getArticleDetailWithAvailability(
    String slugOrId, {
    bool forceRefresh = false,
  }) async {
    final key = 'cache_blog_detail_$slugOrId';
    final entry = await _cacheService.get(key);
    try {
      final response = await _apiService.getBlogDetail(
        slugOrId,
        etag: forceRefresh ? null : entry?.etag,
        cachedPayload: entry?.payload,
      );
      final article = response.data;
      if (!response.isSuccess || article == null) {
        throw const ParseException('Blog detayı alınamadı.');
      }
      if (!response.isFromCache) {
        await _cacheService.set(
          key,
          article.toJson(),
          etag: response.etag,
          ttl: AppConfig.newsDetailCacheTtl,
        );
      }
      return BlogDetailResult(
        article: article,
        availability: ContentAvailability.available,
        isFromCache: response.isFromCache,
      );
    } on NotFoundException {
      await _cacheService.remove(key);
      if (entry?.payload is Map<String, dynamic>) {
        final old = BlogArticleModel.fromJson(entry!.payload);
        if (old.id.isNotEmpty) {
          await _cacheService.remove('cache_blog_detail_${old.id}');
        }
        if (old.slug.isNotEmpty) {
          await _cacheService.remove('cache_blog_detail_${old.slug}');
        }
      }
      return const BlogDetailResult(
        availability: ContentAvailability.unavailable,
      );
    } catch (_) {
      if (entry?.payload is Map<String, dynamic>) {
        return BlogDetailResult(
          article: BlogArticleModel.fromJson(entry!.payload),
          availability: ContentAvailability.cachedOffline,
          isFromCache: true,
        );
      }
      rethrow;
    }
  }
}
