import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../app/bottom_nav_preferences.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/notification_preference_model.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_city.dart';
import '../../home/presentation/home_widgets.dart';
import 'personalization_widgets.dart';
import 'contact_screen.dart';

/// Tercihler / Uygulama Ayarları
///
/// Tek kişiselleştirme merkezi: Şehrim, İlgi Alanları, Bildirimler,
/// Sessiz Saatler ve Alt Menü Düzeni. Yeni depolama motoru kurmaz;
/// şehir + ilgi alanları mevcut cihaz tercihlerine (tek canonical state),
/// alt menü düzeni [BottomNavPreferences]'a yazılır.
class AppSettingsScreen extends StatefulWidget {
  final DeviceRepository? device;
  final TaxonomyRepository? taxonomy;
  const AppSettingsScreen({super.key, this.device, this.taxonomy});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late final _device = widget.device ?? DeviceRepository();
  late final _taxonomy = widget.taxonomy ?? TaxonomyRepository();

  NotificationPreferenceModel _prefs = const NotificationPreferenceModel();
  List<CategoryModel> _categories = const [];
  List<LocationProvinceModel> _provinces = const [];
  bool _loading = true;
  bool _categoriesFailed = false;

  @override
  void initState() {
    super.initState();
    BottomNavPreferences.instance.load();
    _load();
  }

