import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_entry.dart';

/// Güvenli, hafif ve dosya tabanlı lokal önbellek servisi.
///
/// Flutter SDK ve test ortamlarıyla tam uyumludur.
/// Memory + Persistent File Cache katmanı sunar.
class LocalCacheService {
  static LocalCacheService? _instance;
  static LocalCacheService get instance => _instance ??= LocalCacheService._();

  LocalCacheService._();

  final Map<String, CacheEntry> _memoryCache = {};
  final Set<String> _knownKeys = {};
  Directory? _cacheDir;
  bool _isInitialized = false;

  /// Servisi başlatır ve diskteki önbellek dizinini hazırlar
  Future<void> init({Directory? overrideDir}) async {
    if (_isInitialized && overrideDir == null) return;

    try {
      if (overrideDir != null) {
        _cacheDir = overrideDir;
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        _cacheDir = Directory('${appDir.path}/app_cache');
      }

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _isInitialized = true;
    } catch (_) {
      // Test ortamlarında path_provider mock edilmediğinde bellek önbelleğiyle devam eder
      _isInitialized = true;
    }
  }

  /// Güvenli anahtar hash'i (dosya adı için)
  String _hashKey(String key) {
    return md5.convert(utf8.encode(key)).toString();
  }

  File? _getFileForKey(String key) {
    if (_cacheDir == null) return null;
    return File('${_cacheDir!.path}/${_hashKey(key)}.cache.json');
  }

  /// Önbellekten okuma yapar
  Future<CacheEntry?> get(String key) async {
    // 1. Önce memory cache kontrol et
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key]!;
      if (entry.isExpired) {
        await remove(key);
        return null;
      }
      return entry;
    }

    // 2. Diski kontrol et
    final file = _getFileForKey(key);
    if (file != null && await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final entry = CacheEntry.fromJson(json);

        if (entry.isExpired) {
          await file.delete();
          return null;
        }

        // Memory cache'e al
        _memoryCache[key] = entry;
        return entry;
      } catch (_) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    return null;
  }

  /// Önbelleğe kaydeder
  Future<void> set(
    String key,
    dynamic payload, {
    String? etag,
    Duration? ttl,
  }) async {
    final now = DateTime.now();
    final expiresAt = ttl != null ? now.add(ttl) : null;

    final entry = CacheEntry(
      key: key,
      payload: payload,
      etag: etag,
      savedAt: now,
      expiresAt: expiresAt,
    );

    // Memory cache
    _memoryCache[key] = entry;
    _knownKeys.add(key);

    // Disk cache
    final file = _getFileForKey(key);
    if (file != null) {
      try {
        await file.writeAsString(jsonEncode(entry.toJson()));
      } catch (_) {}
    }
  }

  /// Yalnızca ETag değerini günceller (304 Not Modified geldiğinde kullanılır)
  Future<void> updateEtag(String key, String newEtag) async {
    final existing = await get(key);
    if (existing != null) {
      final updated = existing.copyWithUpdatedEtag(newEtag);
      _memoryCache[key] = updated;

      final file = _getFileForKey(key);
      if (file != null) {
        try {
          await file.writeAsString(jsonEncode(updated.toJson()));
        } catch (_) {}
      }
    }
  }

  /// Belirli bir anahtarı siler
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _knownKeys.remove(key);
    final file = _getFileForKey(key);
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// 404 Invalidation: Bir haber silindiğinde veya yayından kaldırıldığında
  /// hem detay önbelleğinden hem de bilinen tüm liste/ana sayfa önbelleklerinden temizler.
  Future<void> purgeNewsItem(String idOrSlug) async {
    // 1. Detay önbelleklerini temizle (hem id hem slug ile olası kayıtlar)
    await remove('cache_news_detail_$idOrSlug');

    // 2. Bilinen tüm liste ve ana sayfa önbelleklerini filtrele
    final keysToInspect = _knownKeys.union(_memoryCache.keys.toSet()).toList();

    for (final key in keysToInspect) {
      if (key == 'cache_home_v1') {
        final homeEntry = await get(key);
        if (homeEntry != null && homeEntry.payload is Map<String, dynamic>) {
          final homeMap = Map<String, dynamic>.from(
            homeEntry.payload as Map<String, dynamic>,
          );
          bool modified = false;

          List<dynamic> filterList(List<dynamic>? list) {
            if (list == null) return [];
            return list.where((item) {
              if (item is Map<String, dynamic>) {
                final id = item['id']?.toString();
                final slug = item['slug']?.toString();
                if (id == idOrSlug || slug == idOrSlug) {
                  modified = true;
                  return false;
                }
              }
              return true;
            }).toList();
          }

          homeMap['breaking'] = filterList(
            homeMap['breaking'] as List<dynamic>?,
          );
          homeMap['hero'] = filterList(homeMap['hero'] as List<dynamic>?);
          homeMap['featured'] = filterList(
            homeMap['featured'] as List<dynamic>?,
          );
          homeMap['most_read'] = filterList(
            homeMap['most_read'] as List<dynamic>?,
          );
          homeMap['latest'] = filterList(homeMap['latest'] as List<dynamic>?);

          if (homeMap['category_sections'] is List) {
            final sections = (homeMap['category_sections'] as List).map((sec) {
              if (sec is Map<String, dynamic>) {
                final secCopy = Map<String, dynamic>.from(sec);
                secCopy['news'] = filterList(secCopy['news'] as List<dynamic>?);
                return secCopy;
              }
              return sec;
            }).toList();
            homeMap['category_sections'] = sections;
          }

          if (modified) {
            await set(
              key,
              homeMap,
              etag: homeEntry.etag,
              ttl: homeEntry.expiresAt?.difference(DateTime.now()),
            );
          }
        }
      } else if (key.startsWith('cache_news_') ||
          key.startsWith('cache_categories_') ||
          key.startsWith('cache_locations_')) {
        final listEntry = await get(key);
        if (listEntry != null && listEntry.payload is List) {
          final list = listEntry.payload as List;
          bool modified = false;
          final filtered = list.where((item) {
            if (item is Map<String, dynamic>) {
              final id = item['id']?.toString();
              final slug = item['slug']?.toString();
              if (id == idOrSlug || slug == idOrSlug) {
                modified = true;
                return false;
              }
            }
            return true;
          }).toList();

          if (modified) {
            await set(
              key,
              filtered,
              etag: listEntry.etag,
              ttl: listEntry.expiresAt?.difference(DateTime.now()),
            );
          }
        }
      }
    }
  }

  /// Tüm önbelleği temizler
  Future<void> clear() async {
    _memoryCache.clear();
    _knownKeys.clear();
    if (_cacheDir != null && await _cacheDir!.exists()) {
      try {
        final files = _cacheDir!.listSync();
        for (final f in files) {
          if (f is File) {
            await f.delete();
          }
        }
      } catch (_) {}
    }
  }
}
