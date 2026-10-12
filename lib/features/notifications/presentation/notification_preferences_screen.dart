import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/notification_preference_model.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../design/branding_state.dart';
import '../../../services/notification_permission_service.dart';
import '../../../services/firebase_push_coordinator.dart';
import '../../home/presentation/home_city.dart';
import '../../home/presentation/home_widgets.dart';
import '../../news/presentation/news_navigation.dart';

/// Bildirim Tercihleri Ekranı
///
/// FAZ 5 / BİLDİRİM KOORDİNASYONU — Mevcut cihaz/tercih altyapısını kullanır.
///
/// Yalnız backend (`MobileDeviceValidator`) tarafından desteklenen tercihleri
/// gösterir: global anahtar, Son Dakika, haber kategorileri, seçili şehir
/// (yerel haberler) ve sessiz saatler. Backend'de olmayan tercih üretmez.
class NotificationPreferencesScreen extends StatefulWidget {
  final DeviceRepository? device;
  final TaxonomyRepository? taxonomy;
  final NotificationPermissionService? permission;

  const NotificationPreferencesScreen({
    super.key,
    this.device,
    this.taxonomy,
    this.permission,
  });

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late final _device = widget.device ?? DeviceRepository();
  late final _taxonomy = widget.taxonomy ?? TaxonomyRepository();
  late final _permission = widget.permission ?? NotificationPermissionService();

  bool _loading = true;
  bool _error = false;
  bool _saving = false;

  NotificationPreferenceModel _prefs = const NotificationPreferenceModel();
  List<CategoryModel> _categories = const [];
  List<LocationProvinceModel> _provinces = const [];
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notApplicable;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final prefs = await _device.getPreferences();
      // Taksonomi ve izin durumu ikincil bilgilerdir; hata ekranı tetiklemez.
      List<CategoryModel> categories = const [];
      List<LocationProvinceModel> provinces = const [];
      try {
        categories = await _taxonomy.getCategories();
      } catch (_) {}
      try {
        provinces = await _taxonomy.getLocations();
      } catch (_) {}
      final status = await _permission.status();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _categories = categories;
        _provinces = provinces;
        _permissionStatus = status;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// Yerel değişikliği anında yansıtır ve offline-first olarak kalıcılaştırır.
  Future<void> _apply(NotificationPreferenceModel next) async {
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      await _device.updatePreferences(next);
    } catch (_) {
      // Repository zaten yerelde saklar; kullanıcıya teknik hata gösterilmez.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleMaster(bool value) async {
    // Kullanıcı bildirimleri açtığında (saldırgan değil, talep anında) izin iste.
    if (value) {
      final status = await _permission.request();
      if (mounted) setState(() => _permissionStatus = status);
    }
    await _apply(_prefs.copyWith(notificationsEnabled: value));
    if (value) unawaited(FirebasePushCoordinator.instance.syncToken());
  }

  Future<void> _refreshPermission() async {
    final status = await _permission.status();
    if (mounted) setState(() => _permissionStatus = status);
  }

  Future<void> _requestPermission() async {
    final status = await _permission.request();
    if (mounted) setState(() => _permissionStatus = status);
    if (status == NotificationPermissionStatus.granted) {
      unawaited(FirebasePushCoordinator.instance.syncToken());
    }
  }

  Future<void> _openSystemSettings() async {
    await _permission.openSettings();
    // Ayarlardan dönüşte durumu tazele.
    await _refreshPermission();
  }

