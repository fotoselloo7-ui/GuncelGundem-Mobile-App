# 6D-C gerçek Android önizlemesi

Cihaz: Pixel 9, Android 15 / API 35, emulator-5554; yaklaşık 411 dp genişlik.

Debug API: `http://10.0.2.2:8080/api/mobile/v1`.
Production URL değiştirilmedi. Uygulama debug olarak açık bırakıldı.

Screenshot dizini: `C:\GuncelGundem-Mobile-App\preview\6dc-final\`.
Aşağıdaki 24 PNG doğrudan emulator screencap çıktısıdır; mockup veya test golden değildir.

## İstenen ekranlar

- A: [Home top](C:/GuncelGundem-Mobile-App/preview/6dc-final/A-home-top.png)
- B: [Home middle](C:/GuncelGundem-Mobile-App/preview/6dc-final/B-home-middle.png)
- C: [Home lower](C:/GuncelGundem-Mobile-App/preview/6dc-final/C-home-lower.png)
- D: [Haber domaini](C:/GuncelGundem-Mobile-App/preview/6dc-final/D-categories-news.png)
- D2: [Gündem alt kategorileri](C:/GuncelGundem-Mobile-App/preview/6dc-final/D2-news-subcategories.png)
- E: [Bilgi Köşesi domaini](C:/GuncelGundem-Mobile-App/preview/6dc-final/E-categories-blog.png)
- E2: [Blog alt kategorileri](C:/GuncelGundem-Mobile-App/preview/6dc-final/E2-blog-subcategories.png)
- F: [Haber kategorisi, iki kolon](C:/GuncelGundem-Mobile-App/preview/6dc-final/F-news-category-two-columns.png)
- G: [Asayiş alt kategorisi, iki kolon](C:/GuncelGundem-Mobile-App/preview/6dc-final/G-news-subcategory-two-columns.png)
- H: [81 il seçim ekranı](C:/GuncelGundem-Mobile-App/preview/6dc-final/H-city-selection.png)
- H2: [İlçe seçimi ve il düzeyinde devam](C:/GuncelGundem-Mobile-App/preview/6dc-final/H2-city-district-selection.png)
- I: [Şehrim, kayıtlı ilçe](C:/GuncelGundem-Mobile-App/preview/6dc-final/I-my-city.png)
- I2: [Şehrim, Adana yerel haberleri](C:/GuncelGundem-Mobile-App/preview/6dc-final/I2-my-city-adana.png)
- J: [Video, gerçek boş durum](C:/GuncelGundem-Mobile-App/preview/6dc-final/J-video.png)
- K: [Haber Gönder route](C:/GuncelGundem-Mobile-App/preview/6dc-final/K-submit.png)
- K2: [Son Dakika route](C:/GuncelGundem-Mobile-App/preview/6dc-final/K2-breaking.png)
- K3: [Arama sonucu](C:/GuncelGundem-Mobile-App/preview/6dc-final/K3-search.png)
- K4: [Mevcut minimal haber detayı](C:/GuncelGundem-Mobile-App/preview/6dc-final/K4-news-detail.png)
- K5: [Öne Çıkan tam arşiv, featured veri yok](C:/GuncelGundem-Mobile-App/preview/6dc-final/K5-featured-archive.png)
- K6: [Güncel Haberler tam arşiv](C:/GuncelGundem-Mobile-App/preview/6dc-final/K6-latest-archive.png)
- K7: [Çok Okunanlar tam arşiv](C:/GuncelGundem-Mobile-App/preview/6dc-final/K7-most-read-archive.png)
- L: [Ticker ilk kare](C:/GuncelGundem-Mobile-App/preview/6dc-final/L-breaking-ticker.png)
- L2: [Ticker 5,5 saniye sonraki kare](C:/GuncelGundem-Mobile-App/preview/6dc-final/L2-breaking-ticker-next.png)
- L3: [Ticker dokunuşuyla gerçek haber detayı](C:/GuncelGundem-Mobile-App/preview/6dc-final/L3-ticker-article.png)

## Görsel kontrol notları

Kategori/alt kategori ve arşiv gridleri iki kolon; tarih ayrı alanda, uzun başlıklar kontrollü üç satırlık ellipsis kullanıyor. Son Dakika tek kolon istisnası korunuyor. Home'da ana haber section'ları dört, yerel haberler üç kayıtla sınırlı. B/C görüntüleri şehir seçimi öncesinde, A ve I2 seçim sonrasında alındı.

Blog kartlarında başlıkla uyuşmayan gerçek backend kapakları devam ediyor; SVG render sorunu değil. Video ve gönderim ekranları gerçek veri/API yokluğunu gösteriyor. Finans/hava/aktif olmayan reklam için sahte alan eklenmedi.
