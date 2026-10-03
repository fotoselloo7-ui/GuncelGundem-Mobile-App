import '../../core/storage/favorites_storage.dart';
import '../models/news_model.dart';

/// Favori Haberler Veri Deposu (Cihaz İçi)
class FavoritesRepository {
  final FavoritesStorage _storage;

  FavoritesRepository({FavoritesStorage? storage})
    : _storage = storage ?? FavoritesStorage();

  Future<List<FavoriteItem>> getFavorites() => _storage.getAll();

  Future<bool> isFavorite(String newsId) => _storage.isFavorite(newsId);

  Future<void> toggleFavorite(NewsModel news) async {
    final exists = await _storage.isFavorite(news.id);
    if (exists) {
      await _storage.removeFavorite(news.id);
    } else {
      await _storage.addFavorite(
        FavoriteItem(
          newsId: news.id,
          slug: news.slug,
          savedAt: DateTime.now(),
          snapshot: news.toJson(),
        ),
      );
    }
  }

  Future<void> removeFavorite(String newsId) => _storage.removeFavorite(newsId);

  Future<void> clearAll() => _storage.clear();
}