  Future<void> _load() async {
    final prefs = await _device.getPreferences();
    List<CategoryModel> categories = const [];
    List<LocationProvinceModel> provinces = const [];
    var categoriesFailed = false;
    try {
      categories = mainNewsCategories(await _taxonomy.getCategories());
    } catch (_) {
      categoriesFailed = true;
    }
    try {
      provinces = await _taxonomy.getLocations();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _categories = categories;
      _provinces = provinces;
      _categoriesFailed = categoriesFailed;
      _loading = false;
    });
  }

  Future<void> _reloadPrefs() async {
    final prefs = await _device.getPreferences();
    if (mounted) setState(() => _prefs = prefs);
  }

  Future<void> _toggleInterest(String id, bool selected) async {
    final ids = List<String>.from(_prefs.categoryIds);
    if (selected) {
      if (!ids.contains(id)) ids.add(id);
    } else {
      ids.remove(id);
    }
    final next = _prefs.copyWith(categoryIds: ids);
    setState(() => _prefs = next);
    await _device.updatePreferences(next);
  }

  Future<void> _open(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (mounted) await _reloadPrefs();
  }

  String get _quietLabel {
    final q = _prefs.quietHours;
    if (!q.enabled) return 'Kapalı';
    return '${q.start ?? '22:00'} – ${q.end ?? '07:00'}';
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    final city = HomeCity.resolve(_prefs.locationIds, _provinces);
    return Theme(
      data: homeTheme(brand),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          toolbarHeight: 64,
          iconTheme: const IconThemeData(color: homeNavy),
          shape: const Border(bottom: BorderSide(color: homeLine)),
          title: const Text(
            'Tercihler',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: homeNavy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  const PrefSectionTitle('Şehrim'),
                  PrefCard(
                    padding: EdgeInsets.zero,
                    child: _NavTile(
                      key: const ValueKey('settings-city'),
                      icon: Icons.location_on_outlined,
                      title: _prefs.locationIds.isEmpty
                          ? 'Şehir seçilmedi'
                          : (city?.label ?? 'Seçili şehir'),
                      subtitle:
                          'Hava, namaz, yerel haberler ve yerel bildirimler',
                      action: _prefs.locationIds.isEmpty ? 'Seç' : 'Değiştir',
                      onTap: () => _open('/sehrim'),
                    ),
                  ),
                  const PrefSectionTitle(
                    'İlgi Alanları',
                    subtitle:
                        'Seçtikleriniz kategori bildirimlerinde de kullanılır.',
                  ),
                  PrefCard(
                    child: _categories.isEmpty
                        ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _categoriesFailed
                                      ? 'Kategoriler şu an yüklenemedi.'
                                      : 'Henüz kategori bulunmuyor.',
                                  style: const TextStyle(color: homeMuted),
                                ),
                              ),
                              if (_categoriesFailed)
                                TextButton(
                                  onPressed: () {
                                    setState(() => _loading = true);
                                    _load();
                                  },
                                  child: const Text('Tekrar Dene'),
                                ),
                            ],
                          )
                        : InterestChips(
                            categories: _categories,
                            selectedIds: _prefs.categoryIds,
                            onToggle: _toggleInterest,
                          ),
                  ),
                  const PrefSectionTitle('Bildirimler'),
                  PrefCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _NavTile(
                          key: const ValueKey('settings-notifications'),
                          icon: Icons.notifications_none_rounded,
                          title: 'Bildirim Tercihleri',
                          subtitle: _prefs.notificationsEnabled
                              ? 'Açık · Son Dakika ${_prefs.breakingNews ? 'açık' : 'kapalı'}'
                              : 'Kapalı',
                          onTap: () => _open('/bildirim-ayarlari'),
                        ),
                        const Divider(height: 1, color: homeLine),
                        _NavTile(
                          key: const ValueKey('settings-quiet'),
                          icon: Icons.nightlight_round,
                          title: 'Sessiz Saatler',
                          subtitle: _quietLabel,
                          onTap: () => _open('/bildirimler'),
                        ),
                      ],
                    ),
                  ),
                  const PrefSectionTitle(
                    'Alt Menü Düzeni',
                    subtitle: 'Sağdaki iki sekmeyi kendinize göre seçin.',
                  ),
                  PrefCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NavSlotPicker(),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          key: const ValueKey('settings-nav-reset'),
                          onPressed: BottomNavPreferences.instance.reset,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Varsayılana dön'),
                          style: TextButton.styleFrom(
                            foregroundColor: homeNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PrefSectionTitle('Hakkında'),
                  PrefCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _NavTile(
                          key: const ValueKey('settings-partnership'),
                          icon: Icons.campaign_outlined,
                          title: 'Özel Haber & İş Birliği',
                          subtitle: 'Erişim istatistikleri ve iletişim kanalları',
                          onTap: () => _open('/ozel-haber-isbirligi'),
                        ),
                        const Divider(height: 1, color: homeLine),
                        _NavTile(
                          key: const ValueKey('settings-contact'),
                          icon: Icons.contact_mail_outlined,
                          title: 'Bize Ulaşın',
                          subtitle: 'İletişim ve geliştirici bilgileri',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ContactScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: homeLine),
                        _NavTile(
                          key: const ValueKey('settings-privacy'),
                          icon: Icons.privacy_tip_outlined,
                          title: 'Gizlilik Politikası',
                          subtitle: AppConfig.privacyUrl,
                          onTap: () => _openUrl(AppConfig.privacyUrl),
                        ),
                        const Divider(height: 1, color: homeLine),
                        _NavTile(
                          key: const ValueKey('settings-kvkk'),
                          icon: Icons.gavel_rounded,
                          title: 'KVKK Aydınlatma Metni',
                          subtitle: AppConfig.kvkkUrl,
                          onTap: () => _openUrl(AppConfig.kvkkUrl),
                        ),
                        const Divider(height: 1, color: homeLine),
                        _NavTile(
                          key: const ValueKey('settings-terms'),
                          icon: Icons.description_outlined,
                          title: 'Kullanım Şartları',
                          subtitle: AppConfig.termsUrl,
                          onTap: () => _openUrl(AppConfig.termsUrl),
                        ),
                        const Divider(height: 1, color: homeLine),
                        _NavTile(
                          key: const ValueKey('settings-cookies'),
                          icon: Icons.cookie_outlined,
                          title: 'Çerez Politikası',
                          subtitle: AppConfig.cookiePolicyUrl,
                          onTap: () => _openUrl(AppConfig.cookiePolicyUrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '${brand.siteName} · Sürüm ${AppConfig.appVersion} (${AppConfig.buildNumber})',
                      style: const TextStyle(color: homeMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
      }
    }
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback onTap;
  const _NavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: homeBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: homeNavy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: homeNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: homeMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (action != null)
            Text(
              action!,
              style: TextStyle(
                color: BrandingState.instance.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Icon(Icons.chevron_right, color: homeMuted),
        ],
      ),
    ),
  );
}
