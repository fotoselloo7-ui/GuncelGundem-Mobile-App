import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_client.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/repositories/news_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/services/api_service.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/6da/$name.json').readAsStringSync())
        as Map<String, dynamic>;

class FixtureAdapter implements HttpClientAdapter {
  bool offline = false;
  bool notModified = false;
  bool removed = false;
  bool empty = false;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: const SocketException('offline'),
      );
    }
    if (removed) {
      return ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'error': {'code': 'NOT_FOUND', 'message': 'removed'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (notModified) return ResponseBody.fromString('', 304);
    final value = options.path == '/categories'
        ? fixture('categories')
        : options.path == '/search'
        ? fixture('search')
        : fixture(
            options.queryParameters['page'] == 2 ? 'breaking2' : 'breaking1',
          );
    if (empty) {
      value['data'] = [];
      (value['meta'] as Map<String, dynamic>)['has_more'] = false;
      (value['meta'] as Map<String, dynamic>)['total'] = 0;
    }
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'etag': ['"page-etag"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FixtureAdapter adapter;
  late NewsRepository repository;
  late TaxonomyRepository taxonomy;
  setUp(() async {
    await LocalCacheService.instance.clear();
    adapter = FixtureAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://fixture.invalid',
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = adapter;
    final api = ApiService(apiClient: ApiClient(customDio: dio));
    repository = NewsRepository(apiService: api);
    taxonomy = TaxonomyRepository(apiService: api);
  });
  test('breaking uses existing paginated route with distinct page and canonical metadata', () async {
    final first = await repository.getBreakingPage(limit: 2);
    final next = await repository.getBreakingPage(page: 2, limit: 2);
    expect(adapter.requests.map((r) => r.path).toSet(), {
      '/categories/son-dakika/news',
    });
    expect(adapter.requests.last.queryParameters, {'page': 2, 'limit': 2});
    expect(first.meta?.total, fixture('breaking1')['meta']['total']);
    expect(next.page, 2);
    expect(next.hasMore, isTrue);
    expect(next.news.first.id, isNot(first.news.first.id));
    expect(first.news.first.breaking, isTrue);
  });
  test('category cached pages preserve page/total/hasMore on 304, not an offline banner', () async {
    final first = await repository.getCategoryNews('gundem', limit: 2);
    adapter.notModified = true;
    final cached = await repository.getCategoryNews('gundem', limit: 2);
    expect(adapter.requests.last.headers['If-None-Match'], '"page-etag"');
    expect(cached.news, first.news);
    expect(cached.meta, first.meta);
    expect(cached.isFromCache, isTrue);
    expect(cached.isOffline, isFalse);
  });
  test('category and search offline reuse existing cache including pagination metadata', () async {
    final category = await repository.getCategoryNews(
      'gundem',
      page: 2,
      limit: 2,
    );
    final search = await repository.search('haber', limit: 2);
    adapter.offline = true;
    final c = await repository.getCategoryNews('gundem', page: 2, limit: 2);
    final s = await repository.search('haber', limit: 2);
    expect(c.news, category.news);
    expect(c.page, 2);
    expect(c.hasMore, isTrue);
    expect(c.isOffline, isTrue);
    expect(s.isOffline, isTrue);
    expect(s.meta?.total, search.meta?.total);
    expect(s.hasMore, isFalse);
  });
  test('blank and one-character search make no API calls', () async {
    await repository.search('   ');
    await repository.search('a');
    expect(adapter.requests, isEmpty);
  });
  test('search uses existing endpoint and requested page; query/page caches stay isolated', () async {
    await repository.search(' haber ', page: 2, limit: 2);
    expect(adapter.requests.single.path, '/search');
    expect(adapter.requests.single.queryParameters, {
      'q': 'haber',
      'page': 2,
      'limit': 2,
    });
    adapter.offline = true;
    await expectLater(
      repository.search('different', page: 2, limit: 2),
      throwsA(anything),
    );
    await expectLater(
      repository.search('haber', page: 1, limit: 2),
      throwsA(anything),
    );
  });
  test(
    'authoritative empty response replaces stale news and pagination cache',
    () async {
      await repository.getCategoryNews('gundem', limit: 2);
      adapter.empty = true;
      expect(
        (await repository.getCategoryNews('gundem', limit: 2)).news,
        isEmpty,
      );
      adapter.offline = true;
      final cached = await repository.getCategoryNews('gundem', limit: 2);
      expect(cached.news, isEmpty);
      expect(cached.hasMore, isFalse);
      expect(cached.meta?.total, 0);
    },
  );
  test('404 does not resurrect a removed category from cache', () async {
    await repository.getCategoryNews('gundem', limit: 2);
    adapter.removed = true;
    await expectLater(
      repository.getCategoryNews('gundem', limit: 2),
      throwsA(anything),
    );
    adapter.removed = false;
    adapter.offline = true;
    await expectLater(
      repository.getCategoryNews('gundem', limit: 2),
      throwsA(anything),
    );
  });
  test('all 48 API taxonomy nodes, including children, survive offline; empty response replaces tree', () async {
    final roots = await taxonomy.getCategories();
    expect(roots.length, 22);
    expect(roots.fold<int>(0, (n, r) => n + 1 + r.children.length), 48);
    adapter.offline = true;
    expect(await taxonomy.getCategories(), roots);
    adapter.offline = false;
    adapter.empty = true;
    expect(await taxonomy.getCategories(), isEmpty);
    adapter.offline = true;
    expect(await taxonomy.getCategories(), isEmpty);
  });
}
