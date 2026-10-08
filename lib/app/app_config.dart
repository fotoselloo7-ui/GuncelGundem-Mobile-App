import 'package:flutter/foundation.dart';

import '../data/models/app_config_model.dart';

/// GüncelGündem Mobil Uygulama — Merkezi Yapılandırma
///
/// API Base URL ve ortam değişkenlerini tek bir yerden yönetir.
/// Kod tabanında URL hard-code edilmesini engeller.
class AppConfig {
  AppConfig._();

  /// Üretim (release) sabit base URL. --dart-define=API_BASE_URL ile
  /// multi-tenant build desteklenir. 10.0.2.2 / localhost gibi dev host'lar
  /// release derlemelerine KESİNLİKLE sızamaz.
  static const String _productionUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://guncelgundem.tr/api/mobile/v1',
  );

  /// Debug (geliştirme) base URL. Android emulator varsayılan olarak host
  /// makineye `10.0.2.2` üzerinden erişir — yerelde `php -S 0.0.0.0:8080 -t public`
  /// çalışan GüncelGündem backend'ini otomatik hedefler. Fiziksel cihazda veya
  /// farklı port kullanıldığında --dart-define=DEBUG_API_BASE_URL=http://... ile
  /// override edilebilir. Release derlemeleri bu değere ASLA bakmaz.
  static const String _debugUrl = String.fromEnvironment(
    'DEBUG_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/mobile/v1',
  );

  /// Derleme moduna göre varsayılan base URL. Release daima production,
  /// debug ise `DEBUG_API_BASE_URL` (varsayılan: emulator loopback).
  static String get defaultBaseUrl {
    if (kReleaseMode) return _productionUrl;
    return _debugUrl.isNotEmpty ? _debugUrl : _productionUrl;
  }

  /// Üretim web sitesi (brand ve privacy link'leri için).
  static const String productionSiteUrl = 'https://guncelgundem.tr';

  /// Deep link ve universal link host'u.
  static const String deepLinkHost = 'guncelgundem.tr';

  static String _apiBaseUrl = defaultBaseUrl;

  static String get apiBaseUrl => _apiBaseUrl;

  static void setBaseUrl(String url) {
    _apiBaseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Varsayılan base URL'ye döner (test ortamları için).
  static void resetBaseUrl() {
    _apiBaseUrl = defaultBaseUrl;
  }

  /// Network Zaman Aşımları
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);

  /// Startup sırasında config isteği için daha kısa, kullanıcı-nazik timeout.
  /// Config başarısız olursa cached / bundled fallback devreye girer.
  static const Duration startupConfigTimeout = Duration(seconds: 6);

  /// Sayfalama Sınırları
  static const int defaultPageLimit = 15;
  static const int maxPageLimit = 30;

  /// Önbellek Varsayılan Süreleri
  static const Duration configCacheTtl = Duration(minutes: 5);
  static const Duration categoriesCacheTtl = Duration(minutes: 30);
  static const Duration locationsCacheTtl = Duration(hours: 1);
  static const Duration homeCacheTtl = Duration(seconds: 60);
  static const Duration newsListCacheTtl = Duration(seconds: 60);
  static const Duration newsDetailCacheTtl = Duration(minutes: 5);

  /// Uygulama Sürüm Bilgisi
  static const String appVersion = '1.0.0';
  static const int buildNumber = 4;

  /// Üretim legal/privacy linkleri — TEK DOĞRULUK KAYNAĞI.
  ///
  /// Web tarafındaki kanonik sabit sayfa slug'larıyla birebir eşleşir ve
  /// SONDAKİ EĞİK ÇİZGİ (trailing slash) dahil kanonik biçimde tutulur; böylece
  /// gereksiz yönlendirme olmadan doğrudan 200 döner. Ekranlarda bu sabitler
  /// dışında legal URL hard-code EDİLMEZ.
  static const String privacyUrl = '$productionSiteUrl/gizlilik-politikasi/';
  static const String kvkkUrl = '$productionSiteUrl/kvkk/';
  static const String termsUrl = '$productionSiteUrl/kullanim-sartlari/';
  static const String cookiePolicyUrl = '$productionSiteUrl/cerez-politikasi/';

  /// Google Play Haberler ve Dergiler politikası için görünür, kalıcı
  /// yayıncı/geliştirici iletişim bilgileri. Bu değerler hem Android hem iOS
  /// uygulamasında aynı native iletişim ekranında kullanılır.
  static const String publisherName = 'Netvera Teknoloji Yazılım';
  static const String contactEmail = 'iletisim@guncelgundem.tr';
  static const String contactUrl = '$productionSiteUrl/iletisim';
  static const String contactWebsiteUrl = productionSiteUrl;

  /// Ayar/bildirim ekranlarının ortak legal bağlantı listesi (başlık + URL).
  /// Tek kaynaktan okunur; yeni bir ekran eklendiğinde kopyalama gerekmez.
  static const List<({String title, String url})> legalLinks = [
    (title: 'Gizlilik Politikası', url: privacyUrl),
    (title: 'KVKK Aydınlatma Metni', url: kvkkUrl),
    (title: 'Kullanım Şartları', url: termsUrl),
    (title: 'Çerez Politikası', url: cookiePolicyUrl),
  ];

  /// Uygulama çevrimdışı/ilk kurulumda bile açılabilsin diye bundled güvenli
  /// varsayılan konfigürasyon. Mevcut server-driven branding mimarisini
  /// kaldırmaz; yalnız remote config erişilemediğinde fallback olarak kullanılır.
  /// Remote config döndüğünde ezilir.
  static AppConfigModel bundledDefaultConfig() => const AppConfigModel(
    apiVersion: 'v1',
    siteName: 'GüncelGündem',
    shortName: 'GüncelGündem',
    tagline: "Türkiye'nin Güncel Gündem Adresi",
    siteUrl: productionSiteUrl,
    maintenanceMode: false,
    forceUpdate: false,
  );
}
