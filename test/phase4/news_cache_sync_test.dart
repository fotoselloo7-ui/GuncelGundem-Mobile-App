import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/errors/app_exception.dart';
import 'package:guncelgundem/core/network/api_response.dart';
import 'package:guncelgundem/core/network/content_availability.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/news_block_model.dart';
import 'package:guncelgundem/data/models/news_detail_model.dart';
import 'package:guncelgundem/data/models/news_model.dart';
import 'package:guncelgundem/data/repositories/news_repository.dart';
import 'package:guncelgundem/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock ApiService for testing cache sync behaviors
class FakeApiService extends ApiService {
  List<NewsModel>? mockNewsList;
  NewsDetailModel? mockNewsDetail;
  bool shouldThrow404 = false;
  bool shouldThrowNetworkError = false;

  @override
  Future<ApiResponse<List<NewsModel>>> getNews({
    int page = 1,
    int limit = 15,
    String? category,
    String? tag,
    String? author,
    String? etag,
    dynamic cachedPayload,
  }) async {
    if (shouldThrowNetworkError) {
      throw const NetworkException('Bağlantı hatası');
    }
    return ApiResponse<List<NewsModel>>(
      success: true,
      data: mockNewsList ?? [],
      etag: 'etag_list_$page',
      isFromCache: false,
    );
  }

  @override
  Future<ApiResponse<NewsDetailModel>> getNewsDetail(
    String slugOrId, {
    String? etag,
    dynamic cachedPayload,
  }) async {
    if (shouldThrow404) {
      throw const NotFoundException(
        message: 'Haber bulunamadı veya silindi.',
        code: 'NOT_FOUND',
      );
    }
    if (shouldThrowNetworkError) {
      throw const NetworkException('Bağlantı hatası');
    }
    return ApiResponse<NewsDetailModel>(
      success: true,
      data:
          mockNewsDetail ??
          NewsDetailModel(
            card: NewsModel(
              id: slugOrId,
              slug: slugOrId,
              title: 'Haber Detay Başlığı',
              summary: 'Özet',
            ),
            body: const NewsBodyModel(),
          ),
      etag: 'etag_detail_$slugOrId',
      isFromCache: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalCacheService cacheService;
  late FakeApiService fakeApi;
  late NewsRepository newsRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('guncelgundem_sync_test_');
    cacheService = LocalCacheService.instance;
    await cacheService.init(overrideDir: tempDir);
    await cacheService.clear();

    fakeApi = FakeApiService();
    newsRepo = NewsRepository(apiService: fakeApi, cacheService: cacheService);
  });

