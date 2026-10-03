import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/news_model.dart';
import 'package:guncelgundem/data/repositories/favorites_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalCacheService cacheService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('guncelgundem_cache_test_');
    cacheService = LocalCacheService.instance;
    await cacheService.init(overrideDir: tempDir);
    await cacheService.clear();
  });

  tearDown(() async {
    await cacheService.clear();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Local Storage & Caching Tests', () {
    test('LocalCacheService saves and retrieves payload with ETag', () async {
      const key = 'test_key_1';
      final payload = {'name': 'Test Verisi', 'count': 42};

      await cacheService.set(
        key,
        payload,
        etag: 'etag_abc_123',
        ttl: const Duration(seconds: 300),
      );

      final entry = await cacheService.get(key);
      expect(entry, isNotNull);
      expect(entry!.key, key);
      expect(entry.payload, payload);
      expect(entry.etag, 'etag_abc_123');
      expect(entry.isExpired, isFalse);
    });

    test('LocalCacheService updates ETag on 304 revalidation', () async {
      const key = 'test_key_etag';
      await cacheService.set(key, {'data': 'old_data'}, etag: 'old_etag');

      await cacheService.updateEtag(key, 'new_etag_304');

      final entry = await cacheService.get(key);
      expect(entry?.etag, 'new_etag_304');
      expect(entry?.payload, {'data': 'old_data'});
    });

    test('LocalCacheService honors TTL expiration', () async {
      const key = 'test_key_expired';
      await cacheService.set(key, {
        'expired': true,
      }, ttl: const Duration(milliseconds: 1));

      // Wait for expiration
      await Future.delayed(const Duration(milliseconds: 10));

      final entry = await cacheService.get(key);
      expect(entry, isNull);
    });

    test('LocalCacheService removes and clears keys', () async {
      await cacheService.set('k1', {'val': 1});
      await cacheService.set('k2', {'val': 2});

      await cacheService.remove('k1');
      expect(await cacheService.get('k1'), isNull);
      expect(await cacheService.get('k2'), isNotNull);

      await cacheService.clear();
      expect(await cacheService.get('k2'), isNull);
    });

    test(
      'FavoritesRepository adds, checks, and removes favorites offline',
      () async {
        final favRepo = FavoritesRepository();

        const testNews = NewsModel(
          id: 'news_fav_1',
          slug: 'favori-haber',
          title: 'Favori Haber Başlığı',
          summary: 'Favori haber özeti',
        );

        expect(await favRepo.isFavorite('news_fav_1'), isFalse);

        await favRepo.toggleFavorite(testNews);
        expect(await favRepo.isFavorite('news_fav_1'), isTrue);

        final list = await favRepo.getFavorites();
        expect(list.length, 1);
        expect(list.first.newsId, 'news_fav_1');
        expect(list.first.snapshot?['title'], 'Favori Haber Başlığı');

        await favRepo.toggleFavorite(testNews);
        expect(await favRepo.isFavorite('news_fav_1'), isFalse);
      },
    );
  });
}
