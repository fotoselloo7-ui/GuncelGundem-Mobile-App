# GüncelGündem Mobil Uygulama — FAZ 3 Raporu
**Flutter Teknik Temel, API İstemcisi, Veri Modelleri ve Çekirdek Altyapı**

*Tarih: 29 Eylül 2026*  
*Durum: Tamamlandı (25/25 Test PASS, 0 Analyzer Hatası, Debug APK Başarılı)*  
*Hedef Platformlar: Android & iOS (Tek Kod Tabanı)*  
*Paket / Uygulama Kimliği: `tr.guncelgundem.app`*  

---

## 1. Geliştirme Ortamı ve Temel Sürümler

Proje kurulumu ve derleme işlemleri aşağıdaki onaylı geliştirme ortamında icra edilmiştir:
- **Flutter Sürümü:** `3.47.4` (Channel stable, revision `9584c6713b`)
- **Dart SDK Sürümü:** `3.13.3` (stable, windows_x64)
- **Android SDK:** Version `36.0.0`
- **Gradle & JVM:** Java 17, Gradle 8.x, Kotlin JVM 17

---

## 2. Kullanılan Bağımlılıklar (Dependencies)

Tüm paketler Flutter 3.47 ve Dart 3.13 ile tam uyumlu seçilmiş ve pubspec konfigürasyonuna eklenmiştir:

