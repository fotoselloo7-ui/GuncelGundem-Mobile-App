# GüncelGündem Mobile — Final Store Release Raporu

**Tarih:** 2026-10-03
**Flutter projesi:** `C:\GuncelGundem-Mobile-App`
**Backend referansı:** `C:\GuncelGundem-Mobile-Dev\guncelgundem.tr`
**Flutter:** 3.47.4 (stable) · **Dart:** 3.13.3 · **Çalıştırma OS'u:** Windows

## SONUÇ (2026-10-03 güncellemesi): ANDROID ARTIFACT HAZIR

> **GÜNCELLEME —** Bu rapordaki §6.1 test blokajı GİDERİLDİ.
> `flutter test` artık **334/334 PASS, 0 FAIL**; `flutter analyze` 0 sorun.
> İmzalı **AAB ve APK üretildi ve doğrulandı** (gerçek upload key, targetSdk 36).
> Release APK Pixel 9 emülatöründe smoke test edildi: crash/overflow/ANR = 0.
> Ayrıntı: **`FINAL-TEST-RECOVERY-REPORT.md`**.
>
> Kalan blokajlar yalnız KOD DIŞI: Firebase config (§6.2), assetlinks.json 403
> (§6.3), AASA 404 (§6.4) ve iOS için Mac/Xcode (§6.5).

---

## 1. Legal URL'ler — PASS (gerçek HTTP doğrulaması)

2026-10-03 tarihinde canlı `curl` ile doğrulandı:

| Metin | Kanonik URL | HTTP | Yönlendirme |
|---|---|---|---|
| KVKK | `https://guncelgundem.tr/kvkk/` | **200** | 0 |
| Gizlilik Politikası | `https://guncelgundem.tr/gizlilik-politikasi/` | **200** | 0 |
| Kullanım Şartları | `https://guncelgundem.tr/kullanim-sartlari/` | **200** | 0 |
| Çerez Politikası | `https://guncelgundem.tr/cerez-politikasi/` | **200** | 0 |

Kontrol amaçlı: eski `https://guncelgundem.tr/gizlilik` → **404** (uygulamada kullanılmıyor).

### Bulunan ve düzeltilen sorunlar

1. **Trailing slash yoktu.** `AppConfig` değerleri `/gizlilik-politikasi`, `/kvkk`,
   `/kullanim-sartlari` biçimindeydi. Kanonik biçime (sonda `/`) çekildi.
2. **Çerez Politikası hiç yoktu.** `cookiePolicyUrl` eklendi.
3. **Bildirim ekranında legal bağlantı yoktu.** (Asıl şikâyet.) Eklendi.
4. Tüm URL'ler tek kaynaktan okunuyor: `AppConfig.legalLinks`. Ekranlarda hard-code yok.
5. Bağlantılar `url_launcher` + `LaunchMode.externalApplication` ile **tarayıcıda** açılıyor;
   Flutter router'a `/gizlilik` gibi bir uygulama route'u olarak düşmüyor.

**Backend değişikliği gerekmedi:** `app/Mobile/**` taramasında mobile config legal URL
döndürmüyor (yalnız `submission.policy_version` metni var). Flutter'daki 4 kanonik
absolute HTTPS URL tek doğruluk kaynağıdır.

---

## 2. Bildirim Ayarları Legal Linkleri — DÜZELTİLDİ

`lib/features/notifications/presentation/notification_preferences_screen.dart`
ekranına "Yasal Bilgilendirme" bölümü eklendi: KVKK, Gizlilik, Kullanım Şartları, Çerez.

- URL'ler `AppConfig.legalLinks` üzerinden gelir (kopyalama yok).
- Satırlar `ListTile` yerine `InkWell` ile çizildi — `ListTile` bu karttaki `DecoratedBox`
  içinde framework assert'i tetikliyordu (test ile yakalandı ve giderildi).
- **Mevcut bildirim davranışı korundu:** `notifications_enabled`, `breaking_news`,
  kategori/şehir tercihleri, sessiz saatler.
  `flutter test test/notifications/` → **12/12 geçti.**

---

## 3. Backend Sözleşmesi Uyumu — PASS

Canlı üretim API'si (`https://guncelgundem.tr/api/mobile/v1`) ile doğrulandı:

| Endpoint | HTTP |
|---|---|
| `/config` | 200 |
| `/home` | 200 |
| `/news` | 200 |
| `/categories` | 200 |
| `/locations` | 200 |
| `/blog` | 200 |
| `/blog/categories` | 200 |

### Son backend değişikliklerine uyum

- **`sources` alanı artık dönmüyor** → canlı yanıt doğrulandı (`has sources: False`).
  Flutter modeli zaten güvenli: `BlogJson.maps(null)` → `const []`.
  Zorunlu / non-null beklemiyor.
