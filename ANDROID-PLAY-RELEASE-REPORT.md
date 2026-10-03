# Android / Google Play — Release Raporu

**Tarih:** 2026-10-03 · **Paket:** `tr.guncelgundem.app` · **Sürüm:** `1.0.0+1`
**Sonuç (2026-10-03 güncellemesi): AAB ÜRETİLDİ VE DOĞRULANDI**

> §8'deki test blokajı giderildi: `flutter test` **334/334 PASS**, `analyze` 0 sorun.
>
> | Artifact | Yol | Boyut |
> |---|---|---|
> | **AAB (Play)** | `buildpp\outputsundleeleasepp-release.aab` | 60.828.081 bayt |
> | APK (yalnız test) | `buildpp\outputslutter-apkpp-release.apk` | 63.045.290 bayt |
>
> package `tr.guncelgundem.app` · versionName `1.0.0` · versionCode `1` ·
> targetSdk/compileSdk **36/36** · imza `CN=GuncelGundem` (**debug DEĞİL**) ·
> SHA-256 `47:9C:43:C3:E0:EB:3F:71:5B:2C:2A:89:1C:B3:39:CC:42:DA:B0:E5:3C:30:C4:3C:52:87:69:11:01:E1:FC:67`
>
> Ayrıntı: `FINAL-TEST-RECOVERY-REPORT.md`. Kalan blokajlar kod dışı:
> Firebase (§6) ve assetlinks.json 403 (§3).

---

## 1. Play 2026 Uyumu (API 36)

| Gereksinim | Değer | Durum |
|---|---|---|
| `targetSdk` ≥ 36 | **36** (`flutter.targetSdkVersion`, Flutter 3.47.4) | ✅ |
| `compileSdk` ≥ 36 | **36** (`flutter.compileSdkVersion`) | ✅ |
| `minSdk` | 24 | ✅ |
| Java/Kotlin uyumu | `JavaVersion.VERSION_17` | ✅ |
| AGP / Gradle | Flutter şablonu, değiştirilmedi | ✅ |

Kaynak doğrulaması: `C:\src\flutter\packages\flutter_tools\gradle\src\main\kotlin\FlutterExtension.kt`
→ `compileSdkVersion = 36`, `targetSdkVersion = 36`, `minSdkVersion = 24`.
Gereksiz bağımlılık yükseltmesi **yapılmadı**.

---

## 2. Release İmzalama

| Öğe | Durum |
|---|---|
| Upload keystore | ✅ **Oluşturuldu** |
| Konum | `C:\GuncelGundem-Release-Secrets\android\guncelgundem-upload.jks` (**repo dışında**) |
| Alias | `guncelgundem-upload` |
| Anahtar | **RSA 4096-bit**, SHA384withRSA |
| Geçerlilik | 03.10.2026 → 18.02.2054 |
| Depo türü | PKCS12 |
| Parola dosyası | `C:\GuncelGundem-Release-Secrets\android\release-key.properties` (**repo dışında**) |
| Parola görünürlüğü | **Hiçbir log/rapor/çıktıda yazılmadı** |

### Gradle entegrasyonu (bu görevde güncellendi)
`android/app/build.gradle.kts` imza dosyasını şu sırayla arar:
1. `GG_RELEASE_KEY_PROPERTIES` ortam değişkeni (CI)
2. `C:/GuncelGundem-Release-Secrets/android/release-key.properties` (yerel üretim)
3. `android/key.properties` (eski yol, `.gitignore`'da)

Hiçbiri yoksa **debug anahtarına düşer** → bu durumda üretilen AAB mağazaya yüklenemez.
Build sırasında hangi dosyanın kullanıldığı `logger.lifecycle` ile yazdırılır.

### `.gitignore` doğrulaması ✅
```
.gitignore:43  android/key.properties
.gitignore:44  android/app/*.jks
.gitignore:45  android/app/*.keystore
android/.gitignore:12-14  key.properties, **/*.keystore, **/*.jks
```

---

## 3. Play App Signing / assetlinks.json

| Öğe | Durum |
|---|---|
| Play App Signing | Kullanılacak (AAB upload key ile imzalanır) |
| Upload key SHA-256 | Keystore'da mevcut (Play Console'a yüklenecek) |
| **assetlinks.json** | ⛔ **EXTERNAL BLOCKER** |

`https://guncelgundem.tr/.well-known/assetlinks.json` → **HTTP 403** (2026-10-03).

App Links doğrulaması için gereken SHA-256, **Play App Signing sertifikasının** parmak izidir
ve ancak AAB Play Console'a ilk kez yüklendikten sonra Play Console → Setup → App signing
ekranından alınabilir. Upload key parmak izi ile karıştırılmamalıdır.