  Future<void> _changeCity() async {
    await Navigator.of(context).pushNamed(NewsNavigation.city);
    if (!mounted) return;
    // Şehir seçimi locationIds'i günceller; tercihleri yeniden oku.
    final prefs = await _device.getPreferences();
    List<LocationProvinceModel> provinces = _provinces;
    if (provinces.isEmpty) {
      try {
        provinces = await _taxonomy.getLocations();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _provinces = provinces;
      });
    }
  }

  Future<void> _pickQuietTime({required bool isStart}) async {
    final current = isStart ? _prefs.quietHours.start : _prefs.quietHours.end;
    final initial =
        _parseTime(current) ??
        (isStart
            ? const TimeOfDay(hour: 22, minute: 0)
            : const TimeOfDay(hour: 7, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final formatted = _formatTime(picked);
    final quiet = _prefs.quietHours;
    await _apply(
      _prefs.copyWith(
        quietHours: QuietHoursModel(
          enabled: true,
          start: isStart ? formatted : quiet.start,
          end: isStart ? quiet.end : formatted,
        ),
      ),
    );
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
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
          actions: [
            IconButton(
              key: const ValueKey('open-app-settings'),
              tooltip: 'Tüm Tercihler',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.tune_rounded, color: homeNavy),
              onPressed: () =>
                  Navigator.of(context).pushNamed(NewsNavigation.settings),
            ),
            const SizedBox(width: 4),
          ],
          title: const Text(
            'Bildirimler',
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
            : _error
            ? _buildError()
            : _buildContent(brand),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomeMessage('Bildirim tercihleri yüklenemedi.'),
        TextButton(onPressed: _load, child: const Text('Tekrar Dene')),
      ],
    ),
  );

  Widget _buildContent(BrandingState brand) {
    final enabled = _prefs.notificationsEnabled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (enabled) _buildPermissionBanner(brand),
        _buildMasterCard(brand),
        const SizedBox(height: 16),
        _SectionLabel('Bildirim Türleri', enabled: enabled),
        _buildCard(
          child: _ToggleRow(
            key: const ValueKey('pref-breaking'),
            icon: Icons.bolt_rounded,
            title: 'Son Dakika',
            subtitle: 'Önemli ve acil gelişmeler anında bildirilir.',
            value: _prefs.breakingNews,
            enabled: enabled,
            onChanged: (v) => _apply(_prefs.copyWith(breakingNews: v)),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Kategori Bildirimleri', enabled: enabled),
        _buildCategoriesCard(enabled),
        const SizedBox(height: 16),
        _SectionLabel('Yerel Haberler', enabled: enabled),
        _buildLocationCard(enabled),
        const SizedBox(height: 16),
        _SectionLabel('Sessiz Saatler', enabled: enabled),
        _buildQuietHoursCard(enabled),
        const SizedBox(height: 16),
        // Bildirim tercihleri kişisel veri işlenmesiyle doğrudan ilgilidir;
        // yasal metinler bu ekrandan da erişilebilir olmalıdır. URL'ler
        // AppConfig.legalLinks tek kaynağından okunur (hard-code edilmez).
        const _SectionLabel('Yasal Bilgilendirme', enabled: true),
        _buildLegalCard(),
      ],
    );
  }

  /// KVKK / Gizlilik / Kullanım Şartları / Çerez Politikası bağlantıları.
  /// Bağlantılar uygulama route'u değil, harici tarayıcıda açılır.
  Widget _buildLegalCard() {
    final links = AppConfig.legalLinks;
    return _buildCard(
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: homeLine),
            // ListTile KULLANILMAZ: bu kart arka plan rengi olan bir DecoratedBox
            // içindedir ve ListTile ink/arka planı için Material ata düğümü arar
            // (framework assert'i). Kart yapısına uygun InkWell satırı kullanılır.
            InkWell(
              key: ValueKey('notif-legal-${links[i].url}'),
              onTap: () => _openLegalUrl(links[i].url),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: homeMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            links[i].title,
                            style: const TextStyle(
                              color: homeNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            links[i].url,
                            style: const TextStyle(
                              color: homeMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: homeMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bağlantı açılamadı: $url')),
      );
    }
  }

  Widget _buildPermissionBanner(BrandingState brand) {
    final status = _permissionStatus;
    if (status == NotificationPermissionStatus.granted ||
        status == NotificationPermissionStatus.notApplicable) {
      return const SizedBox.shrink();
    }
    final isPermanent =
        status == NotificationPermissionStatus.permanentlyDenied;
    return Container(
      key: const ValueKey('permission-banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff4f4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: brand.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPermanent
                      ? 'Bildirimler cihaz ayarlarından kapalı'
                      : 'Bildirim izni verilmedi',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: homeNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPermanent
                ? 'Bildirimleri almak için sistem ayarlarından izni açmanız gerekir.'
                : 'Seçtiğiniz bildirimleri alabilmek için izin vermeniz gerekir.',
            style: const TextStyle(color: homeMuted, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: ValueKey(
                isPermanent ? 'permission-open-settings' : 'permission-request',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: brand.primaryColor,
                minimumSize: const Size(48, 44),
              ),
              onPressed: isPermanent ? _openSystemSettings : _requestPermission,
              child: Text(isPermanent ? 'Ayarları Aç' : 'İzin Ver'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterCard(BrandingState brand) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: homeNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildirimler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _prefs.notificationsEnabled
                      ? 'Bildirimler açık. Türleri aşağıdan düzenleyin.'
                      : 'Tüm bildirimler kapalı.',
                  style: const TextStyle(color: Color(0xffc7d2e0), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: const ValueKey('pref-master'),
            value: _prefs.notificationsEnabled,
            activeThumbColor: Colors.white,
            activeTrackColor: brand.primaryColor,
            onChanged: _saving ? null : _toggleMaster,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: homeLine),
    ),
    child: child,
  );

  Widget _buildCategoriesCard(bool enabled) {
    final brand = BrandingState.instance;
    final allCategories = _prefs.allCategories;
    return _buildCard(
      child: Column(
        children: [
          _ToggleRow(
            key: const ValueKey('pref-all-categories'),
            icon: Icons.apps_rounded,
            title: 'Tüm Haber Kategorileri',
            subtitle:
                'Yeni içerik yayınlandığında tüm kategorilerden bildirim.',
            value: allCategories,
            enabled: enabled,
            onChanged: (v) => _apply(_prefs.copyWith(allCategories: v)),
          ),
          if (!allCategories) ...[
            const Divider(height: 1, color: homeLine),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Takip edilecek kategoriler',
                    style: TextStyle(
                      color: homeMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_categories.isEmpty)
                    const Text(
                      'Kategoriler şu an yüklenemedi.',
                      style: TextStyle(color: homeMuted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in _categories)
                          FilterChip(
                            key: ValueKey('pref-category-${cat.id}'),
                            label: Text(cat.name),
                            selected: _prefs.categoryIds.contains(cat.id),
                            onSelected: enabled
                                ? (sel) => _toggleCategory(cat.id, sel)
                                : null,
                            selectedColor: brand.primaryColor.withValues(
                              alpha: 0.14,
                            ),
                            checkmarkColor: brand.primaryColor,
                            labelStyle: TextStyle(
                              color: _prefs.categoryIds.contains(cat.id)
                                  ? brand.primaryColor
                                  : homeNavy,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: homeLine),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleCategory(String id, bool selected) {
    final current = List<String>.from(_prefs.categoryIds);
    if (selected) {
      if (!current.contains(id)) current.add(id);
    } else {
      current.remove(id);
    }
    _apply(_prefs.copyWith(categoryIds: current));
  }

  Widget _buildLocationCard(bool enabled) {
    final city = HomeCity.resolve(_prefs.locationIds, _provinces);
    final hasCity = _prefs.locationIds.isNotEmpty;
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: homeNavy),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Şehrim',
                        style: TextStyle(
                          color: homeNavy,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasCity
                            ? (city?.label ?? 'Seçili şehir')
                            : 'Henüz şehir seçilmedi',
                        style: const TextStyle(color: homeMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Yerel haber bildirimleri seçtiğiniz şehre göre gönderilir.',
              style: TextStyle(color: homeMuted, height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('pref-change-city'),
                onPressed: enabled ? _changeCity : null,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: Text(hasCity ? 'Şehri Değiştir' : 'Şehir Seç'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: homeNavy,
                  minimumSize: const Size(48, 44),
                  side: const BorderSide(color: homeLine),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursCard(bool enabled) {
    final quiet = _prefs.quietHours;
    return _buildCard(
      child: Column(
        children: [
          _ToggleRow(
            key: const ValueKey('pref-quiet'),
            icon: Icons.nightlight_round,
            title: 'Sessiz Saatler',
            subtitle: 'Belirlediğiniz saatler arasında bildirim gönderilmez.',
            value: quiet.enabled,
            enabled: enabled,
            onChanged: (v) => _apply(
              _prefs.copyWith(
                quietHours: QuietHoursModel(
                  enabled: v,
                  start: quiet.start ?? '22:00',
                  end: quiet.end ?? '07:00',
                ),
              ),
            ),
          ),
          if (quiet.enabled) ...[
            const Divider(height: 1, color: homeLine),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      key: const ValueKey('pref-quiet-start'),
                      label: 'Başlangıç',
                      value: quiet.start ?? '22:00',
                      enabled: enabled,
                      onTap: () => _pickQuietTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      key: const ValueKey('pref-quiet-end'),
                      label: 'Bitiş',
                      value: quiet.end ?? '07:00',
                      enabled: enabled,
                      onTap: () => _pickQuietTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool enabled;
  const _SectionLabel(this.text, {required this.enabled});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: TextStyle(
        color: enabled ? homeNavy : homeMuted,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Icon(icon, color: homeNavy),
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
                    style: const TextStyle(
                      color: homeMuted,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: brand.primaryColor,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xfff2f4f7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: homeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: homeMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: homeNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const Icon(Icons.schedule, size: 18, color: homeMuted),
            ],
          ),
        ],
      ),
    ),
  );
}
