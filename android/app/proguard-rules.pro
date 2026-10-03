# GüncelGündem — Release derleme ProGuard/R8 kuralları
#
# Mevcut mimaride reflection yoktur: Dio, flutter_bloc, equatable, Material,
# flutter_svg, flutter_widget_from_html_core, cached_network_image,
# image_picker, url_launcher, path_provider, shared_preferences, crypto,
# connectivity_plus — hiçbiri runtime reflection gerektirmez.
#
# Flutter embedding ve plugin'ler zaten varsayılan Flutter kurallarıyla
# korunur (proguard-android-optimize.txt + plugin-provided rules).
# Burayı yalnız bir çökme oluşursa genişletin.

# İpuçları:
# - Firebase (TUR 2'de eklenecek) için ek kural GEREKMEZ (firebase_messaging
#   kendi consumer rules'larını içerir).
# - google_mobile_ads eklenirse okunması tavsiye edilir:
#     https://developers.google.com/admob/flutter/eu-consent
