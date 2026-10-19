# Güncel Gündem — App Store ASO Paketi (TR)
Tarih: 2026-10-19
Durum: TASLAK — App Store Connect'e henüz uygulanmadı
Canlı URL: https://apps.apple.com/tr/app/g%C3%BCncel-g%C3%BCndem-son-dakika/id6818792857

## Yayın güvenliği
- Canlı iOS 1.0 yayında kalır. ASO değişiklikleri için mevcut sürümü yayından KALDIRMA.
- Uygulama adını hiçbir koşulda değiştirme: Güncel Gündem: Son Dakika
- Subtitle, keywords, description, screenshots ve kategori değişiklikleri gerekli olduğunda yeni sürümün App Review incelemesine girer; sürüm için yeni build yüklenir.
- Promotional Text mevcut yayında yeni sürüm olmadan düzenlenebilir.
- Canlı sistem veya API işlevlerini ASO için değiştirme.
- Ekran görüntüsü üzerindeki vaatler gerçek uygulamayla uyumlu olmalı.

## Mevcut doğrulanan alanlar
- App name: Güncel Gündem: Son Dakika
- Mevcut subtitle: Haber, Yerel Gündem, Bildirim
- Primary category: News
- Secondary category: Reference
- Mağaza, uygulama ikili dosyasının dilini English olarak gösteriyor; App Store Connect birincil metaveri dili Turkish. Native iOS localization kontrolü gerekli.

## Önerilen metadata (tr-TR)
App Name (DEĞİŞTİRME):
Güncel Gündem: Son Dakika

Subtitle (29 / 30 karakter):
Yerel Haberler ve Bildirimler

Promotional Text (142 / 170 karakter — yeni sürüm beklemeden uygulanabilir):
Türkiye ve dünyadan son dakika gelişmelerini, 81 ilde yerel haberleri ve ilgi alanına göre bildirimleri Güncel Gündem ile tek yerden takip et.

Keywords (91 / 100 UTF-8 bayt; virgülle ayır, başlık ve subtitle kelimelerini tekrarlama):
ekonomi,spor,teknoloji,dünya,manşet,analiz,siyaset,sağlık,yaşam,şehir,ilçe,piyasalar

Description:
Güncel Gündem ile Türkiye ve dünyadan son dakika haberlerini, şehir ve ilçene özel yerel gelişmeleri, ekonomi, spor, teknoloji ve daha pek çok alandaki güncel başlıkları tek yerden takip et.

SON DAKİKA HABERLERİ
Önemli gelişmeleri ve manşetleri sade, hızlı ve kolay okunabilir bir haber akışında keşfet.

ŞEHRİM — YEREL HABERLER
81 il ve ilçeler için yerel içeriklere ulaş. Yaşadığın veya merak ettiğin şehirdeki gelişmeleri takip et.

KİŞİSELLEŞTİRİLEBİLİR BİLDİRİMLER
Son dakika, kategori ve şehir tercihlerine göre haber bildirimlerini yönet. Sessiz saatlerle bildirim akışını kendine göre düzenle.

TÜRKİYE, DÜNYA VE KATEGORİLER
Gündem, ekonomi, spor, teknoloji, sağlık, yaşam ve diğer kategorilerdeki gelişmelere hızlıca ulaş. Arama özelliğiyle ilgilendiğin haberleri bul.

BİLGİ KÖŞESİ
Rehberleri, analizleri ve derinlemesine içerikleri incele; gündemin arka planını keşfet.

HABER GÖNDER
Tanık olduğun bir gelişmeyi metin ve fotoğrafla editör ekibimize ilet.

ŞEHRİNE AİT BİLGİLER
Seçtiğin şehre ait hava durumu ve uygulamanın desteklediği güncel bilgileri görüntüle.

Güncel Gündem, haber okumayı ve şehir gündemini takip etmeyi kolaylaştıran bir mobil haber uygulamasıdır.

İnternet sitesi: https://guncelgundem.tr
İletişim ve destek: https://guncelgundem.tr/iletisim/

Support URL:
https://guncelgundem.tr/iletisim/

Marketing URL:
https://guncelgundem.tr/

Privacy Policy:
https://guncelgundem.tr/gizlilik-politikasi/

Primary Category:
News — koru.

Secondary Category:
Reference — mevcut; Magazines & Newspapers ile değiştirmeden önce kategorinin hedef kitleye uygunluğunu ayrıca değerlendir.

## Ekran görüntüsü ASO metinleri (gerçek UI ile eşleştirildikten sonra)
1. Son Dakika Haberleri Tek Ekranda
2. 81 İlden Yerel Gelişmeler
3. İlgi Alanına Göre Bildirimler
4. Ekonomi, Spor ve Teknoloji
5. Haber Gönder, Gündeme Katıl

Not: Yukarıdaki metinler var olan görsellerin otomatik değiştirildiği anlamına gelmez. Yeni görseller gerçek uygulamadan alınan ekran görüntülerine dayanmalı ve mağaza ölçülerine uygun hazırlanmalı.

## Türkçe uygulama dili (ayrı ikili dosya düzeltmesi)
App Store'daki Supported Languages alanı 'English' gösteriyor. Bu alan metadata dili değil, iOS binary localization bilgisidir.
- ios/Runner.xcodeproj/project.pbxproj içinde developmentRegion=en ve knownRegions=(en,Base) mevcut.
- ios/Runner/Info.plist içindeki CFBundleDevelopmentRegion ${DEVELOPMENT_LANGUAGE} olarak ayarlı.
- Türkçe desteklenen dilinin doğru bildirilmesi için Xcode native localization ve gerekirse CFBundleLocalizations (tr) eklenmesini, yeni iOS build üretilerek doğrulanmasını planla.
- Flutter uygulamanın gerçekten Türkçe çalıştığını kontrol etmeden ikinci bir dili destekliyor gibi tanıtma.
- Bu belge tek başına Flutter/Xcode kaynak kodunu değiştirmez.

## Yayına alma sırası
1. App Store Connect > iOS Version 1.0 mevcut keywords, description, promotional text ve screenshots alanlarını gözden geçir.
2. Uygulama adını değiştirmeden şimdi uygulanabilecek promotional text'i Save ile kaydet.
3. Yeni iOS 1.0.1 sürüm taslağı aç ve yeni build hazırla; mevcut canlı 1.0'a dokunma.
4. Subtitle, keywords, description, gerekiyorsa screenshotları ve native localization düzeltmesini yeni sürüme yerleştir.
5. Metinlerin gerçekten çalışır özellikleri yansıttığını ve gizlilik beyanıyla tutarlı olduğunu doğrula.
6. Yeni sürümü incelemeye gönder; 1.0 yayınını kesme.
7. Onaylandığında yayınla ve mağaza metadatasını kontrol et.

Kaynaklar:
- https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version
- https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
