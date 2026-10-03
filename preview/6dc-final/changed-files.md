# 6D-C değişen dosyalar

Flutter uygulaması: `C:\GuncelGundem-Mobile-App`.

## Uygulama kaynakları

- [category_model.dart](C:/GuncelGundem-Mobile-App/lib/data/models/category_model.dart) — API content_types alanı; blog-only taxonomy kayıtlarını haber domaininden ayırma.
- [news_repository.dart](C:/GuncelGundem-Mobile-App/lib/data/repositories/news_repository.dart) — mevcut ETag/cache mekanizmasıyla sayfalı arşivler.
- [api_service.dart](C:/GuncelGundem-Mobile-App/lib/services/api_service.dart) — arşiv isteği ve isteğe bağlı trending sayfalaması.
- [home_screen.dart](C:/GuncelGundem-Mobile-App/lib/features/home/presentation/home_screen.dart) — kontrollü section limitleri, ortak kompakt grid, 5 saniyelik ticker ve çalışan hedefler.
- [blog_category_explorer.dart](C:/GuncelGundem-Mobile-App/lib/features/blog/presentation/blog_category_explorer.dart) — mevcut explorer'ın gömülü kullanım seçeneği; bottom sheet varsayılanı korunur.
- [news_navigation.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/news_navigation.dart) — mevcut Navigator üzerinde kategori explorer, şehir, video, gönderim ve arşiv hedefleri.
- [news_feed_screen.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/news_feed_screen.dart) — lazy iki kolonlu kategori/arama/arşiv, mevcut pagination ve Son Dakika istisnası.
- [news_feed_card.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/widgets/news_feed_card.dart) — ortak CompactNewsGridCard; 4:3 görsel, üç satırlık başlık, tarih.
- [news_category_explorer_screen.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/news_category_explorer_screen.dart) — yeni Haber/Bilgi Köşesi domain seçimi ve aşamalı haber taxonomy explorer.
- [city_screen.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/city_screen.dart) — yeni il/ilçe seçimi, mevcut preference storage ve sayfalı yerel haber ekranı.
- [video_screen.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/video_screen.dart) — yeni çalışan route; yayınlanmış video yokken boş durum.
- [news_submit_screen.dart](C:/GuncelGundem-Mobile-App/lib/features/news/presentation/news_submit_screen.dart) — yeni çalışan route; Mobile submission API olmadığını belirten durum.

## Hedefli test

- [content_navigation_test.dart](C:/GuncelGundem-Mobile-App/test/phase6dc/content_navigation_test.dart) — 21 hedefli test; limits, ticker, domain/hierarchy, şehir preferences, route ve responsive grid.

## Backend: yalnız safe additive Mobile adapter değişiklikleri

- [MobileSerializer.php](C:/GuncelGundem-Mobile-Dev/guncelgundem.tr/app/Mobile/MobileSerializer.php) — taxonomy content_types alanını dışarı sunma.
- [MobileNewsController.php](C:/GuncelGundem-Mobile-Dev/guncelgundem.tr/app/Mobile/MobileNewsController.php) — opt-in featured filtresi ve opt-in trending pagination. Eski parametresiz davranış korunur.

Crawler, AiWriter, backend içerik kayıtları, renderer, production API URL ve bağımlılıklar değiştirilmedi.

## Kontrol yardımcıları

- [preview-6dc.ps1](C:/GuncelGundem-Mobile-Dev/preview-6dc.ps1) — Android adb gezinme ve gerçek screenshot kaydı.
- [6dc-protected-baseline.sha256](C:/GuncelGundem-Mobile-Dev/6dc-protected-baseline.sha256) — 169 Crawler/AiWriter dosyasının başlangıç SHA-256 değerleri; son karşılaştırma 0 fark.
- `C:\GuncelGundem-Mobile-Dev\flutter-6dc-stage` — doğrulanıp uygulamaya kopyalanan kaynaklar.
- `C:\GuncelGundem-Mobile-Dev\flutter-6dc-originals` — değiştirilen önceki Flutter kaynaklarının geri dönüş kopyaları.

## Doğrulama

- 21 yeni 6D-C testi geçti.
- Mevcut testlerden yalnız hedefli seçim: news pagination/debounce/cache/navigation 6, Home responsive 8, offline preference persistence 1; toplam 36 test geçti.
- 360/390/411/430 dp ve %100/%200 text scale testleri geçti. Full regression çalıştırılmadı.
- `flutter analyze --no-pub`: No issues found.
- İki PHP dosyasında `php -l`: syntax error yok.
- 12 dağıtılmış lib dosyası doğrulanmış stage ile hash olarak aynı.
- Gerçek API page 1/page 2: latest ve trending listelerinde farklı kayıtlar; has_more true.
- Mevcut gerçek veri: latest 1676; trending 1377; featured flag taşıyan yayınlanmış haber 0.
- Home'un mevcut backend featured fallback'i son haberleri gösterir; featured-only tam arşiv şu an boş. Bu mevcut veri farkı gizlenmedi, içerik flag'leri değiştirilmedi.
- Haber taxonomy: 14 news root; 8 blog-only legacy root dışarıda. Ayrı blog API: 18 root, 230 child.

## API sınırlamaları

- `MARKET_DATA_NOT_EXPOSED_TO_MOBILE_API`: döviz/altın/BIST verileri mevcut Mobile Home sözleşmesinde ve Mobile route'larda yok; finans section gizli.
- `WEB_DATA_NOT_EXPOSED_TO_MOBILE_API`: canlı hava/piyasa modülleri, namaz vakitleri, nöbetçi eczane, deprem arşivi, video/foto galeri arşivleri ve native haber gönderimi.
- `API_NOT_AVAILABLE`: web gönderim formu var, Mobile submission endpoint yok; yeni backend gönderim sistemi kurulmadı.
- `NOTIFICATION_SCREEN_PENDING`: Flutter bildirim/preference ekranı mevcut değil; bell güvenli bilgilendirme verir.
- Gerçek yayınlanmış news video içeriği 0; fake video eklenmedi.
- Bazı blog kapakları içerikle uyuşmuyor (ör. mercimek çorbasında piyasa grafik SVG'si); gerçek SVG çiziliyor, backend içerikleri değiştirilmedi.
