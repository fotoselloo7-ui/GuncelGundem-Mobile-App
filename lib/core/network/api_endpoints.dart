/// Faz 2 Mobil API Endpoint Yolları
class ApiEndpoints {
  ApiEndpoints._();

  /// GET /api/mobile/v1/config
  static const String config = '/config';

  /// GET /api/mobile/v1/home
  static const String home = '/home';

  static const String blog = '/blog';
  static String blogDetail(String slugOrId) =>
      '/blog/${Uri.encodeComponent(slugOrId)}';
  static const String blogCategories = '/blog/categories';
  static String blogCategory(String slug) =>
      '/blog/categories/${Uri.encodeComponent(slug)}';

  /// GET /api/mobile/v1/news
  static const String news = '/news';

  /// GET /api/mobile/v1/news/{slug-or-id}
  static String newsDetail(String slugOrId) => '/news/$slugOrId';

  /// GET /api/mobile/v1/categories
  static const String categories = '/categories';

  /// GET /api/mobile/v1/categories/{slug}/news
  static String categoryNews(String slug) => '/categories/$slug/news';

  /// GET /api/mobile/v1/search
  static const String search = '/search';

  /// GET /api/mobile/v1/locations
  static const String locations = '/locations';

  /// GET /api/mobile/v1/locations/{slug}/news
  static String locationNews(String slug) => '/locations/$slug/news';

  /// GET /api/mobile/v1/trending
  static const String trending = '/trending';

  /// GET /api/mobile/v1/breaking
  static const String breaking = '/breaking';

  /// POST /api/mobile/v1/devices
  static const String devices = '/devices';

  /// GET/PUT /api/mobile/v1/devices/{device_id}
  static String device(String deviceId) => '/devices/$deviceId';

  /// GET /api/mobile/v1/ads
  static const String ads = '/ads';

  /// POST /api/mobile/v1/analytics/events
  static const String analyticsEvents = '/analytics/events';

  /// POST /api/mobile/v1/news-tips (Haber Gönder → admin moderasyon kuyruğu)
  static const String newsTips = '/news-tips';
}
