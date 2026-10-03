import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alt menünün kullanıcı tarafından değiştirilebilen sağ iki slotunda
/// gösterilebilecek GERÇEK ve çalışan hedefler.
enum NavDestination {
  city('city', 'Şehrim', Icons.location_on_outlined, '/sehrim'),
  video('video', 'Video', Icons.play_circle_outline, '/videolar'),
  infoCorner(
    'info_corner',
    'Bilgi Köşesi',
    Icons.menu_book_outlined,
    '/bilgi-kosesi',
  ),
  categories(
    'categories',
    'Kategoriler',
    Icons.grid_view_rounded,
    '/haber-kategorileri',
  );

  final String key;
  final String label;
  final IconData icon;
  final String route;
  const NavDestination(this.key, this.label, this.icon, this.route);

  static NavDestination? fromKey(String? key) {
    for (final value in values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

/// Alt Menü Düzeni
///
/// İlk 3 slot sabittir (Ana Sayfa, Son Dakika, Haber Gönder). Slot 4 ve 5
/// kullanıcı tarafından seçilir, aynı hedef iki slotta birden bulunamaz ve
/// seçim yerel olarak kalıcıdır. Varsayılan: Şehrim + Video.
class BottomNavPreferences extends ChangeNotifier {
  BottomNavPreferences._();
  static final BottomNavPreferences instance = BottomNavPreferences._();

  static const slot4Key = 'app_bottom_nav_slot4_v1';
  static const slot5Key = 'app_bottom_nav_slot5_v1';
  static const defaultSlot4 = NavDestination.city;
  static const defaultSlot5 = NavDestination.video;

  NavDestination _slot4 = defaultSlot4;
  NavDestination _slot5 = defaultSlot5;
  bool _loaded = false;

  NavDestination get slot4 => _slot4;
  NavDestination get slot5 => _slot5;

  /// Bar indeksine (3 veya 4) karşılık gelen hedef.
  NavDestination destinationAt(int index) => index == 4 ? _slot5 : _slot4;

  /// Hedef alt menüdeyse bar indeksi (3/4), değilse -1.
  int indexOf(NavDestination destination) {
    if (_slot4 == destination) return 3;
    if (_slot5 == destination) return 4;
    return -1;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s4 = NavDestination.fromKey(prefs.getString(slot4Key));
      final s5 = NavDestination.fromKey(prefs.getString(slot5Key));
      if (s4 != null && s5 != null && s4 != s5) {
        _slot4 = s4;
        _slot5 = s5;
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Yerel depo okunamazsa varsayılan düzen korunur.
    }
  }

  /// Slot ataması yapar. Seçilen hedef diğer slottaysa iki slot yer değiştirir;
  /// böylece aynı öğe hiçbir zaman iki slotta bulunmaz.
  Future<void> setSlot(int index, NavDestination destination) async {
    var s4 = _slot4, s5 = _slot5;
    if (index == 3) {
      if (destination == s5) s5 = s4;
      s4 = destination;
    } else {
      if (destination == s4) s4 = s5;
      s5 = destination;
    }
    if (s4 == _slot4 && s5 == _slot5) return;
    _slot4 = s4;
    _slot5 = s5;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(slot4Key, s4.key);
      await prefs.setString(slot5Key, s5.key);
    } catch (_) {}
  }

  Future<void> reset() async {
    await setSlot(3, defaultSlot4);
    await setSlot(4, defaultSlot5);
  }
}
