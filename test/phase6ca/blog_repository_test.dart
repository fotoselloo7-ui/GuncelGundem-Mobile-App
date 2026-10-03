import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_client.dart';
import 'package:guncelgundem/core/network/content_availability.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/blog_category_model.dart';
import 'package:guncelgundem/data/models/blog_block_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/repositories/blog_repository.dart';
import 'package:guncelgundem/data/repositories/home_repository.dart';
import 'package:guncelgundem/data/state/home_data_state.dart';
import 'package:guncelgundem/services/api_service.dart';

import 'contract_fixtures.dart';

/// Exercises the real ApiService -> ApiClient stack without live network calls.
class ContractAdapter implements HttpClientAdapter {
  dynamic payload;
  int status = 200;
  String etag = '"v1"';
  bool offline = false;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': payload}),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'etag': [etag],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late LocalCacheService cache;
  late ContractAdapter adapter;
  late ApiService api;
  late BlogRepository repo;
  late HomeDataState state;
  late HomeRepository homeRepo;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('guncelgundem_6ca_');
    cache = LocalCacheService.instance;
    await cache.init(overrideDir: dir);
    await cache.clear();
    adapter = ContractAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://contract.test/api/mobile/v1',
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = adapter;
    api = ApiService(apiClient: ApiClient(customDio: dio));
    repo = BlogRepository(apiService: api, cacheService: cache);
    state = HomeDataState();
    homeRepo = HomeRepository(
      apiService: api,
      cacheService: cache,
      state: state,
    );
  });
  tearDown(() async {
    state.dispose();
    await cache.clear();
    await dir.delete(recursive: true);
  });
  test(
    'list forwards per_page and canonical location_id, segregates cache keys',
    () async {
      adapter.payload = fixture('blog_list');
      final result = await repo.getArticles(
        page: 2,
        perPage: 7,
        category: 'cat_blog_food',
        locationId: 'loc_prov_antalya',
        query: 'tarif',
      );
      expect(result.articles, isNotEmpty);
      expect(adapter.requests.last.path, '/blog');
      expect(adapter.requests.last.queryParameters, {
        'page': 2,
        'per_page': 7,
        'category': 'cat_blog_food',
        'location_id': 'loc_prov_antalya',
        'q': 'tarif',
      });
      adapter.offline = true;
      expect(
        (await repo.getArticles(
          page: 2,
          perPage: 7,
          category: 'cat_blog_food',
          locationId: 'loc_prov_antalya',
          query: 'tarif',
        )).isFromCache,
        isTrue,
      );
      await expectLater(
        repo.getArticles(locationId: 'loc_prov_istanbul'),
        throwsException,
      );
    },
  );
  test('list 304 restores nested pagination and sends the ETag', () async {
    adapter.payload = fixture('blog_list');
    final first = await repo.getArticles();
    adapter.status = 304;
    final second = await repo.getArticles();
    expect(second.data, first.data);
    expect(second.isFromCache, isTrue);
    expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
  });
  test(
    'offline list reads persistent disk cache with pagination intact',
    () async {
      adapter.payload = fixture('blog_list');
      final first = await repo.getArticles();
      final key = 'cache_blog_list_${jsonEncode([1, 20, null, null, null])}';
      final file = File(
        '${dir.path}/${md5.convert(utf8.encode(key))}.cache.json',
      );
      final snapshot = await file.readAsString();
      await cache.remove(
        key,
      ); // Evict memory, then simulate an earlier disk snapshot.
      await file.writeAsString(snapshot);
      adapter.offline = true;
      final result = await repo.getArticles();
      expect(result.isFromCache, isTrue);
      expect(result.data, first.data);
    },
  );
  test(
    'detail round trip and offline cache preserve blocks and recipe',
    () async {
      adapter.payload = {
        ...fixture('blog_detail'),
        'schema_recipe': recipeFixture,
        'blocks': [
          {
            'type': 'table',
            'headers': ['A'],
            'rows': [
              ['B'],
            ],
          },
          {'type': 'factbox', 'title': 'T', 'text': 'X'},
        ],
      };
      final first = await repo.getArticleDetail('article');
      adapter.offline = true;
      final result = await repo.getArticleDetailWithAvailability('article');
      expect(result.availability, ContentAvailability.cachedOffline);
      expect(result.article, first);
      expect(result.article!.blocks.first, isA<TableBlogBlock>());
      expect(result.article!.schemaRecipe!.totalTime, 'PT40M');
    },
  );
  test('detail 304 and force refresh reuse the existing HTTP policy', () async {
    adapter.payload = fixture('blog_detail');
    final first = await repo.getArticleDetail('slug');
    adapter.status = 304;
    expect(
      (await repo.getArticleDetailWithAvailability('slug')).isFromCache,
      isTrue,
    );
    adapter.status = 200;
    expect(await repo.getArticleDetail('slug', forceRefresh: true), first);
    expect(adapter.requests.last.headers['If-None-Match'], isNull);
  });
  test('404 does not return an offline stale blog detail', () async {
    adapter.payload = fixture('blog_detail');
    await repo.getArticleDetail('article');
    adapter.status = 404;
    final result = await repo.getArticleDetailWithAvailability('article');
    expect(result.availability, ContentAvailability.unavailable);
    expect(result.article, isNull);
    expect(await cache.get('cache_blog_detail_article'), isNull);
  });
  test('tree save/read and 304 retain parent-child relations', () async {
    adapter.payload = fixture('blog_categories');
    final first = await repo.getCategories();
    expect(await repo.getCachedCategories(), first);
    adapter.status = 304;
    expect(await repo.getCategories(), first);
    expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
    expect(first.first.children.first.parentId, first.first.id);
  });
  test('offline category tree reuses the same cache engine', () async {
    adapter.payload = fixture('blog_categories');
    final first = await repo.getCategories();
    adapter.offline = true;
    expect(await repo.getCategories(), first);
  });
  test(
    'tree update replaces renamed, removed, inactive and added categories',
    () async {
      adapter.payload = fixture('blog_categories');
      await repo.getCategories();
      adapter.etag = '"v2"';
      adapter.payload = {
        'categories': [
          {
            'id': 'new',
            'name': 'Yeni Ad',
            'slug': 'new',
            'children': [
              {'id': 'child', 'name': 'Yeni konu'},
            ],
          },
        ],
      };
      final updated = await repo.getCategories();
      expect(updated.single.name, 'Yeni Ad');
      expect(updated.single.children.single.parentId, 'new');
      expect(await repo.getCachedCategories(), updated);
      adapter.payload = {'categories': []};
      expect(await repo.getCategories(forceRefresh: true), isEmpty);
      expect(await repo.getCachedCategories(), isEmpty);
      expect(adapter.requests.last.headers['If-None-Match'], isNull);
      expect(
        BlogCategoryTreeModel.fromJson(
          (await cache.get(BlogRepository.categoriesCacheKey))!.payload,
        ).roots,
        isEmpty,
      );
    },
  );
  test(
    'category articles use the separate blog category endpoint and cache',
    () async {
      adapter.payload = fixture('blog_category');
      final first = await repo.getCategoryArticles(
        'corbalar',
        page: 1,
        perPage: 8,
      );
      expect(adapter.requests.last.path, '/blog/categories/corbalar');
      expect(adapter.requests.last.queryParameters, {'page': 1, 'per_page': 8});
      expect(first.category!.slug, 'corbalar');
      adapter.offline = true;
      expect(
        (await repo.getCategoryArticles('corbalar', page: 1, perPage: 8)).data,
        first.data,
      );
    },
  );
  test(
    'home refresh publishes info_corner, equality detects a blog-only update',
    () async {
      int notifications = 0;
      state.addListener(() => notifications++);
      adapter.payload = fixture('home');
      final first = await homeRepo.getHome();
      expect(state.home, first);
      expect(state.viewModel!.infoCorner, first.infoCorner);
      adapter.payload = {
        ...fixture('home'),
        'info_corner': {
          'title': 'Sunucudan yeni başlık',
          'featured': [],
          'latest': [],
          'categories': [],
        },
      };
      final second = await homeRepo.getHome(forceRefresh: true);
      expect(second.infoCorner!.title, 'Sunucudan yeni başlık');
      expect(state.home, second);
      expect(notifications, 2);
      expect(second.breaking, first.breaking);
    },
  );
  test(
    'home 304, cache read and offline retain featured/latest and news',
    () async {
      adapter.payload = fixture('home');
      final first = await homeRepo.getHome();
      adapter.status = 304;
      expect(await homeRepo.getHome(), first);
      expect(await homeRepo.getCachedHome(), first);
      adapter.offline = true;
      final offline = await homeRepo.getHome();
      expect(offline.infoCorner!.featured, first.infoCorner!.featured);
      expect(offline.infoCorner!.latest, first.infoCorner!.latest);
      expect(offline.breaking, first.breaking);
      expect(state.home, offline);
      expect(
        HomeModel.fromJson((await cache.get(HomeRepository.cacheKey))!.payload),
        first,
      );
    },
  );
}
