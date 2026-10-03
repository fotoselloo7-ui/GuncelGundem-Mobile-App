# Google Play — Data Safety Formu (Koddan Çıkarılmış)

**Uygulama:** GüncelGündem · `tr.guncelgundem.app`
**Kaynak:** Flutter kaynak kodu denetimi (tahmin yok). Tarih: 2026-10-03

---

## 1. Özet

| Soru | Yanıt | Kod Dayanağı |
|---|---|---|
| Veri topluyor mu? | **Evet (sınırlı)** | `device_repository.dart`, `api_service.dart` |
| Veri üçüncü tarafla paylaşılıyor mu? | **Hayır** | Yalnız kendi backend'i (`guncelgundem.tr`) çağrılır |
| Aktarım şifreli mi? | **Evet (HTTPS)** | `AppConfig._productionUrl` = `https://guncelgundem.tr/api/mobile/v1` |
| Kullanıcı silme talep edebilir mi? | **Evet (e-posta ile)** | Hesap sistemi yok; cihaz kaydı anonim |
| Hesap sistemi var mı? | **Hayır** | Kod taramasında login/register/auth akışı yok |
| Reklam SDK'sı var mı? | **Hayır** | `pubspec.yaml` içinde reklam paketi yok |
| Analitik SDK (3. taraf) var mı? | **Hayır** | Analitik kendi backend'ine gider (`analytics_service.dart`) |

---

## 2. Toplanan Veri Türleri

### 2.1 Uygulama Etkinliği → Diğer Kullanıcı Tarafından Oluşturulan İçerik
**Toplanıyor · Paylaşılmıyor · Zorunlu değil (yalnız kullanıcı gönderirse)**

"Haber Gönder" (`NewsTipRequest`) alanları:
- `title`, `description` — kullanıcının yazdığı ihbar metni
- `locationId` — seçilen il (opsiyonel)
- `contactName`, `contactPhone`, `contactEmail` — **opsiyonel**, kullanıcı girerse
- `consent` — KVKK onay bayrağı
- `photo` — **opsiyonel** fotoğraf (multipart)

Amaç: **Uygulama işlevselliği** (editöryel moderasyon kuyruğu).
Not: İçerik asla otomatik yayınlanmaz; sunucuda `RECEIVED` durumunda editör onayına düşer.

### 2.2 Kişisel Bilgiler → Ad / E-posta / Telefon
**Toplanıyor · Paylaşılmıyor · Zorunlu değil**
Yalnızca "Haber Gönder" formunda kullanıcı isterse girer. Amaç: ihbar doğrulaması için geri dönüş.

### 2.3 Fotoğraflar
**Toplanıyor · Paylaşılmıyor · Zorunlu değil**
Yalnız kullanıcı "Haber Gönder" ekranında fotoğraf eklerse. Modern platform seçicisi kullanılır
(`image_picker` → Android Photo Picker / iOS PHPicker). **Geniş galeri izni istenmez.**

### 2.4 Uygulama Bilgileri ve Performans → Cihaz veya diğer kimlikler
**Toplanıyor · Paylaşılmıyor · Zorunlu**
- `device_id`: **uygulama tarafından üretilen rastgele UUID v4**
  (`device_storage.dart:getOrCreateDeviceId` → `generateUuidV4()`, `SharedPreferences`'ta saklanır).
  **Donanım kimliği, reklam kimliği, IMEI, MAC adresi veya telefon numarası DEĞİLDİR.**
- `platform` (`android`/`ios`), `app_version`, `locale`
- `push_token` — yalnız push altyapısı etkinleştirildiğinde (`updateDevice` → `push_token`)

Amaç: **Uygulama işlevselliği** (bildirim hedefleme, tercih senkronizasyonu).

### 2.5 Tercihler (kişisel veri sayılmaz, cihaz kaydına bağlı)
- `notifications_enabled`, `breaking_news`
- kategori tercihleri (`category_ids`)
- şehir seçimi (`location_id`)
- sessiz saatler (`quiet_hours`)

Amaç: **Uygulama işlevselliği**.

---

## 3. TOPLANMAYAN Veriler (kod taramasıyla doğrulandı)

- Konum (GPS/precise/background) — **izin istenmiyor**, yalnız kullanıcının elle seçtiği il
- Kişiler, SMS, arama kaydı, takvim — izin yok
- Sağlık / finans verisi
- Reklam kimliği (AAID/IDFA)
- Üçüncü taraf analitik/crash SDK (Firebase Analytics, Crashlytics vb. **yok**)
- Arama sorguları sunucuya **ayrı bir profil olarak** gönderilmez; arama endpoint'i sorguyu
  yalnız sonuç döndürmek için kullanır, kişiye bağlı geçmiş tutulmaz

---

## 4. Güvenlik ve Silme

- **Aktarımda şifreleme:** Evet — tüm üretim trafiği HTTPS.
- **Silme talebi:** Hesap sistemi olmadığından uygulama içi hesap silme akışı yoktur (N/A).
  Kullanıcı, cihaz kaydının ve gönderdiği ihbarın silinmesini gizlilik politikasındaki
  iletişim kanalından talep edebilir: https://guncelgundem.tr/gizlilik-politikasi/
- **Veri saklama:** Backend editöryel politikasına tabidir.

---

## 5. Play Console Form Yanıtları (hızlı doldurma)

| Play Console alanı | Seçim |
|---|---|
| Does your app collect or share any of the required user data types? | Yes |
| Is all of the user data collected by your app encrypted in transit? | Yes |
| Do you provide a way for users to request that their data is deleted? | Yes (e-posta/iletişim yoluyla) |
| Data types: Personal info → Name, Email address, Phone number | Collected, not shared, optional |
| Data types: Photos and videos → Photos | Collected, not shared, optional |
| Data types: App activity → Other user-generated content | Collected, not shared, optional |
| Data types: App info and performance → Device or other IDs | Collected, not shared, required |
| Contains ads | **No** |