  tearDown(() async {
    await cacheService.clear();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('News Deletion, 404 Invalidation & Authoritative Replace Tests', () {
    test(
      '404 Not Found purges stale detail cache and returns unavailable',
      () async {
        const newsId = 'news_to_delete_1';
        final detailCacheKey = 'cache_news_detail_$newsId';

        // 1. Seed stale cache
        await cacheService.set(detailCacheKey, {
          'id': newsId,
          'slug': 'silinecek-haber',
          'title': 'Eski Başlık',
        });
        expect(await cacheService.get(detailCacheKey), isNotNull);

        // 2. Server returns 404
        fakeApi.shouldThrow404 = true;

        final result = await newsRepo.getNewsDetailWithAvailability(newsId);

        expect(result.availability, ContentAvailability.unavailable);
        expect(result.news, isNull);
        expect(result.isUnavailable, isTrue);

        // 3. Stale cache must be deleted!
        final cachedAfter = await cacheService.get(detailCacheKey);
        expect(cachedAfter, isNull);
      },
    );

    test(
      '404 purgeNewsItem purges news from list caches and home cache',
      () async {
        const deletedId = 'news_deleted_99';

        // Seed list cache with deleted item and normal item
        const listCacheKey = 'cache_news_p1_l15_c_t_a';
        await cacheService.set(listCacheKey, [
          {'id': deletedId, 'slug': 'deleted-news', 'title': 'Silinen Haber'},
          {
            'id': 'news_active_1',
            'slug': 'active-news',
            'title': 'Aktif Haber',
          },
        ]);

        // Seed home cache
        const homeCacheKey = 'cache_home_v1';
        await cacheService.set(homeCacheKey, {
          'breaking': [
            {'id': deletedId, 'slug': 'deleted-news'},
          ],
          'hero': [
            {'id': 'news_active_1', 'slug': 'active-news'},
          ],
          'featured': [],
          'most_read': [],
          'latest': [],
          'category_sections': [],
        });

        // Purge news item
        await cacheService.purgeNewsItem(deletedId);

        // Verify list cache no longer contains deletedId
        final listEntry = await cacheService.get(listCacheKey);
        expect(listEntry, isNotNull);
        final items = listEntry!.payload as List;
        expect(items.length, 1);
        expect(items.first['id'], 'news_active_1');

        // Verify home cache no longer contains deletedId
        final homeEntry = await cacheService.get(homeCacheKey);
        expect(homeEntry, isNotNull);
        final homeMap = homeEntry!.payload as Map<String, dynamic>;
        final breaking = homeMap['breaking'] as List;
        expect(breaking, isEmpty);
      },
    );

    test(
      'Authoritative replace: Server response replaces stale page 1 cache',
      () async {
        const listCacheKey = 'cache_news_p1_l15_c_t_a';

        // Seed stale cache with old items
        await cacheService.set(listCacheKey, [
          {'id': 'old_item_1', 'title': 'Eski Haber 1'},
          {'id': 'old_item_2', 'title': 'Eski Haber 2'},
        ]);

        // Server returns fresh new list (old items are gone)
        fakeApi.mockNewsList = [
          const NewsModel(
            id: 'fresh_item_1',
            slug: 'fresh-1',
            title: 'Taze Haber 1',
            summary: 'Özet 1',
          ),
          const NewsModel(
            id: 'fresh_item_2',
            slug: 'fresh-2',
            title: 'Taze Haber 2',
            summary: 'Özet 2',
          ),
        ];

        final result = await newsRepo.getNews(page: 1, limit: 15);

        expect(result.news.length, 2);
        expect(result.news[0].id, 'fresh_item_1');
        expect(result.news[1].id, 'fresh_item_2');

        // Cache must now contain only the fresh items
        final cacheAfter = await cacheService.get(listCacheKey);
        final cachedList = cacheAfter!.payload as List;
        expect(cachedList.length, 2);
        expect(cachedList[0]['id'], 'fresh_item_1');
        expect(cachedList[1]['id'], 'fresh_item_2');
      },
    );

    test('Duplicate news IDs from server response are deduplicated', () async {
      fakeApi.mockNewsList = [
        const NewsModel(
          id: 'duplicate_id_1',
          slug: 'dup-1',
          title: 'Haber 1',
          summary: 'Özet 1',
        ),
        const NewsModel(
          id: 'duplicate_id_1',
          slug: 'dup-1-repeat',
          title: 'Haber 1 Tekrar',
          summary: 'Özet 1 Tekrar',
        ),
        const NewsModel(
          id: 'unique_id_2',
          slug: 'unique-2',
          title: 'Haber 2',
          summary: 'Özet 2',
        ),
      ];

      final result = await newsRepo.getNews(page: 1, limit: 15);

      expect(result.news.length, 2);
      expect(result.news[0].id, 'duplicate_id_1');
      expect(result.news[1].id, 'unique_id_2');
    });

    test('Offline fallback returns cached news with ContentAvailability.cachedOffline', () async {
      const newsId = 'news_offline_test';
      const detailCacheKey = 'cache_news_detail_$newsId';

      await cacheService.set(detailCacheKey, {
        'id': newsId,
        'slug': 'offline-haber',
        'title': 'Çevrimdışı Başlık',
      });

      fakeApi.shouldThrowNetworkError = true;

      final result = await newsRepo.getNewsDetailWithAvailability(newsId);

      expect(result.availability, ContentAvailability.cachedOffline);
      expect(result.isOffline, isTrue);
      expect(result.news, isNotNull);
      expect(result.news!.id, newsId);
    });
  });
}
