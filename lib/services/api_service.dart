import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_response.dart';
import '../data/models/ad_model.dart';
import '../data/models/app_config_model.dart';
import '../data/models/category_model.dart';
import '../data/models/device_model.dart';
import '../data/models/home_model.dart';
import '../data/models/location_model.dart';
import '../data/models/news_detail_model.dart';
import '../data/models/news_model.dart';
import '../data/models/news_tip_model.dart';
import '../data/models/blog_article_model.dart';
import '../data/models/blog_category_model.dart';
import '../data/models/blog_json.dart';

/// Mobil API Servisi
///
/// Faz 2'deki 11 read-only endpoint + Faz 4 Cihaz / Tercih API'sini yönetir.
class ApiService {
  final ApiClient client;

  ApiService({ApiClient? apiClient}) : client = apiClient ?? ApiClient();

  Future<ApiResponse<BlogPageModel>> getBlogArticles({
    int page = 1,
    int perPage = 20,
    String? category,
    String? locationId,
    String? query,
    String? etag,
    dynamic cachedPayload,
  }) => client.get<BlogPageModel>(
    ApiEndpoints.blog,
    queryParameters: {
      'page': page,
      'per_page': perPage,
      if (category != null && category.isNotEmpty) 'category': category,
      if (locationId != null && locationId.isNotEmpty)
        'location_id': locationId,
      if (query != null && query.isNotEmpty) 'q': query,
    },
    etag: etag,
    cachedPayload: cachedPayload,
    fromDataJson: BlogPageModel.fromJson,
  );

  Future<ApiResponse<BlogArticleModel>> getBlogDetail(
    String slugOrId, {
    String? etag,
    dynamic cachedPayload,
  }) => client.get<BlogArticleModel>(
    ApiEndpoints.blogDetail(slugOrId),
    etag: etag,
    cachedPayload: cachedPayload,
    fromDataJson: (data) => BlogArticleModel.fromJson(BlogJson.map(data)),
  );

  Future<ApiResponse<BlogCategoryTreeModel>> getBlogCategories({
    String? etag,
    dynamic cachedPayload,
  }) => client.get<BlogCategoryTreeModel>(
    ApiEndpoints.blogCategories,
    etag: etag,
    cachedPayload: cachedPayload,
    fromDataJson: BlogCategoryTreeModel.fromJson,
  );

  // This category endpoint currently supports page/per_page only, not location_id.
  Future<ApiResponse<BlogPageModel>> getBlogCategoryArticles(
    String slug, {
    int page = 1,
    int perPage = 20,
    String? etag,
    dynamic cachedPayload,
  }) => client.get<BlogPageModel>(
    ApiEndpoints.blogCategory(slug),
    queryParameters: {'page': page, 'per_page': perPage},
    etag: etag,
    cachedPayload: cachedPayload,
    fromDataJson: BlogPageModel.fromJson,
  );

