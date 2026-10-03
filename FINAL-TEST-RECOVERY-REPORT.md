# Final Test Recovery + Signed Android AAB — Rapor

**Tarih:** 2026-10-03 · **Proje:** `C:\GuncelGundem-Mobile-App`
**Flutter:** 3.47.4 stable · **Sonuç: TEST RECOVERY PASS**

---

## 1. Başlangıç / Final

| | Başlangıç | Final |
|---|---|---|
| PASS | 260 | **334** |
| FAIL | **73** | **0** |
| Toplam | 333 | 334 |
| `flutter analyze` | 0 sorun | **0 sorun** |

**Test sayısı 333 → 334:** Hiçbir test silinmedi/skip edilmedi. `live_api_smoke_test.dart`
içindeki tek test, iki gerçek senaryoya ayrıldı (başarılı sözleşme + hata yolu) → net +1.

---

## 2. Sınıflandırma (73 başarısızlık)

| # | Dosya | Adet | Kök neden | Karar |
|---|---|---|---|---|
| 1 | news | 18 | `FakeNews` sahtesi `getArchive()`'i karşılamıyordu; latest/featured/mostRead modları gerçek ağ katmanına düşüp boş ekran render ediyordu | **STALE TEST** (sahte tamamlandı) |
| 2 | news | 18 | `title.maxLines isNull` bekleniyordu; akış artık 2 sütunlu `CompactNewsGridCard` ve başlık 3 satıra kırpılıyor | **STALE TEST** |
| 3 | news | 6 | Kart anahtarı `news-article-{id}` → `news-grid-{id}` | **STALE TEST** |
| 4 | news | 4 | `news-more` butonuna kaydırıp tıklama; UI artık dibe yaklaşınca OTOMATİK sayfalıyor (`_onScroll`, `extentAfter < 240`), buton sürekli aşağı itiliyor | **STALE TEST** (mekanizma) |
| 5 | news | 1 | `news-article-` → `news-grid-` | **STALE TEST** |
| 6 | news | 6 | Golden: eski 1 sütunlu tasarım | **STALE GOLDEN** |
| 7 | blog | 4 | `blog-more`; aynı otomatik sayfalama deseni | **STALE TEST** |
| 8 | blog | 1 | `ÖNE ÇIKAN` rozeti + `maxLines isNull`; feed artık `CompactBlogGridCard` (4 satır kırpma), öne çıkanlar ayrı başlıklı bölümde | **STALE TEST** |
| 9 | blog | 1 | `blog-card-article-0` → `blog-grid-article-0` (feed); detaydaki ilgili içerik `blog-card-*` olarak KALDI | **STALE TEST** |
| 10 | blog | 1 | Home blog CTA etiketi `Tümünü Gör` → `Tümünü Gör →` (haber bölümlerinden ayrışıyor) | **STALE TEST** |
| 11 | blog | 4 | Golden | **STALE GOLDEN** |
| 12 | home | 1 | Bölüm sırası: Video Haberler artık Güncel'den SONRA | **STALE TEST** |
| 13 | home | 1 | Bilgi Köşesi galerisi önizleme: en fazla 4 kart (`home-blog-6` hiç yok) | **STALE TEST** |
| 14 | home | 1 | `pumpHome` harness'ında rota üreticisi yoktu → `/sehrim`, `/videolar` "Could not find a generator" | **STALE TEST** (harness) |
| 15 | home | 1 | **Video kategorisi iki kez çiziliyordu** | **GERÇEK UYGULAMA HATASI** |
| 16 | home | 3 | Golden | **STALE GOLDEN** |
| 17 | ui_fidelity | 1 | Aynı harness/rota sorunu | **STALE TEST** |
| 18 | live_api | 1 | Canlı ağa bağımlı + `try/catch` ile hata yutma (30 sn timeout) | **TEST ORTAMI** |

---

## 3. Düzeltilen GERÇEK uygulama hatası (1)

**`lib/features/home/presentation/home_screen.dart` — yinelenen Video bölümü**

`for (final section in home.categorySections)` TÜM kategori bölümlerini çiziyor, hemen
ardından `_videos(home)` aynı içeriği "Video Haberler" başlığıyla TEKRAR çiziyordu.
Backend video kategorisi döndürdüğünde kullanıcı aynı bölümü iki kez görüyordu.

```dart
for (final section in home.categorySections.where(
  (section) => !_isVideo(section),
))
```

Doğrulama: `videoText=3 / desc=2` → düzeltme sonrası tek bölüm.

---

## 4. Güncellenen stale testler (72 başarısızlık)

Yaklaşım: **uygulama geri döndürülmedi.** Mevcut final UI sözleşmesi doğru kabul edildi.
Yasaklı kısayollar KULLANILMADI: `skip` yok, silme yok, `expect(true,true)` yok,
boş assertion yok, geniş `try/catch` yok, timeout şişirme yok.