- **`cover_url` null dönebiliyor** → canlı yanıtta `cover_url: null` görüldü.
  Model `String? coverUrl` olarak nullable. Kategori fallback'i hero olarak zorunlu beklenmiyor.
- **Blog taksonomisi dinamik** — kodda hard-coded kategori listesi/sayısı taraması yapıldı;
  18 / 230 / 248 gibi sabit sayı kullanımı **yok**.
- Blog detayda internal sızıntı kontrolü: `sources`, `internal_metadata`, `ai_audit`,
  `source_references`, `trend_query` → **hiçbiri yok**.

### Bu görevde bulunan ve düzeltilen MOBİL hata

Backend blok metinlerinde güvenli satır içi HTML saklıyor (`<strong>`, `<em>`, sarmalayıcı `<p>`).
Flutter blog renderer'ı paragraf / alıntı / liste metnini **düz `Text`** ile çiziyordu →
kullanıcıya `<strong>Biliyor musunuz?</strong>` **literal olarak görünürdü**
(web tarafında giderilen hatanın mobil karşılığı).

`blog_block_renderer.dart` güncellendi:

- Metinde etiket varsa güvenli `HtmlWidget` ile çizilir, yoksa eski düz metin yolu korunur.
- `script` / `iframe` / `style` / `object` / `embed` atılır, bağlantılar `onLink` ile yönetilir.
- Başlık ve factbox başlığı düz metne indirgenir (`blogStripTags`).
- Liste maddeleri ve factbox gövdesi de aynı güvenli yoldan geçer.

---

## 4. Deep Links — DÜZELTİLDİ

| Katman | Önce | Sonra |
|---|---|---|
| `AndroidManifest.xml` | `/haber/` + **`/bilgi-kosesi/`** (canlıda **404**) | `/haber/` + **`/blog/`** |
| `Runner.entitlements` | `applinks:guncelgundem.tr` (yorum eski yolu anlatıyordu) | Aynı domain, yorum kanonik yollara güncellendi |
| `DeepLinkService` | `/blog/{slug}` ve `/bilgi-kosesi/{slug}` → makale | Aynı + **kategori biçimi ayrımı** |

- **Catch-all domain deep link yok**; yalnız `/haber/*` ve `/blog/*`.
- **Yasal sayfalar bilerek kapsam dışı** → tarayıcıda açılır, uygulama route'una düşmez.
- Ek düzeltme: web'de `/blog/{slug}` makale, `/blog/{kategori}/` kategori — ikisi de 2 segment.
  Kategori biçimi (sonda `/` veya 3 segment) artık boş makale ekranı yerine
  Bilgi Köşesi dizinine açılıyor.

---

## 5. Android Hazırlık

| Kalem | Durum |
|---|---|
| `targetSdk` / `compileSdk` | **36 / 36** (Play 2026 uyumlu) |
| `minSdk` | 24 |
| Package ID | `tr.guncelgundem.app` (değiştirilmedi) |
| Sürüm | `1.0.0+1` |
| **Upload keystore** | **Üretildi** — RSA **4096**, alias `guncelgundem-upload`, 2054'e kadar geçerli |
| Keystore konumu | `C:\GuncelGundem-Release-Secrets\android\` (**repo dışında**) |
| Parola | **Hiçbir yere yazdırılmadı** — yalnız repo dışı `release-key.properties` |
| `.gitignore` | `key.properties`, `*.jks`, `*.keystore` dışlanmış |
| Gradle imza okuma | Env var → repo dışı yol → eski yol sırası eklendi |
| R8 / shrink / ProGuard | Açık |
| İzinler | Yalnız `INTERNET` + `POST_NOTIFICATIONS` |
| İkon / adaptive / splash | Eksik yok (5 yoğunluk + anydpi-v26 + monochrome) |
| Production API | `kReleaseMode` ile korunuyor; `10.0.2.2` release'de erişilemez |
| `flutter analyze` | **0 sorun** |
| **AAB / APK** | **ÜRETİLMEDİ** (test kapısı — §6.1) |

---

## 6. BLOKAJLAR

### 6.1 Test paketi — 73 başarısız (BU GÖREVDEN KAYNAKLANMIYOR)

```
flutter test -> 260 passed, 73 failed
```

Kanıtlı regresyon ölçümü (tüm değişikliklerim geri alınıp yeniden ölçüldü):

| Kod durumu | Sonuç |
|---|---|
| Orijinal (değişikliklerim geri alınmış) | 260 geçti / **73 başarısız** |
| Mevcut (düzeltmelerim uygulanmış) | 260 geçti / **73 başarısız** |

→ **Bu görevin eklediği regresyon: 0.**

| Dosya | Hata | Karakter |
|---|---|---|
| `test/phase6da/news_screens_test.dart` | 53 | widget bulunamıyor + 3 golden |
| `test/phase6db/blog_screens_test.dart` | 11 | `blog-more` key'i ve "ÖNE ÇIKAN" metni yok |
| `test/phase6cb/home_screen_test.dart` | 7 | bölüm yüksekliği 1330 (beklenen > 4378) |
| `test/ui_fidelity_test.dart` | 1 | — |
| `test/integration/live_api_smoke_test.dart` | 1 | 30 sn ağ zaman aşımı |

Hata karakteri: 28 × `Bad state: No element`, 18 × `Expected: null / Actual: <3>`,
3 × golden görsel uyuşmazlığı. Yani test paketi uygulamanın güncel arayüzüyle senkron değil.

**Testler gevşetilmedi veya silinmedi.** Görev tanımındaki FINAL GATE gereği
("tests fail ise AAB üretme / PASS verme") AAB üretilmedi ve PASS verilmedi.

### 6.2 Firebase / Push — EXTERNAL BLOCKER

`google-services.json` ve `GoogleService-Info.plist` **yok**; sahte üretilmedi.
Push olmadan uygulama **çökmüyor** (`push_token` yalnız mevcutsa gönderiliyor).

### 6.3 assetlinks.json — EXTERNAL BLOCKER

`https://guncelgundem.tr/.well-known/assetlinks.json` → **403**.
Gereken SHA-256 **Play App Signing** sertifikasınındır; AAB ilk yüklemeden sonra
Play Console'dan alınır. **Sahte SHA yazılmadı.**

