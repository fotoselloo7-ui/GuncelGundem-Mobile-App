# iOS Release Handoff — macOS'ta Yapılacaklar

**Durum: IPA ÜRETİLMEDİ.**
Bu görev **Windows** makinesinde çalıştırıldı (`MINGW64_NT-10.0-26200`).
Xcode ve iOS SDK yalnız macOS'ta bulunur; bu makinede **Xcode yok, imzalama kimliği yok**.
Bu nedenle `flutter build ipa` **çalıştırılmadı** ve IPA üretildiği **iddia edilmiyor**.

Aşağıdaki adımlar bir macOS makinesinde sırayla uygulanmalıdır.

---

## 0. Projede HAZIR olanlar (bu görevde doğrulandı)

| Öğe | Değer | Durum |
|---|---|---|
| Bundle ID | `tr.guncelgundem.app` | ✅ (`project.pbxproj`, Release yapılandırması) |
| Deployment target | iOS 15.0 | ✅ (gereken minimum iOS 13+) |
| Sürüm | `1.0.0+1` | ✅ İlk yayın için uygun |
| Associated Domains | `applinks:guncelgundem.tr` | ✅ (`Runner.entitlements`) |
| `NSPhotoLibraryUsageDescription` | Mevcut, açıklayıcı TR metin | ✅ |
| `NSCameraUsageDescription` | Mevcut, açıklayıcı TR metin | ✅ |
| Gereksiz izin | Yok (konum/rehber/takvim izni tanımlı değil) | ✅ |
| AppIcon varlıkları | `Assets.xcassets/AppIcon.appiconset` (16 öğe) | ✅ |
| Firebase (`GoogleService-Info.plist`) | **YOK** | ⛔ Blocker (push için) |

---

## 1. Ön Koşullar (macOS)

```bash
# Apple'ın App Store Connect yükleme şartı (2026): Xcode 26+ / iOS 26 SDK+
xcodebuild -version       # Xcode 26.x bekleniyor
xcrun --sdk iphoneos --show-sdk-version   # 26.x bekleniyor
flutter --version         # 3.47.4 (bu projede doğrulanan sürüm)
```

Xcode 26'dan düşükse App Store Connect yüklemeyi reddeder → **önce Xcode'u yükseltin.**

---

## 2. Projeyi Hazırlama

```bash
cd /path/to/GuncelGundem-Mobile-App
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter analyze            # bu projede 0 sorun olmalı
```

---

## 3. İmzalama (Signing)

Xcode'da `ios/Runner.xcworkspace` açın:

1. **Runner → Signing & Capabilities → Release**
2. Team: GüncelGündem'in Apple Developer Program hesabı
3. `Automatically manage signing` önerilir (ilk yayın için en hızlısı)
4. Bundle Identifier'ın **`tr.guncelgundem.app`** olduğunu doğrulayın (değiştirmeyin)
5. Capabilities:
   - **Associated Domains** → `applinks:guncelgundem.tr` (entitlements'ta zaten var)
   - **Push Notifications** → *yalnız* Firebase/APNs gerçekten devreye alınacaksa ekleyin.
     Gerçek push altyapısı yokken bu capability'yi **eklemeyin** (gereksiz yetki).

---

## 4. Universal Links — Sunucu Tarafı (BLOCKER)

Şu an **`https://guncelgundem.tr/.well-known/apple-app-site-association` → HTTP 404**
(2026-10-03 doğrulaması). Universal Links bu dosya olmadan çalışmaz.

Apple Team ID bilinmediği için **sahte AASA üretilmedi.** Team ID alındıktan sonra
sunucuya şu içerik `Content-Type: application/json` ile, **yönlendirmesiz** yayınlanmalı:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.tr.guncelgundem.app",
        "paths": [ "/haber/*", "/blog/*" ]
      }
    ]
  }
}
```

**Önemli:** `paths` yalnız içerik yollarını içerir. Yasal sayfalar
(`/kvkk/`, `/gizlilik-politikasi/`, `/kullanim-sartlari/`, `/cerez-politikasi/`)
bilerek kapsam dışıdır; Safari'de açılmalıdır.

---

## 5. Push Notifications (BLOCKER — opsiyonel)

`ios/Runner/GoogleService-Info.plist` **yok**. Push gerekiyorsa:
1. Firebase Console → iOS uygulaması ekle (`tr.guncelgundem.app`)
2. `GoogleService-Info.plist` indirip `ios/Runner/` altına ekleyin (Xcode'da hedefe dahil edin)
3. Apple Developer → Keys → **APNs Auth Key (.p8)** üretip Firebase'e yükleyin
4. Push Notifications capability'sini ekleyin

Push yapılandırılmadan uygulama **çöker mi?** Hayır — bildirim tercihleri yerelde saklanır,
`push_token` yalnız mevcutsa gönderilir. Uygulama push olmadan sorunsuz çalışır.

---

## 6. Arşiv ve Yükleme

```bash
flutter build ipa --release
# veya App Store Connect'e doğrudan:
# flutter build ipa --release --export-method app-store
```

Çıktı: `build/ios/ipa/*.ipa`
Yükleme: **Transporter** uygulaması veya Xcode → Organizer → Distribute App.

---

## 7. App Store Connect

- Mağaza metinleri: `APP-STORE-LISTING-TR.md`
- App Privacy yanıtları: `STORE-APP-PRIVACY-APPLE.md`
- Privacy Policy URL: `https://guncelgundem.tr/gizlilik-politikasi/` (doğrulandı: 200)
- Review Notes: `APP-STORE-LISTING-TR.md` içindeki hazır metni kopyalayın
  (hesap sistemi yok → 5.1.1(v) N/A; UGC moderasyonu açıklaması)

---

## 8. iOS Yayın Öncesi Kontrol Listesi

- [ ] Xcode 26+ ve iOS 26 SDK
- [ ] Gerçek Apple Developer Team ile imzalama
- [ ] Bundle ID `tr.guncelgundem.app`
- [ ] AASA dosyası sunucuda yayında (200, JSON, yönlendirmesiz)
- [ ] (Push kullanılacaksa) `GoogleService-Info.plist` + APNs key + capability
- [ ] Gerçek cihazda smoke test: açılış, onboarding, ana sayfa, son dakika, haber detayı,
      kategoriler, arama, Şehrim, Bilgi Köşesi, blog detay, Haber Gönder, bildirim ayarları,
      **yasal bağlantıların Safari'de açılması**, `/haber/*` ve `/blog/*` universal link
- [ ] Ekran görüntüleri gerçek uygulamadan alındı
- [ ] **Flutter test paketindeki 73 başarısız test giderildi** (bkz. `FINAL-MOBILE-STORE-RELEASE-REPORT.md`)
