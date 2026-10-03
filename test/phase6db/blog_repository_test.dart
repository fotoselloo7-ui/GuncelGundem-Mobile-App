import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_client.dart';
import 'package:guncelgundem/core/network/content_availability.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/blog_article_model.dart';
import 'package:guncelgundem/data/models/blog_block_model.dart';
import 'package:guncelgundem/data/repositories/blog_repository.dart';
import 'package:guncelgundem/services/api_service.dart';

import '../phase6ca/blog_repository_test.dart' show ContractAdapter;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/6db/$name.json').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late LocalCacheService cache;
  late ContractAdapter adapter;
  late BlogRepository repo;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('guncelgundem_6db_');
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
    repo = BlogRepository(
      apiService: ApiService(apiClient: ApiClient(customDio: dio)),
      cacheService: cache,
    );
  });
  tearDown(() async {
    await cache.clear();
    await dir.delete(recursive: true);
  });
  test('real blog projection retains root/subcategory, featured, cover captions and recipe', () {
    final article = BlogArticleModel.fromJson(fixture('recipe')['data']);
    expect(article.category!.slug, 'yemek-tarifleri');
    expect(article.subcategory!.slug, 'corbalar');
    expect(article.featured, true);
    expect(article.coverCaption, isNotEmpty);
    expect(article.coverCredit, isNotEmpty);
    expect(article.schemaRecipe!.ingredients.length, 9);
    expect(article.schemaRecipe!.instructions, isEmpty);
    expect(
      article.blocks.whereType<FactboxBlogBlock>().single.text,
      isNotEmpty,
    );
    expect(BlogArticleModel.fromJson(article.toJson()), article);
  });
  test(
    'detail and category caches preserve newly exposed fields when offline',
    () async {
      adapter.payload = fixture('recipe')['data'];
      final live = await repo.getArticleDetailWithAvailability('recipe');
      adapter.offline = true;
      final cached = await repo.getArticleDetailWithAvailability('recipe');
      expect(cached.availability, ContentAvailability.cachedOffline);
      expect(cached.article, live.article);
      adapter.offline = false;
      adapter.payload = fixture('subcategory')['data'];
      final page = await repo.getCategoryArticles('corbalar');
      adapter.offline = true;
      final offline = await repo.getCategoryArticles('corbalar');
      expect(offline.isOffline, true);
      expect(offline.data, page.data);
      expect(offline.category!.description, isNotEmpty);
      expect(offline.articles.single.subcategory!.slug, 'corbalar');
    },
  );
  test(
    '304 revalidation is cached, not offline; page cache keys remain isolated',
    () async {
      adapter.payload = fixture('list')['data'];
      final first = await repo.getArticles(page: 1);
      adapter.status = 304;
      final cached = await repo.getArticles(page: 1);
      expect(cached.isFromCache, true);
      expect(cached.isOffline, false);
      expect(cached.data, first.data);
      adapter.status = 200;
      adapter.payload = fixture('list')['data'];
      await repo.getArticles(page: 2);
      adapter.offline = true;
      final page = await repo.getArticles(page: 2);
      expect(page.isOffline, true);
      expect(adapter.requests.last.queryParameters['page'], 2);
    },
  );
  test('all real roots and children remain accessible from existing offline category cache', () async {
    adapter.payload = fixture('categories')['data'];
    await repo.getCategories();
    adapter.offline = true;
    final roots = await repo.getCategories();
    expect(roots.length, 18);
    expect(roots.expand((r) => r.children).length, 230);
    expect(roots.first.articleCount, 1);
    expect(roots.first.description, isNotEmpty);
  });
  test('authoritative empty response and removed detail cannot resurrect old cache', () async {
    adapter.payload = fixture('list')['data'];
    await repo.getArticles();
    adapter.payload = {
      'items': [],
      'pagination': {'current_page': 1, 'has_more': false},
    };
    expect((await repo.getArticles()).articles, isEmpty);
    adapter.offline = true;
    expect((await repo.getArticles()).articles, isEmpty);
    adapter.offline = false;
    adapter.payload = fixture('recipe')['data'];
    await repo.getArticleDetailWithAvailability('recipe');
    adapter.status = 404;
    expect(
      (await repo.getArticleDetailWithAvailability('recipe')).availability,
      ContentAvailability.unavailable,
    );
    adapter.status = 200;
    adapter.offline = true;
    expect(
      () => repo.getArticleDetailWithAvailability('recipe'),
      throwsA(anything),
    );
  });
  test('blog nullable image metadata and links retain raw extras through cache round trip', () {
    final article = BlogArticleModel.fromJson({
      'body': {
        'blocks': [
          null,
          {
            'type': 'image',
            'url': '',
            'alt': 'Server alt',
            'width': 1600,
            'height': 900,
          },
          {
            'type': 'internal_link',
            'url': '/blog/other',
            'text': 'Server link',
          },
          {
            'type': 'table',
            'headers': ['A', 'B'],
            'rows': [
              [null, 'B'],
            ],
          },
        ],
      },
    });
    final cached = BlogArticleModel.fromJson(article.toJson());
    expect(cached, article);
    expect((cached.blocks.first as StandardBlogBlock).raw['alt'], 'Server alt');
    expect((cached.blocks.last as TableBlogBlock).rows.single, ['', 'B']);
  });
}