### 6.4 apple-app-site-association — EXTERNAL BLOCKER

`https://guncelgundem.tr/.well-known/apple-app-site-association` → **404**.
Apple Team ID olmadan **sahte AASA üretilmedi**.

### 6.5 iOS derleme — PLATFORM BLOCKER

Bu makine Windows. Xcode / iOS SDK yok → `flutter build ipa` **çalıştırılmadı**,
IPA üretildiği **iddia edilmiyor**. Yapılacaklar: `IOS-RELEASE-HANDOFF.md`.

---

## 7. Politika / Mağaza Notları

| Konu | Sonuç |
|---|---|
| **Contains Ads** | **HAYIR** — kodda reklam SDK'sı yok (doğrulandı, tahmin değil) |
| **Hesap sistemi** | **Yok** → hesap silme gereksinimi **N/A** (anonim UUID cihaz kaydı) |
| **Haber uygulaması politikası** | Yayıncı kimliği, yazar/kaynak ve iletişim web'de erişilebilir |
| Blog araştırma referansı kaldırma | NEWS kaynak atıfını **bozmadı** (ayrı alan) |
| 3. taraf analitik / crash SDK | Yok — analitik kendi backend'ine gider |

---

## 8. Değişen Dosyalar (bu görev)

| Dosya | Değişiklik |
|---|---|
| `lib/app/app_config.dart` | Kanonik legal URL'ler (trailing slash) + `cookiePolicyUrl` + `legalLinks` |
| `lib/features/notifications/presentation/notification_preferences_screen.dart` | Yasal bilgilendirme bölümü |
| `lib/features/settings/presentation/app_settings_screen.dart` | Çerez Politikası satırı |
| `lib/features/blog/presentation/blog_block_renderer.dart` | Satır içi HTML güvenli render (literal tag hatası) |
| `lib/services/deep_link_service.dart` | Blog kategori / makale biçim ayrımı |
| `lib/app/app.dart` | Kategori biçimli blog linki → Bilgi Köşesi dizini |
| `android/app/src/main/AndroidManifest.xml` | App Link `/bilgi-kosesi/` → `/blog/` |
| `android/app/build.gradle.kts` | Repo dışı keystore arama sırası |
| `ios/Runner/Runner.entitlements` | Kanonik yol / kapsam yorumu |

**Backend (`guncelgundem.tr`) dosyalarında bu görevde değişiklik YAPILMADI** — gerekmedi.

---

## 9. Üretilen Dokümanlar

`ANDROID-PLAY-RELEASE-REPORT.md` · `GOOGLE-PLAY-LISTING-TR.md` · `STORE-DATA-SAFETY-GOOGLE.md`
`IOS-RELEASE-HANDOFF.md` · `APP-STORE-LISTING-TR.md` · `STORE-APP-PRIVACY-APPLE.md`

---

## 10. Yayına Çıkmak İçin Sıra

1. **73 testi gider** (uygulama arayüzü ↔ test sözleşmesi senkronu) → `flutter test` 0 hata
2. `flutter build appbundle --release` → imzayı `jarsigner -verify` ile doğrula (debug olmamalı)
3. AAB'yi Play Console'a yükle (internal testing)
4. Play App Signing **SHA-256**'yı al → sunucuda `assetlinks.json` yayınla (200)
5. Push isteniyorsa Firebase yapılandırmasını ekle
6. macOS'ta `IOS-RELEASE-HANDOFF.md` adımları + Apple Team ID ile AASA yayınla
7. Gerçek cihazdan ekran görüntülerini al, mağaza listelerini doldur
