import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Yerel favori kaydı (kullanıcı hesabı gerektirmez)
class FavoriteItem {
  final String newsId;
  final String slug;
  final DateTime savedAt;
  final Map<String, dynamic>? snapshot;

  const FavoriteItem({
    required this.newsId,
    required this.slug,
    required this.savedAt,
    this.snapshot,
  });

  Map<String, dynamic> toJson() => {
    'news_id': newsId,
    'slug': slug,
    'saved_at': savedAt.toIso8601String(),
    if (snapshot != null) 'snapshot': snapshot,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    newsId: json['news_id'] as String,
    slug: json['slug'] as String,
    savedAt:
        DateTime.tryParse(json['saved_at'] as String? ?? '') ?? DateTime.now(),
    snapshot: json['snapshot'] as Map<String, dynamic>?,
  );
}

/// Cihaz içi favoriler depolama katmanı
class FavoritesStorage {
  static const String _key = 'user_favorites_v1';
  final SharedPreferences? _prefsInstance;

  FavoritesStorage({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  Future<List<FavoriteItem>> getAll() async {
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_key) ?? [];
    final list = <FavoriteItem>[];
    for (final str in raw) {
      try {
        final json = jsonDecode(str) as Map<String, dynamic>;
        list.add(FavoriteItem.fromJson(json));
      } catch (_) {}
    }
    // En son eklenen en üstte
    list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  Future<bool> isFavorite(String newsId) async {
    final list = await getAll();
    return list.any((item) => item.newsId == newsId);
  }

  Future<void> addFavorite(FavoriteItem item) async {
    final list = await getAll();
    // Varsa önce çıkar, tekrar ekle
    list.removeWhere((i) => i.newsId == item.newsId);
    list.insert(0, item);
    await _save(list);
  }

  Future<void> removeFavorite(String newsId) async {
    final list = await getAll();
    list.removeWhere((i) => i.newsId == newsId);
    await _save(list);
  }

  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_key);
  }

  Future<void> _save(List<FavoriteItem> list) async {
    final prefs = await _getPrefs();
    final encoded = list.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }
}
