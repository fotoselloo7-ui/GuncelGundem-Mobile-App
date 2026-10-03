# App Store Connect — App Privacy (Koddan Çıkarılmış)

**Uygulama:** GüncelGündem · Bundle ID `tr.guncelgundem.app`
**Kaynak:** Flutter kaynak kodu denetimi (tahmin yok). Tarih: 2026-10-03

---

## 1. "Data Used to Track You" — **YOK**

Uygulama App Tracking Transparency kapsamında izleme yapmaz:
- Reklam SDK'sı yok, IDFA okunmaz, `AppTrackingTransparency` çağrısı yok.
- Üçüncü taraf analitik/attribution SDK'sı yok.
- Veri veri simsarlarıyla paylaşılmaz.

→ App Privacy formunda **"Data is not used to track you"**.

---

## 2. "Data Linked to You"

| Veri Türü | Durum | Amaç | Kod Dayanağı |
|---|---|---|---|
| Contact Info → Name | Opsiyonel toplanır | App Functionality | `NewsTipRequest.contactName` |
| Contact Info → Email Address | Opsiyonel toplanır | App Functionality | `NewsTipRequest.contactEmail` |
| Contact Info → Phone Number | Opsiyonel toplanır | App Functionality | `NewsTipRequest.contactPhone` |
| User Content → Photos or Videos | Opsiyonel toplanır | App Functionality | `api_service.dart` multipart `photo` |
| User Content → Other User Content | Opsiyonel toplanır | App Functionality | `NewsTipRequest.title/description` |

Bu alanlar **yalnızca** kullanıcı "Haber Gönder" formunu doldurup gönderdiğinde iletilir.
Uygulamanın geri kalanı bu verilerin hiçbirini istemez.

---

## 3. "Data Not Linked to You"

| Veri Türü | Durum | Amaç | Kod Dayanağı |
|---|---|---|---|
| Identifiers → Device ID | Toplanır | App Functionality | Rastgele UUID v4 (`device_storage.dart`) |
| Usage Data → Product Interaction | Toplanır (anonim) | App Functionality | `analytics_service.dart` (kendi backend'i) |

**Device ID notu:** `identifierForVendor` veya IDFA **değildir**; uygulamanın kendi ürettiği
rastgele UUID v4'tür ve yalnız cihaz tercihlerini (bildirim ayarları) eşlemek için kullanılır.
Uygulama silindiğinde kaybolur.

---

## 4. TOPLANMAYAN (iOS tarafında doğrulandı)

- Location (precise/coarse) — `NSLocationWhenInUseUsageDescription` **yok**
- Contacts, Calendar, Health, Fitness, Financial Info
- Browsing History, Search History (kişiye bağlı geçmiş tutulmaz)
- Sensitive Info, Diagnostics (3. taraf crash SDK yok)

---

## 5. İzin Metinleri (Info.plist — mevcut ve doğru)

| Anahtar | Metin |
|---|---|
| `NSPhotoLibraryUsageDescription` | "Haber ihbarınıza fotoğraf eklemek istediğinizde galeriden seçim yapabilmek için kullanılır. Fotoğraflar yalnız siz onayladığınızda gönderilir." |
| `NSCameraUsageDescription` | "Haber ihbarınıza doğrudan kamera ile fotoğraf çekip eklemek için kullanılır." |

Gereksiz izin tanımı yoktur.

---

## 6. Hesap Silme (App Store Guideline 5.1.1(v))

Uygulamada **hesap oluşturma/giriş yoktur** (kod taramasıyla doğrulandı).
Bu nedenle uygulama içi hesap silme zorunluluğu **uygulanabilir değildir (N/A)**.
Review Notes alanına bu not eklenmelidir.

Veri silme talebi kanalı: https://guncelgundem.tr/gizlilik-politikasi/

---

## 7. Privacy Policy URL (zorunlu alan)

```
https://guncelgundem.tr/gizlilik-politikasi/
```
(2026-10-03 itibarıyla canlı doğrulama: HTTP 200, yönlendirme yok.)