| Paket | Sürüm | Kullanım Amacı / Rolü |
|---|---|---|
| `dio` | `^5.11.1` | HTTP istekleri, zaman aşımları, ETag/If-None-Match, kontrollü retry |
| `flutter_bloc` | `^9.1.1` | State management (Cubit odaklı reaktif mimari) |
| `equatable` | `^3.0.0` | Değer tabanlı eşitlik ve state karşılaştırması |
| `path_provider` | `^2.1.6` | Uygulama belgeleri ve kalıcı önbellek dizin yönetimi |
| `shared_preferences` | `^2.5.5` | Onboarding, ayarlar ve lokal favori listesi saklama |
| `connectivity_plus` | `^7.3.1` | Çevrimiçi/çevrimdışı ağ bağlantı durumu takibi |
| `cached_network_image` | `^4.0.2` | Ağ görsellerinin disk ve bellek önbelleklemesi, fallback desteği |
| `flutter_widget_from_html_core` | `^0.17.4` | HTML fallback bloklarının güvenli (JS ve iframe'siz) render edilmesi |
| `crypto` | `^3.0.7` | MD5 cache anahtar hashleme ve doğrulama |

---

## 3. Klasör Mimarisi (Feature-First Core)

Proje, gereksiz katman karmaşasından uzak, bakımı ve genişletilmesi kolay Feature-First yapısında inşa edilmiştir:

```
C:\GuncelGundem-Mobile-App\lib\
├── app/
│   ├── app.dart                   # GuncelGundemApp kök MaterialApp ve teknik kabuk
│   ├── app_config.dart            # Merkezi yapılandırma (apiBaseUrl, timeouts, TTL'ler)
│   └── app_startup.dart           # Soğuk başlangıç akışı ve durum koordinatörü
├── core/
│   ├── errors/
│   │   ├── app_exception.dart     # Typed AppException sınıf hiyerarşisi
│   │   └── failure.dart           # UI dostu Failure nesneleri
│   ├── network/
│   │   ├── api_client.dart        # Dio sarmalayıcı, ETag, 304 revalidation, retry
│   │   ├── api_endpoints.dart     # 11 endpoint sabitleri
│   │   └── api_response.dart      # ApiResponse<T>, ApiError, ApiMeta zarf modelleri
│   ├── storage/
│   │   ├── cache_entry.dart       # key, payload, etag, savedAt, expiresAt
│   │   ├── favorites_storage.dart # Cihaz içi yerel favori kaydı
│   │   └── local_cache_service.dart# Bellek + dosya tabanlı güvenli önbellek servisi
│   └── utils/
│       ├── network_info.dart      # ConnectivityPlus ağ kontrolü
│       └── pagination.dart        # Reusable PaginatedList ve ID deduplication
├── data/
│   ├── models/
│   │   ├── app_config_model.dart  # Branding, bakım modu, sürüm kontrol modeli
│   │   ├── author_model.dart      # Yazar profili modeli
│   │   ├── category_model.dart    # Kategori ağacı ve kompakt snippet modeli
│   │   ├── home_model.dart        # Ana sayfa akışı (hero, breaking, sections) modeli
│   │   ├── location_model.dart    # İl (81 il) ve ilçe hiyerarşik modelleri
│   │   ├── media_model.dart       # Video ve medya modelleri
│   │   ├── news_block_model.dart  # Semantic gövde blokları (Dart 3 sealed class)
│   │   ├── news_detail_model.dart # Zengin haber detay modeli
│   │   ├── news_model.dart        # Kompakt haber liste kartı modeli
│   │   ├── source_model.dart      # Haber kaynağı modeli
│   │   ├── tag_model.dart         # Etiket modeli
│   │   └── topic_model.dart       # Konu modeli
│   └── repositories/
│       ├── config_repository.dart # Konfigürasyon ve stale-while-revalidate deposu
│       ├── favorites_repository.dart# Yerel offline favori deposu
│       ├── home_repository.dart   # Ana sayfa verisi deposu
│       ├── news_repository.dart   # Haber listeleme, detay, arama ve filtreleme deposu
│       └── taxonomy_repository.dart# Kategori ve 81 il lokasyon deposu
├── services/
│   ├── api_service.dart           # 11 Faz 2 endpoint'ini tüketen servis
│   └── version_check_service.dart # SemVer zorunlu/tavsiye güncelleme denetimi
├── design/                        # TEMPORARY / PLACEHOLDER (Tasarım token iskeleti)
│   ├── app_colors.dart            # Placeholder renk tokenları
│   ├── app_radius.dart            # Placeholder köşe yuvarlama tokenları
│   ├── app_spacing.dart           # Placeholder aralık tokenları
│   ├── app_theme.dart             # Placeholder açık/koyu tema
│   └── app_typography.dart        # Placeholder tipografi tokenları
└── features/
    └── news/
        └── presentation/
            └── widgets/
                ├── article_block_renderer.dart # Semantic blokları widget'a çeviren motor
                └── cached_image_widget.dart    # Önbellekli ve fallback korumalı görsel
```

---

## 4. Uygulanan Veri Modelleri ve Alan Bütünlüğü

Tüm Dart modelleri, Faz 2 backend endpoint çıktılarındaki gerçek JSON verilerine göre null-safe olarak kodlanmıştır. Hiçbir eksik veya boş alanda çökme yaşanmaz.

1. **`AppConfigModel`:** Site adı, kısa ad, slogan, mutlak logo ve favicon URL'leri, renk sözlüğü, sosyal medya linkleri, bakım modu (`maintenance_mode`, `maintenance_message`), minimum/tavsiye sürüm bilgisi ve özellik bayrakları.
2. **`NewsModel`:** `id`, `slug`, `title`, `summary`, `coverUrl`, `primaryCategory`, `categories`, `locations`, `publishedAt`, `modifiedAt`, `breaking`, `featured`, `readingTime`, `canonicalUrl`.
3. **`NewsDetailModel`:** Kart alanlarına ek olarak `body` (`NewsBodyModel`), `coverCredit`, `gallery`, `videos`, `authors`, `sources`, `tags`, `topics`, `relatedNews`.
4. **`NewsBlockModel`:** Dart 3 sealed class mimarisiyle:
   - `ParagraphNewsBlock`: Normal metin
   - `HeadingNewsBlock`: H2, H3, H4 hiyerarşik başlıklar
   - `ImageNewsBlock`: Mutlak URL, altyazı ve telif bilgisi
   - `QuoteNewsBlock`: Vurgulu alıntı metni ve konuşmacı
   - `ListNewsBlock`: Sıralı (1. 2.) veya madde imli (•) liste
   - `VideoNewsBlock`: Video önizleme ve embed bilgisi
   - `HtmlNewsBlock`: Sanitize edilmiş güvenli HTML fallback
   - `UnknownNewsBlock`: Bilinmeyen/gelecekte eklenecek yeni blok tipleri için güvenli çökme koruması
5. **`CategoryModel`:** Canonical kategori ID'si (`id`), `name`, `slug`, `parentId`, `displayOrder`, `isMenu`, `isHomepage`, `coverUrl`, `children`.
6. **`LocationProvinceModel` & `LocationDistrictModel`:** 81 il, plaka kodu, ilçe listesi; her ilçede `province_id` canonical bağlantısı.
7. **`HomeModel`:** `breaking`, `hero`, `category_sections`, `featured`, `most_read`, `latest`.

---

## 5. API İstemcisi ve Endpoint Entegrasyonu

`ApiService` sınıfı, backend'in sunduğu tüm 11 read-only endpoint'i eksiksiz destekler:
- `GET /api/mobile/v1/config` -> `ApiService.getConfig()`
- `GET /api/mobile/v1/home` -> `ApiService.getHome()`
- `GET /api/mobile/v1/news` -> `ApiService.getNews(page, limit, category, tag, author)`
- `GET /api/mobile/v1/news/{slug-or-id}` -> `ApiService.getNewsDetail(slugOrId)`
- `GET /api/mobile/v1/categories` -> `ApiService.getCategories()`
- `GET /api/mobile/v1/categories/{slug}/news` -> `ApiService.getCategoryNews(slug, page, limit)`
- `GET /api/mobile/v1/search` -> `ApiService.search(query, page, limit)`
- `GET /api/mobile/v1/locations` -> `ApiService.getLocations()`
- `GET /api/mobile/v1/locations/{slug}/news` -> `ApiService.getLocationNews(slug, district, hours, page, limit)`
- `GET /api/mobile/v1/trending` -> `ApiService.getTrending(limit)`
- `GET /api/mobile/v1/breaking` -> `ApiService.getBreaking(limit)`

---

## 6. Önbellekleme, ETag ve Stale-While-Revalidate Mimarisi

1. **`LocalCacheService`:** Bellek (Memory) ve disk (Persistent JSON File) olmak üzere iki kademeli çalışır. `key`, `payload`, `etag`, `savedAt`, `expiresAt` alanlarını saklar.
2. **HTTP 304 Revalidation:** `ApiClient`, önbellekte mevcut bir ETag varsa isteğe `If-None-Match: <etag>` başlığı ekler. Sunucu `304 Not Modified` döndüğünde diskteki veri doğrudan kullanılır ve ağ veri transferi sıfırlanır.
3. **Offline Fallback:** Cihaz internetsiz kaldığında `ConfigRepository`, `HomeRepository`, `NewsRepository` ve `TaxonomyRepository` önbellekteki veriyi kullanıcıya kesintisiz sunar.
4. **Cihaz İçi Favoriler:** `FavoritesRepository`, harici bir kullanıcı girişi veya sunucu bağlantısı gerekmeksizin haberleri ve haber snapshot'larını cihazda saklar (`isFavorite`, `toggleFavorite`, `getFavorites`).

---

## 7. Semantic Block Renderer ve HTML Güvenliği

`ArticleBlockRenderer`:
- Webview veya kontrolsüz web tarayıcı bileşenlerini haber okuma motoru olarak **kullanmaz**.
- Metin, başlık, görsel, alıntı ve listeleri saf Flutter widget'ları olarak render eder.
- HTML blokları için `flutter_widget_from_html_core` kullanır; Javascript çalıştırmaz, uzaktan harici script çekmez, varsayılan olarak iframe yüklemez.
- Tüm görsel stilleri (renk, font boyutu, padding) doğrudan `Theme.of(context)` üzerinden alır; böylece tasarım aşamasında tek bir tema değişikliği tüm okuma motorunu günceller.

---

## 8. Test ve Doğrulama Sonuçları

### 8.1 Unit ve Widget Testleri (25/25 PASS)
`flutter test` komutu çalıştırılmış ve tüm test senaryoları 1 saniye içinde başarıyla tamamlanmıştır:
- **`test/models/models_parsing_test.dart` (5 Test):** Gerçek Faz 2 JSON yanıtlarının ayrıştırılması, null safety, eksik alan güvenliği.
- **`test/models/semantic_blocks_test.dart` (8 Test):** 8 farklı semantic blok türü, `UnknownNewsBlock` fallback davranışı.
- **`test/core/api_envelope_and_errors_test.dart` (4 Test):** Başarı/hata zarfı, 404, 422, 429, 500, 503 durum kodlarının `Failure` nesnelerine haritalanması.
- **`test/core/storage_and_cache_test.dart` (5 Test):** Bellek ve disk önbellek yazma/okuma, TTL aşımı, 304 ETag güncellemesi, favori ekleme/silme.
- **`test/utils/pagination_and_version_test.dart` (2 Test):** Sayfalama ID tekilleştirmesi (deduplication), SemVer sürüm denetimi ve Force Update mantığı.
- **`test/widget_test.dart` (1 Test):** `ArticleBlockRenderer` bileşen testi.
- **`test/integration/live_api_smoke_test.dart` (1 Test):** Gerçek API endpoint'ine (`/config`) yapılan canlı smoke testi.

### 8.2 Flutter Analyze Sonucu
`flutter analyze` komutu projenin tamamında çalıştırılmıştır:
```
Analyzing GuncelGundem-Mobile-App...
No issues found! (ran in 8.1s)
```
**0 hata, 0 uyarı, 0 bilgi.**

### 8.3 Android Debug APK Derleme Sonucu
`flutter build apk --debug` komutu çalıştırılmış ve hatasız derlenmiştir:
```
Running Gradle task 'assembleDebug'...
√ Built build\app\outputs\flutter-apk\app-debug.apk
```
Üretilen debug APK: `C:\GuncelGundem-Mobile-App\build\app\outputs\flutter-apk\app-debug.apk`

---

## 9. Backend Dokunulmazlık Denetimi

Faz 3 boyunca `C:\GuncelGundem-Mobile-Dev\guncelgundem.tr` dizinindeki backend dosyaları **kesinlikle salt-okunur** tutulmuştur.
- Hiçbir PHP, JSON, YAML veya yapılandırma dosyası değiştirilmemiş veya yeniden formatlanmamıştır.
- Canlı otomatik haber yayın akışı, crawler ve queue mekanizmaları kesintisiz çalışmayı sürdürmüştür.

---

## 10. Bilerek Ertelenen Konular (Kırmızı Çizgiler)

Kullanıcı talimatlarına tam riayet edilerek aşağıdaki başlıklar Faz 3 kapsamı dışında bırakılmıştır:
- **Mobil UI / Ekran Tasarımı:** Ana sayfa tasarımı, haber kartı görünümü, onboarding arayüzü, navigation tasarımı, renk ve font seçimleri kullanıcı tasarım kararları verilene kadar bilerek yapılmamıştır.
- **Firebase / Push Bildirimleri:** Firebase SDK, FCM, cihaz kayıt backend'i ve bildirim tercihleri bu faza dahil edilmemiştir.
- **Canlı İmzalar & Deep Link:** Android release signing / keystore, AAB üretimi, iOS signing, `assetlinks.json` ve `apple-app-site-association` üretimleri ertelenmiştir.

---

## 11. Faz 4 İçin Önerilen Teknik Yol Haritası

1. **Faz 4A (Tasarım Sistemi Entegrasyonu):** Kullanıcıdan alınacak marka renkleri, tipografi kuralları ve görsel bileşen tanımlarının `lib/design/` altındaki token sınıflarına uygulanması.
2. **Faz 4B (Ana Ekranlar ve Navigation):** Bottom navigation bar, Ana Sayfa (Hero slider, Son Dakika ticker, Kategori sekmeleri) ve Haber Kartı widget'larının kodlanması.
3. **Faz 4C (Haber Detay ve Okuma Ekranı):** Geliştirdiğimiz `ArticleBlockRenderer` motorunun zengin detay ekranına bağlanması (galeri, video oynatıcı, yazar kartı, benzer haberler).
4. **Faz 4D (Kategori, Yerel Haberler ve Arama Ekranları):** 81 il haritası/seçicisi, sonsuz kaydırmalı (infinite-scroll) kategori akışı ve anlık arama ekranlarının yapılması.