Eklenen gerçek yardımcılar (assertion'ları güçlendirir, gevşetmez):
- `triggerNextPage` / `triggerNextBlogPage`: kaydırmanın **gerçekten** yeni sayfa isteği
  ürettiğini `expect(..., greaterThan(before))` ile doğrular.
- `scrollToFeedEnd` / `scrollToBlogEnd`: bitiş işaretçisine ulaşır.
- `dragFeed` / `dragBlogFeed`: bekleyen istek sırasında süresiz dönen göstergeye
  takılmamak için `pumpAndSettle` yerine sınırlı `pump`.
- `RouteObserverSpy` + deterministik yer tutucu rota: alt gezinmenin **kanonik rota
  adını** (`/sehrim`, `/videolar`) ittiği doğrulanır.

`live_api_smoke_test.dart` yeniden yazıldı: üretimden **kaydedilmiş gerçek `/config`
yanıtı** ile ağsız/deterministik sözleşme testi + 500 yolunun `ServerException`
fırlattığını doğrulayan ikinci test. Hata yutma kaldırıldı.

---

## 5. Goldens (14 dosya)

Hiçbiri körlemesine kabul edilmedi; her biri `*_testImage.png` görsel olarak incelendi
(taşma / hizalama / eksik widget / tipografi kontrolü), sonra yenilendi.

| Paket | Dosyalar |
|---|---|
| news (6) | breaking, categories, search, latest*, featured*, mostRead* |
| blog (4) | index, category, detail, explorer |
| home (4) | home-360, home-390, home-430, info-corner-390 |

`*` latest/featured/mostRead golden'ları ilk kez üretildi (bu modlar daha önce sahte
eksikliği yüzünden hiç render edilemiyordu).

Doğrulanan final tasarım: logo + arama + bildirim (profil ikonu yok), 2 sütunlu
kompakt grid, alt gezinme Ana Sayfa / Son Dakika / Haber Gönder (merkez FAB) / Şehrim / Video.

---

## 6. Release Smoke Test (gerçek cihazda)

Pixel 9 emülatöründe **release APK** kurulup çalıştırıldı (debug değil):

| Ekran | Sonuç |
|---|---|
| Startup / Onboarding (4 adım) | ✅ |
| Şehir seçimi (81 il, canlı API) | ✅ |
| Kategori seçimi (40 kategori) | ✅ |
| Bildirim kurulumu | ✅ |
| Ana Sayfa (hero, ticker, kategori şeridi, canlı görseller) | ✅ |
| Şehrim (Antalya 21,7°C, namaz vakitleri, yerel haber) | ✅ |
| Haber Gönder (form + opsiyonel foto/iletişim) | ✅ |
| Bildirim Ayarları + **4 yasal bağlantı** | ✅ |
| Kategori bölümleri (2 sütun, 3 satır kırpma) | ✅ |

**Sonuç:** crash = 0 · `E/flutter` = 0 · RenderFlex overflow = 0 · ANR = 0

---

## 7. Final AAB / APK

| | Değer |
|---|---|
| **AAB** | `build\app\outputs\bundle\release\app-release.aab` (60.828.081 bayt) |
| **APK** | `build\app\outputs\flutter-apk\app-release.apk` (63.045.290 bayt — yalnız test) |
| package | `tr.guncelgundem.app` |
| versionName / versionCode | `1.0.0` / `1` |
| targetSdk / compileSdk | **36 / 36** |
| İmza sahibi | `CN=GuncelGundem, OU=Mobile, O=GuncelGundem, L=Istanbul, ST=Istanbul, C=TR` |
| İmza SHA-256 | `47:9C:43:C3:E0:EB:3F:71:5B:2C:2A:89:1C:B3:39:CC:42:DA:B0:E5:3C:30:C4:3C:52:87:69:11:01:E1:FC:67` |
| Algoritma | SHA384withRSA (RSA 4096) |
| **DEBUG imza mı?** | **HAYIR** |

Keystore repo dışında: `C:\GuncelGundem-Release-Secrets\android\` (parola hiçbir
log/rapora yazılmadı). `release-key.properties` içindeki `storeFile` yolu Java
Properties kaçışı nedeniyle düz eğik çizgiye çevrildi.

Release binary doğrulaması (`lib/arm64-v8a/libapp.so`):
4 kanonik legal URL ve `guncelgundem.tr/api/mobile/v1` **var**; `10.0.2.2` **yok**
(kReleaseMode ile elendi). Manifest'te deep link yalnız `/haber/` + `/blog/`.
İzinler: INTERNET, POST_NOTIFICATIONS, ACCESS_NETWORK_STATE (konum/rehber/SMS yok).

---

## 8. Kalan harici blokajlar (kod dışı)

| Konu | Durum |
|---|---|
| **Firebase** | `google-services.json` / `GoogleService-Info.plist` YOK — sahte üretilmedi. Push olmadan uygulama çökmüyor (smoke test doğruladı). **EXTERNAL BLOCKER** |
| **assetlinks.json** | `https://guncelgundem.tr/.well-known/assetlinks.json` → **403**. Gereken SHA-256 Play App Signing sertifikasınındır; AAB ilk yüklemeden sonra alınır. Sahte fingerprint yazılmadı. Play App Links **VERIFIED sayılmıyor**. |
| **iOS** | Windows ortamı: Mac + Xcode 26+ + Team ID + AASA + Firebase iOS config gerekiyor. IPA üretilmedi/iddia edilmedi. Bkz. `IOS-RELEASE-HANDOFF.md` |

---

## 9. Korunan önceki store düzeltmeleri

- Kanonik legal URL'ler (trailing slash dahil) — release binary'de doğrulandı
- Bildirim ayarlarındaki 4 yasal bağlantı — gerçek cihazda görsel olarak doğrulandı
- Deep link `/haber/*` + `/blog/*`; `/bilgi-kosesi/*` geri gelmedi
