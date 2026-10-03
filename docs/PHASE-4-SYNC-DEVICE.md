# GÜNCELGÜNDEM MOBİL UYGULAMA — FAZ 4 RAPORU
## CANLI SENKRONİZASYON, DİNAMİK MARKA & CİHAZ / BİLDİRİM TERCİH ALTYAPISI

**Tarih:** 2026-09-29  
**Platform:** Flutter 3.47.4 / Dart 3.13.3  
**Aşama:** Faz 4 — Canlı Senkronizasyon + Dinamik Marka + Cihaz/Bildirim Tercih Altyapısı  
**Durum:** Tamamlandı (Başarılı)

---

### 1. Mimari Prensipler ve Çoklu Müşteri (Multi-Tenant) Desteği

Uygulama, **NetVera Haber Sitesi Script Yazılımı** ürününün mobil ayağı olarak tasarlanmıştır.

- **Merkezi URL Yapılandırması:** Domain kod içine hard-code edilmemiştir.
  - `--dart-define=API_BASE_URL=https://guncelgundem.tr/api/mobile/v1` ile derleme anında belirlenebilir.
  - Kod tabanı tek bir komutla farklı NetVera müşterileri için yeniden derlenebilir.
- **Web / Admin Paneli Tek Gerçek Kaynaktır:**
  - Mobil uygulama ikinci bir içerik yönetim sistemi değildir.
  - İçeriksel tüm değişiklikler (haber silme/arşivleme, kategori sırası, logo değişimi vb.) mobil uygulama tarafından otomatik revalidate edilir. Yeni bir APK/AAB release GEREKMEZ.

---

### 2. Runtime Server-Driven Branding

`BrandingState` sınıfı dinamik marka kimliğini çalışma anında yönetir:
- `GET /api/mobile/v1/config` üzerinden beslenir.
- `siteName`, `shortName`, `tagline`, `logoUrl`, `logoMobileUrl`, `faviconUrl`, `primaryColor`, `secondaryColor`, `accentColor` değerlerini günceller.
- Hex renk kodlarını (`#10B981` veya `10B981`) `Color` nesnesine ayrıştırır.
- `notifyListeners()` aracılığıyla dinleyicileri uyarır. `GuncelGundemApp` kök bileşeni `AnimatedBuilder` ile dinamik başlık ve temayı anında yansıtır.

---

### 3. Server-Driven vs App Store / Google Play Release Ayrımı

- **Server-Driven (Release GEREKTİRMEZ):**
  - Uygulama içi logolar
  - Site adı ve sloganı
  - Dinamik marka renkleri
  - Kategoriler ve kategori sıralaması
  - Şehir ve ilçe listesi
  - Yayınlanan haberler
  - Feature flag'ler
  - Bakım modu ve bakım mesajı
  - Minimum ve önerilen uygulama sürümü

- **App Release GEREKTİRENLER:**
  - Cihaz ana ekranındaki Launcher Icon
  - Mağaza ekran görüntüleri ve açıklamaları
  - Android `applicationId` / iOS `bundleIdentifier`
  - Native izinler (push notification capability, camera vb.)
  - Yeni native plugin/kütüphane eklenmesi
  - Sıfırdan yeni ekran/layout mimarisi

---

### 4. Haber Silme & 404 Cache Invalidation

1. **404 Not Found Revalidation:**
   - Önbellekte bulunan bir haber açıldığında sunucu `404` veya `NOT_FOUND` dönerse, `LocalCacheService.purgeNewsItem(idOrSlug)` çalıştırılır.
   - Stale detay cache'i silinir.
   - Liste önbelleklerinden (`cache_news_p*`) ve ana sayfa önbelleğinden (`cache_home_v1`) ilgili haber ID'si temizlenir.
   - `ContentAvailability.unavailable` döndürülerek güvenli hata durumu yönetilir.
2. **Authoritative List Cache:**
   - `GET /news?page=1` yanıtı yerel page-1 cache'ini tamamen replace eder.
   - Duplicate haber ID'leri temizlenir.
3. **Home Authoritative Replace:**
   - `GET /home` güncel yanıtı eski home snapshot'ını tamamen replace eder.

---

### 5. Kategori ve Lokasyon Senkronizasyonu

- Kategoriler ve Lokasyonlar için `id` (canonical ID) kullanılır (`cat_gundem`, `loc_prov_antalya`).
- Sunucuda silinen/kaldırılan kategori veya lokasyonlar, `DeviceRepository.sanitizePreferencesAgainstTaxonomy()` metodu ile kullanıcının yerel tercihlerinden sessizce temizlenir; crash oluşumu engellenir.

---

### 6. Cihaz Kimliği ve Bildirim Tercih Altyapısı

- **Anonim Cihaz ID:**
  - `DeviceStorage.generateUuidV4()` ile donanım kimliği, IMEI veya telefon numarası kullanılmadan RFC 4122 uyumlu rastgele UUID v4 üretilir ve `shared_preferences` üzerinde kalıcı saklanır.
- **Yerel Bildirim Modeli:**
  - `NotificationPreferenceModel`: `notifications_enabled`, `breaking_news`, `all_categories`, `category_ids`, `all_locations`, `location_ids`, `quiet_hours`.
- **Offline Tercih Yönetimi (Dirty Flag):**
  - Çevrimdışıyken tercihler güncellendiğinde anında kaydedilir ve `isPendingSync = true` yapılır.
  - Cihaz çevrimiçi olduğunda veya `syncOnResume()` anında `syncPendingPreferences()` çalışarak sunucuya aktarır ve pending bayrağını temizler.

---

### 7. Doğrulama ve Test Sonuçları

- **`flutter analyze`:** `No issues found! (0 hata, 0 uyarı)`
- **`flutter test`:** **42/42 test PASS**
  - `test/core/api_envelope_and_errors_test.dart` (4 test)
  - `test/core/storage_and_cache_test.dart` (4 test)
  - `test/integration/live_api_smoke_test.dart` (1 test)
  - `test/models/models_parsing_test.dart` (9 test)
  - `test/models/semantic_blocks_test.dart` (10 test)
  - `test/phase4/branding_state_test.dart` (4 test)
  - `test/phase4/device_repository_test.dart` (5 test)
  - `test/phase4/news_cache_sync_test.dart` (5 test)
  - `test/phase4/sync_coordinator_test.dart` (2 test)
  - `test/widget_test.dart` (1 test)
- **`flutter build apk --debug`:** Başarıyla tamamlandı (`build\app\outputs\flutter-apk\app-debug.apk`)