**Sahte SHA-256 yazılmadı.** Sıra:
1. AAB'yi Play Console'a yükle (internal testing yeterli)
2. Play Console → App signing → **App signing key certificate SHA-256**'yı kopyala
3. Sunucuda `/.well-known/assetlinks.json` dosyasını 200 + `application/json` olarak yayınla:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "tr.guncelgundem.app",
    "sha256_cert_fingerprints": ["<PLAY_APP_SIGNING_SHA256>"]
  }
}]
```

---

## 4. Deep Links (bu görevde düzeltildi)

**Bulunan hata:** `AndroidManifest.xml` App Link yolu `/bilgi-kosesi/` idi; bu yol canlıda
**HTTP 404** döndürüyor (web canonical `/blog/` olarak değişmiş).

**Düzeltme:**
```xml
<data android:pathPrefix="/haber/"/>
<data android:pathPrefix="/blog/"/>
```
- Catch-all domain filtresi **kullanılmıyor**.
- Yasal sayfalar (`/kvkk/`, `/gizlilik-politikasi/`, `/kullanim-sartlari/`, `/cerez-politikasi/`)
  App Link kapsamı **dışında** → tarayıcıda açılır. ✅
- `DeepLinkService` hem `/blog/` hem eski `/bilgi-kosesi/` biçimini çözmeye devam eder
  (eski bildirim payload'ları için geriye dönük uyum).
- **Ek düzeltme:** `/blog/{slug}` (makale) ile `/blog/{kategori}/` (kategori) aynı segment
  sayısına sahip. Kategori biçimi artık boş makale ekranı yerine Bilgi Köşesi dizinine açılır.

---

## 5. İzinler (Manifest denetimi) ✅

| İzin | Durum |
|---|---|
| `INTERNET` | ✅ Var (gerekli) |
| `POST_NOTIFICATIONS` | ✅ Var (Android 13+ runtime izni) |
| Rehber / SMS / arama kaydı | ✅ **Yok** |
| Konum (coarse/fine/background) | ✅ **Yok** — "Şehrim" ili kullanıcı elle seçer |
| Geniş depolama (`READ_EXTERNAL_STORAGE` vb.) | ✅ **Yok** — `image_picker` modern Photo Picker kullanır |

---

## 6. Firebase / Push

| Öğe | Durum |
|---|---|
| `android/app/google-services.json` | ⛔ **YOK** |
| Firebase bağımlılığı (`pubspec.yaml`) | Yok |
| FCM varsayılan bildirim ikonu/rengi | ✅ Manifest'te tanımlı (`ic_stat_notification`, `brand_red`) |
| Push olmadan çökme | ✅ **Yok** — `push_token` yalnız mevcutsa gönderilir |

**PUSH STATUS: EXTERNAL BLOCKER** — sahte Firebase yapılandırması üretilmedi.
Push isteniyorsa: Firebase Console → Android app (`tr.guncelgundem.app`) →
`google-services.json` indir → `android/app/` altına koy → FCM paketlerini ekle.

---

## 7. Release Yapılandırması

| Öğe | Durum |
|---|---|
| R8 / minify | ✅ `isMinifyEnabled = true` |
| Kaynak eleme | ✅ `isShrinkResources = true` |
| ProGuard | ✅ `proguard-android-optimize.txt` + `proguard-rules.pro` |
| Production API | ✅ `https://guncelgundem.tr/api/mobile/v1` |
| Debug host sızıntısı | ✅ `10.0.2.2` yalnız `kReleaseMode == false` dalında; release'de erişilemez |
| İkonlar | ✅ 5 yoğunluk + adaptive (`mipmap-anydpi-v26`) + monochrome |
| Splash | ✅ `launch_background.xml` (drawable + drawable-v21) |
| Sürüm | ✅ `1.0.0+1` (ilk yayın, çakışma yok) |

---

## 8. ⛔ AAB NEDEN ÜRETİLMEDİ

Görev tanımındaki **FINAL GATE** kuralı: *"ANDROID AAB ÜRETME / PASS VERME eğer … tests fail ise"*.

```
flutter test  →  260 passed, 73 FAILED
```

Bu 73 hata **bu görevdeki değişikliklerden kaynaklanmıyor**. Kanıt olarak tüm
değişikliklerim geri alınıp paket yeniden çalıştırıldı:

| Durum | Sonuç |
|---|---|
| Değişikliklerim **geri alınmış** (orijinal kod) | 260 geçti / **73 başarısız** |
| Değişikliklerim **uygulanmış** (mevcut kod) | 260 geçti / **73 başarısız** |

→ **Regresyon = 0.** Hatalar önceki geliştirme turlarından devralınmıştır.

### Başarısız test dağılımı
| Dosya | Hata |
|---|---|
| `test/phase6da/news_screens_test.dart` | 53 |
| `test/phase6db/blog_screens_test.dart` | 11 |
| `test/phase6cb/home_screen_test.dart` | 7 |
| `test/ui_fidelity_test.dart` | 1 |
| `test/integration/live_api_smoke_test.dart` | 1 (30 sn ağ zaman aşımı) |

### Hata karakteri (UI sözleşme kayması + golden)
- 28 × `Bad state: No element` — testin aradığı widget artık render edilmiyor
- 18 × `Expected: null / Actual: <3>`
- `Found 0 widgets with key 'blog-more'`, `'news-article-'`, `"ÖNE ÇIKAN"` metni yok
- 3 × golden görsel uyuşmazlığı (`mostRead-390.png`, `latest-390.png`, `featured-390.png`)

Yani test paketi uygulamanın güncel arayüzüyle senkron değil. Bunlar ya testler güncellenerek
ya da eksik arayüz öğeleri geri getirilerek giderilmelidir. **Testleri "geçsin diye" gevşetmek
veya silmek yapılmadı.**

---

## 9. Blokaj kalktığında yapılacak

```bash
cd C:\GuncelGundem-Mobile-App
flutter clean && flutter pub get
flutter analyze            # 0 sorun olmalı (şu an 0)
flutter test               # 0 hata olmalı  ← ŞU AN BLOKAJ
flutter build appbundle --release
flutter build apk --release   # yalnız cihazda smoke test için (Play'e APK yüklenmez)
```

Üretim sonrası **mutlaka doğrulanmalı**:
```bash
# İmza debug DEĞİL, upload key olmalı:
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
# veya bundletool ile manifest kontrolü (package, versionCode, targetSdk)
```

Beklenen: `CN=GuncelGundem, OU=Mobile, O=GuncelGundem, L=Istanbul, ST=Istanbul, C=TR`
(`CN=Android Debug` görülürse **FAIL**).