  /// 1. GET /api/mobile/v1/config
  Future<ApiResponse<AppConfigModel>> getConfig({
    String? etag,
    dynamic cachedPayload,
  }) {
    return client.get<AppConfigModel>(
      ApiEndpoints.config,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) =>
          AppConfigModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 2. GET /api/mobile/v1/home
  Future<ApiResponse<HomeModel>> getHome({
    String? etag,
    dynamic cachedPayload,
  }) {
    return client.get<HomeModel>(
      ApiEndpoints.home,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => HomeModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 3. GET /api/mobile/v1/news
  Future<ApiResponse<HomeModel>> getHomeForLocation(
    String locationId, {
    String? etag,
    dynamic cachedPayload,
  }) => client.get<HomeModel>(
    ApiEndpoints.home,
    queryParameters: {'location_id': locationId},
    etag: etag,
    cachedPayload: cachedPayload,
    fromDataJson: (json) => HomeModel.fromJson(json as Map<String, dynamic>),
  );

  Future<ApiResponse<List<NewsModel>>> getNews({
    int page = 1,
    int limit = 15,
    String? category,
    String? tag,
    String? author,
    String? etag,
    dynamic cachedPayload,
  }) {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (author != null && author.isNotEmpty) 'author': author,
    };

    return client.get<List<NewsModel>>(
      ApiEndpoints.news,
      queryParameters: params,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  /// 4. GET /api/mobile/v1/news/{slug-or-id}
  Future<ApiResponse<List<NewsModel>>> getArchiveNews({
    int page = 1,
    int limit = 16,
    String? feed,
    String? etag,
    dynamic cachedPayload,
  }) {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (feed != null) {
      params['feed'] = feed;
    }
    return client.get<List<NewsModel>>(
      ApiEndpoints.news,
      queryParameters: params,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  /// 4. GET /api/mobile/v1/news/{slug-or-id}
  Future<ApiResponse<NewsDetailModel>> getNewsDetail(
    String slugOrId, {
    String? etag,
    dynamic cachedPayload,
  }) {
    return client.get<NewsDetailModel>(
      ApiEndpoints.newsDetail(slugOrId),
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) =>
          NewsDetailModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 5. GET /api/mobile/v1/categories
  Future<ApiResponse<List<CategoryModel>>> getCategories({
    String? etag,
    dynamic cachedPayload,
  }) {
    return client.get<List<CategoryModel>>(
      ApiEndpoints.categories,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((c) => CategoryModel.fromJson(c))
              .toList();
        }
        return const [];
      },
    );
  }

  /// 6. GET /api/mobile/v1/categories/{slug}/news
  Future<ApiResponse<List<NewsModel>>> getCategoryNews(
    String slug, {
    int page = 1,
    int limit = 15,
    String? etag,
    dynamic cachedPayload,
  }) {
    final params = <String, dynamic>{'page': page, 'limit': limit};

    return client.get<List<NewsModel>>(
      ApiEndpoints.categoryNews(slug),
      queryParameters: params,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  /// 7. GET /api/mobile/v1/search
  Future<ApiResponse<List<NewsModel>>> search(
    String query, {
    int page = 1,
    int limit = 15,
    String? etag,
    dynamic cachedPayload,
  }) {
    final params = <String, dynamic>{'q': query, 'page': page, 'limit': limit};

    return client.get<List<NewsModel>>(
      ApiEndpoints.search,
      queryParameters: params,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  /// 8. GET /api/mobile/v1/locations
  Future<ApiResponse<List<LocationProvinceModel>>> getLocations({
    String? etag,
    dynamic cachedPayload,
  }) {
    return client.get<List<LocationProvinceModel>>(
      ApiEndpoints.locations,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) {
        // Backend: { country: {...}, provinces: [...] } veya doğrudan [...]
        List<dynamic>? provincesList;
        if (json is Map<String, dynamic> && json['provinces'] is List) {
          provincesList = json['provinces'] as List<dynamic>;
        } else if (json is List) {
          provincesList = json;
        }

        if (provincesList != null) {
          return provincesList
              .whereType<Map<String, dynamic>>()
              .map((p) => LocationProvinceModel.fromJson(p))
              .toList();
        }
        return const [];
      },
    );
  }

  /// 9. GET /api/mobile/v1/locations/{slug}/news
  Future<ApiResponse<List<NewsModel>>> getLocationNews(
    String slug, {
    String? district,
    int? hours,
    int page = 1,
    int limit = 15,
    String? etag,
    dynamic cachedPayload,
  }) {
    final params = <String, dynamic>{
      if (district != null && district.isNotEmpty) 'district': district,
      if (hours != null && hours > 0) 'hours': hours,
      'page': page,
      'limit': limit,
    };

    return client.get<List<NewsModel>>(
      ApiEndpoints.locationNews(slug),
      queryParameters: params,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  /// 10. GET /api/mobile/v1/trending
  Future<ApiResponse<List<NewsModel>>> getTrending({
    int limit = 10,
    int? page,
    String? etag,
    dynamic cachedPayload,
  }) {
    final params = <String, dynamic>{'limit': limit};
    if (page != null) {
      params['page'] = page;
    }
    return client.get<List<NewsModel>>(
      ApiEndpoints.trending,
      queryParameters: params,
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  /// 11. GET /api/mobile/v1/breaking
  Future<ApiResponse<List<NewsModel>>> getBreaking({
    int limit = 10,
    String? etag,
    dynamic cachedPayload,
  }) {
    return client.get<List<NewsModel>>(
      ApiEndpoints.breaking,
      queryParameters: {'limit': limit},
      etag: etag,
      cachedPayload: cachedPayload,
      fromDataJson: (json) => _parseNewsList(json),
    );
  }

  List<NewsModel> _parseNewsList(dynamic json) {
    if (json is List) {
      return json
          .whereType<Map<String, dynamic>>()
          .map((n) => NewsModel.fromJson(n))
          .toList();
    }
    return const [];
  }

  /// 12. POST /api/mobile/v1/devices
  Future<ApiResponse<DeviceModel>> registerDevice(Map<String, dynamic> data) {
    return client.post<DeviceModel>(
      ApiEndpoints.devices,
      data: data,
      fromDataJson: (json) =>
          DeviceModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 13. GET /api/mobile/v1/devices/{device_id}
  Future<ApiResponse<DeviceModel>> getDevice(String deviceId) {
    return client.get<DeviceModel>(
      ApiEndpoints.device(deviceId),
      fromDataJson: (json) =>
          DeviceModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 14. PUT /api/mobile/v1/devices/{device_id}
  Future<ApiResponse<DeviceModel>> updateDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return client.put<DeviceModel>(
      ApiEndpoints.device(deviceId),
      data: data,
      fromDataJson: (json) =>
          DeviceModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// 15. GET /api/mobile/v1/ads
  Future<ApiResponse<List<MobileAdModel>>> getAds({
    required String placement,
    String? categoryId,
    String? locationId,
  }) {
    final params = <String, dynamic>{
      'placement': placement,
      if (categoryId != null && categoryId.isNotEmpty)
        'category_id': categoryId,
      if (locationId != null && locationId.isNotEmpty)
        'location_id': locationId,
    };

    return client.get<List<MobileAdModel>>(
      ApiEndpoints.ads,
      queryParameters: params,
      fromDataJson: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((a) => MobileAdModel.fromJson(a))
              .toList();
        }
        return const <MobileAdModel>[];
      },
    );
  }

  /// 17. POST /api/mobile/v1/news-tips
  ///
  /// Haber ihbarı asla otomatik yayınlanmaz; sunucuda RECEIVED durumunda
  /// editör moderasyon kuyruğuna düşer. Opsiyonel [NewsTipRequest.photoPath]
  /// mevcutsa istek multipart/form-data olarak gönderilir ve mevcut backend
  /// doğrulamalarından (SubmissionSecurityGuard) geçer.
  Future<ApiResponse<NewsTipReceipt>> submitNewsTip(NewsTipRequest tip) async {
    NewsTipReceipt parse(dynamic json) => NewsTipReceipt.fromJson(
      json is Map<String, dynamic> ? json : const <String, dynamic>{},
    );
    final photoPath = tip.photoPath;
    if (photoPath == null || photoPath.isEmpty) {
      return client.post<NewsTipReceipt>(
        ApiEndpoints.newsTips,
        data: tip.toJson(),
        fromDataJson: parse,
      );
    }
    final fields = tip.toJson()
      ..removeWhere((_, v) => v == null)
      ..updateAll((_, v) => v is bool ? (v ? '1' : '0') : v.toString());
    final formData = FormData.fromMap({
      ...fields,
      'photo': await MultipartFile.fromFile(photoPath, filename: 'photo.jpg'),
    });
    return client.post<NewsTipReceipt>(
      ApiEndpoints.newsTips,
      data: formData,
      fromDataJson: parse,
    );
  }

  /// 16. POST /api/mobile/v1/analytics/events
  Future<ApiResponse<Map<String, dynamic>>> recordAnalyticsEvent(
    Map<String, dynamic> data,
  ) {
    return client.post<Map<String, dynamic>>(
      ApiEndpoints.analyticsEvents,
      data: data,
      fromDataJson: (json) =>
          json is Map<String, dynamic> ? json : const <String, dynamic>{},
    );
  }
}
