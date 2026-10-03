# Google Play — Mağaza Listesi (TR)

**Paket adı:** `tr.guncelgundem.app`
**Kategori:** Haber ve Dergiler (News & Magazines)
**İçerik derecelendirmesi:** IARC anketi — "Haber/Bilgi uygulaması" seçilir
**Contains Ads:** **HAYIR** (kodda reklam SDK'sı yok — `pubspec.yaml` doğrulandı)
**In-app purchases:** Yok

---

## Uygulama Adı (30 karakter sınırı)
```
GüncelGündem
```

## Kısa Açıklama (80 karakter sınırı)
```
Türkiye'nin güncel gündemi: son dakika, şehrinizin haberleri ve bilgi rehberleri.
```
(80 karakter)

## Tam Açıklama (4000 karakter sınırı)
```
GüncelGündem, Türkiye'nin gündemini hızlı ve sade bir şekilde takip etmeniz için tasarlandı.

SON DAKİKA
Önemli gelişmeler olduğu anda bildirim alın. Son dakika akışı ayrı bir bölümde toplanır;
gereksiz bildirimle boğulmazsınız.

ŞEHRİM
Yaşadığınız ili seçin, yerel haberleri ana ekranınızda görün. 81 il desteklenir.

KATEGORİLER
Gündem, ekonomi, spor, teknoloji, sağlık, dünya ve daha fazlası. İlgilendiğiniz kategorileri
seçin, bildirimleri yalnız onlardan alın.

BİLGİ KÖŞESİ
Haberin ötesinde kalıcı içerik: yemek tarifleri, pratik ev bilgileri, gezi rehberleri,
teknoloji rehberleri, sağlık ve yaşam yazıları. Adım adım tarifler, sıkça sorulan sorular
ve uzman editör rehberleriyle.

ARAMA
Aradığınız habere başlıktan hızlıca ulaşın.

HABER GÖNDER
Çevrenizde olan bir olayı editör ekibimize iletin. İsterseniz fotoğraf ekleyin.
Gönderdiğiniz içerik asla otomatik yayınlanmaz; editör incelemesinden geçer.

BİLDİRİM KONTROLÜ SİZDE
- Bildirimleri tamamen açıp kapatabilirsiniz
- Yalnız son dakika bildirimi alabilirsiniz
- Kategori ve şehir bazında seçim yapabilirsiniz
- Sessiz saatler tanımlayarak gece bildirim almayı durdurabilirsiniz

GİZLİLİK
Uygulama hesap açmanızı istemez. Konumunuza erişmez; şehrinizi siz seçersiniz.
Rehberinize, mesajlarınıza veya arama kaydınıza erişmez. Reklam takibi yapmaz.

Yasal metinler:
Gizlilik Politikası: https://guncelgundem.tr/gizlilik-politikasi/
KVKK Aydınlatma Metni: https://guncelgundem.tr/kvkk/
Kullanım Şartları: https://guncelgundem.tr/kullanim-sartlari/
Çerez Politikası: https://guncelgundem.tr/cerez-politikasi/
```

---

## Zorunlu URL'ler

| Alan | Değer |
|---|---|
| **Privacy Policy** | `https://guncelgundem.tr/gizlilik-politikasi/` |
| Website | `https://guncelgundem.tr/` |
| E-posta | *(yayıncı tarafından doldurulacak — Play Console zorunlu alanı)* |

## Legal References (açıklama ve destek sayfalarında kullanılacak)

| Metin | URL | HTTP (2026-10-03) |
|---|---|---|
| KVKK Aydınlatma Metni | `https://guncelgundem.tr/kvkk/` | 200 |
| Gizlilik Politikası | `https://guncelgundem.tr/gizlilik-politikasi/` | 200 |
| Kullanım Şartları | `https://guncelgundem.tr/kullanim-sartlari/` | 200 |
| Çerez Politikası | `https://guncelgundem.tr/cerez-politikasi/` | 200 |

---

## Grafik Varlıklar (checklist)

| Varlık | Gereksinim | Durum |
|---|---|---|
| Uygulama ikonu | 512×512 PNG (32-bit, alfa) | Marka ikonundan türetilecek (`assets/brand/emblem.png`) |
| Feature graphic | 1024×500 PNG/JPG | **Hazırlanacak** |
| Telefon ekran görüntüsü | En az 2, 16:9 veya 9:16, min 320px | **Gerçek cihaz/emülatörden alınacak** (aşağıdaki plan) |
| 7" tablet | Opsiyonel | — |
| 10" tablet | Opsiyonel | — |

### Ekran Görüntüsü Planı (gerçek uygulamadan alınacak — sahte UI üretilmeyecek)
1. **Ana Sayfa** — manşet + kategori şeridi
2. **Son Dakika** — son dakika akışı
3. **Haber Detayı** — okunabilir tipografi, kaynak/yazar bilgisi
4. **Şehrim** — il seçimi ve yerel haberler
5. **Bilgi Köşesi** — rehber/tarif kartları
6. **Arama** — sonuç listesi
7. **Haber Gönder** — ihbar formu (örnek metinle, gerçek kişisel veri olmadan)

---

## Play Console — Uygulama İçeriği (App content) Yanıtları

| Bölüm | Yanıt |
|---|---|
| Privacy policy | `https://guncelgundem.tr/gizlilik-politikasi/` |
| Ads | Uygulamada reklam **yok** |
| App access | Tüm işlevler giriş olmadan erişilebilir (hesap sistemi yok) |
| Content rating | IARC anketi — Haber/Bilgi |
| Target audience | 13+ (haber uygulaması; çocuklara yönelik değil) |
| News app | **Evet** — News app declaration doldurulmalı (yayıncı bilgisi) |
| Data safety | `STORE-DATA-SAFETY-GOOGLE.md` dosyasındaki tabloya göre |
| Government app | Hayır |
| Financial features | Hayır |
| Health | Hayır |

### News App Declaration notu
Uygulama bir haber uygulamasıdır. Play'in haber uygulaması beyanı için yayıncı kimliği,
editöryel sorumlu ve iletişim bilgisi sitede erişilebilir durumdadır
(künye + gizlilik politikası sayfaları).
