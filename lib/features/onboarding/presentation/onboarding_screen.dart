import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/notification_preference_model.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../design/branding_state.dart';
import '../../../services/notification_permission_service.dart';
import '../../home/presentation/home_city.dart';
import '../../home/presentation/home_widgets.dart';
import '../../settings/presentation/personalization_widgets.dart';

/// İlk kurulum onboarding akışı (yalnız ilk açılışta gösterilir).
///
/// 1. Hoş Geldin  2. Şehrini Seç  3. İlgi Alanlarını Seç
/// 4. Bildirimlerini Ayarla  5. Başla
///
/// Tüm seçimler mevcut cihaz tercihlerine (tek canonical state) yazılır:
/// şehir → location_ids, ilgi alanları → category_ids, bildirimler →
/// notifications_enabled / breaking_news / quiet_hours. Bildirim izni yalnız
/// kullanıcı bildirimleri açmak istediğinde istenir.
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onFinished;
  final DeviceRepository? device;
  final TaxonomyRepository? taxonomy;
  final NotificationPermissionService? permission;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.device,
    this.taxonomy,
    this.permission,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _device = widget.device ?? DeviceRepository();
  late final _taxonomy = widget.taxonomy ?? TaxonomyRepository();
  late final _permission = widget.permission ?? NotificationPermissionService();

  static const _steps = 5;
  final _pager = PageController();
  int _step = 0;
  bool _finishing = false;

  NotificationPreferenceModel _prefs = const NotificationPreferenceModel();

  // Şehir
  List<LocationProvinceModel> _provinces = const [];
  LocationProvinceModel? _province;
  bool _citiesLoading = true;
  bool _citiesFailed = false;
  final _cityQuery = TextEditingController();

  // İlgi alanları
  List<CategoryModel> _categories = const [];
  bool _categoriesLoading = true;
  bool _categoriesFailed = false;

  // Bildirim izni
  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notApplicable;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pager.dispose();
    _cityQuery.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await _device.getPreferences();
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {}
    unawaited(_loadCities());
    unawaited(_loadCategories());
    final status = await _permission.status();
    if (mounted) setState(() => _permissionStatus = status);
  }

  Future<void> _loadCities() async {
    setState(() {
      _citiesLoading = true;
      _citiesFailed = false;
    });
    try {
      final provinces = await _taxonomy.getLocationsResilient();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _citiesFailed = provinces.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _citiesFailed = true);
    } finally {
      if (mounted) setState(() => _citiesLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categoriesLoading = true;
      _categoriesFailed = false;
    });
    try {
      final all = await _taxonomy.getCategories();
      if (!mounted) return;
      setState(() => _categories = mainNewsCategories(all));
    } catch (_) {
      if (mounted) setState(() => _categoriesFailed = true);
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _save(NotificationPreferenceModel next) async {
    setState(() => _prefs = next);
    try {
      await _device.updatePreferences(next);
    } catch (_) {
      // Offline-first: yerelde saklanır, SyncCoordinator sonra eşler.
    }
  }

  Future<void> _selectCity(String id) async {
    await _save(_prefs.copyWith(locationIds: [id], allLocations: false));
    _next();
  }

  void _toggleInterest(String id, bool selected) {
    final ids = List<String>.from(_prefs.categoryIds);
    if (selected) {
      if (!ids.contains(id)) ids.add(id);
    } else {
      ids.remove(id);
    }
    unawaited(_save(_prefs.copyWith(categoryIds: ids)));
  }

  Future<void> _setNotifications(bool enabled) async {
    if (enabled) {
      // Kullanıcı açmak istediğinde izin istenir (açılışta değil).
      final status = await _permission.request();
      if (mounted) setState(() => _permissionStatus = status);
    }
    await _save(_prefs.copyWith(notificationsEnabled: enabled));
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pager.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_step < _steps - 1) _goTo(_step + 1);
  }

  void _back() {
    if (_step == 1 && _province != null) {
      setState(() {
        _province = null;
        _cityQuery.clear();
      });
      return;
    }
    if (_step > 0) _goTo(_step - 1);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    // Cihazı gerçek backend'e kaydet (best-effort; offline'da yerel kalır).
    unawaited(
      _device
          .registerDevice(appVersion: AppConfig.appVersion, locale: 'tr_TR')
          .then<void>((_) {})
          .catchError((Object _) {}),
    );
    await widget.onFinished();
    if (mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Theme(
      data: homeTheme(brand),
      child: PopScope(
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: _step == 0 ? homeNavy : homeBackground,
          body: SafeArea(
            child: Column(
              children: [
                if (_step > 0)
                  _TopBar(step: _step, total: _steps, onBack: _back),
                Expanded(
                  child: PageView(
                    controller: _pager,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _WelcomeStep(onStart: _next),
                      _buildCityStep(brand),
                      _buildInterestsStep(),
                      _buildNotificationsStep(brand),
                      _buildFinishStep(brand),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Şehir
  Widget _buildCityStep(BrandingState brand) {
    final selected = HomeCity.resolve(_prefs.locationIds, _provinces);
    final q = _cityQuery.text.trim().toLowerCase();
    final province = _province;
    final rows = province == null
        ? _provinces
              .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
              .map((p) => (id: p.id, name: p.name, province: p))
              .toList()
        : province.districts
              .where((d) => q.isEmpty || d.name.toLowerCase().contains(q))
              .map((d) => (id: d.id, name: d.name, province: province))
              .toList();

    return _StepScaffold(
      title: province?.name ?? 'Şehrini Seç',
      subtitle: province == null
          ? 'Hava durumu, namaz vakitleri ve yerel haberler seçtiğin şehre göre gelir.'
          : 'İlçeni seçebilir veya il geneliyle devam edebilirsin.',
      primaryLabel: selected != null ? 'Devam' : null,
      onPrimary: selected != null ? _next : null,
      onSkip: _next,
      child: _citiesLoading
          ? const _LoadingNote('Bölgeler yükleniyor…')
          : _citiesFailed
          ? _RetryNote(
              message: 'Bölgeler şu an yüklenemedi. Bağlantını kontrol edip tekrar dene ya da bu adımı daha sonra Şehrim’den tamamla.',
              onRetry: _loadCities,
            )
          : Column(
              children: [
                if (selected != null && province == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PrefCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: brand.primaryColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Seçili: ${selected.label}',
                              style: const TextStyle(
                                color: homeNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                TextField(
                  key: const ValueKey('onboarding-city-search'),
                  controller: _cityQuery,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: province == null ? 'İl ara' : 'İlçe ara',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: homeLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: homeLine),
                    ),
                  ),
                ),
                if (province != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('onboarding-city-province'),
                      style: FilledButton.styleFrom(
                        backgroundColor: homeNavy,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _selectCity(province.id),
                      child: Text('${province.name} geneliyle devam et'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _prefs.locationIds.contains(row.id)
                              ? brand.primaryColor
                              : homeLine,
                        ),
                      ),
                      child: ListTile(
                        key: ValueKey('onboarding-location-${row.id}'),
                        minTileHeight: 52,
                        title: Text(
                          row.name,
                          style: const TextStyle(
                            color: homeNavy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (province == null) {
                            if (row.province.districts.isEmpty) {
                              _selectCity(row.id);
                            } else {
                              setState(() {
                                _province = row.province;
                                _cityQuery.clear();
                              });
                            }
                          } else {
                            _selectCity(row.id);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------- İlgi Alanları
  Widget _buildInterestsStep() {
    return _StepScaffold(
      title: 'İlgi Alanlarını Seç',
      subtitle: 'Takip etmek istediğin haber kategorilerini seç. Kategori bildirimlerinde de kullanılır.',
      primaryLabel: 'Devam',
      onPrimary: _next,
      onSkip: _next,
      child: _categoriesLoading
          ? const _LoadingNote('Kategoriler yükleniyor…')
          : _categoriesFailed || _categories.isEmpty
          ? _RetryNote(
              message: 'Kategoriler şu an yüklenemedi. Daha sonra Tercihler’den seçebilirsin.',
              onRetry: _loadCategories,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterestChips(
                  categories: _categories,
                  selectedIds: _prefs.categoryIds,
                  onToggle: _toggleInterest,
                ),
                const SizedBox(height: 14),
                Text(
                  _prefs.categoryIds.isEmpty
                      ? 'Henüz seçim yapılmadı.'
                      : '${_prefs.categoryIds.length} kategori seçildi.',
                  style: const TextStyle(color: homeMuted, fontSize: 13),
                ),
              ],
            ),
    );
  }

  // ------------------------------------------------------------ Bildirimler
  Widget _buildNotificationsStep(BrandingState brand) {
    final enabled = _prefs.notificationsEnabled;
    final needsPermission =
        enabled &&
        (_permissionStatus == NotificationPermissionStatus.denied ||
            _permissionStatus ==
                NotificationPermissionStatus.permanentlyDenied);
    final quiet = _prefs.quietHours;
    final city = HomeCity.resolve(_prefs.locationIds, _provinces);

    return _StepScaffold(
      title: 'Bildirimlerini Ayarla',
      subtitle: 'Neyi, ne zaman alacağına sen karar ver.',
      primaryLabel: 'Devam',
      onPrimary: _next,
      child: Column(
        children: [
          PrefCard(
            child: Column(
              children: [
                _SwitchRow(
                  key: const ValueKey('onboarding-notify-master'),
                  icon: Icons.notifications_active_outlined,
                  title: 'Bildirimler',
                  subtitle: enabled ? 'Açık' : 'Kapalı',
                  value: enabled,
                  onChanged: _setNotifications,
                ),
                if (needsPermission) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      key: const ValueKey('onboarding-permission'),
                      // Yüksek kontrast: koyu lacivert zemin + beyaz yazı
                      // (uygulamanın birincil buton diliyle uyumlu).
                      style: FilledButton.styleFrom(
                        backgroundColor: homeNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (_permissionStatus ==
                            NotificationPermissionStatus.permanentlyDenied) {
                          await _permission.openSettings();
                          final s = await _permission.status();
                          if (mounted) setState(() => _permissionStatus = s);
                        } else {
                          final s = await _permission.request();
                          if (mounted) setState(() => _permissionStatus = s);
                        }
                      },
                      child: Text(
                        _permissionStatus ==
                                NotificationPermissionStatus.permanentlyDenied
                            ? 'Ayarları Aç'
                            : 'Bildirim İzni Ver',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: enabled ? 1 : .5,
            child: PrefCard(
              child: Column(
                children: [
                  _SwitchRow(
                    key: const ValueKey('onboarding-notify-breaking'),
                    icon: Icons.bolt_rounded,
                    title: 'Son Dakika',
                    subtitle: 'Önemli gelişmeler anında',
                    value: _prefs.breakingNews,
                    onChanged: enabled
                        ? (v) => _save(_prefs.copyWith(breakingNews: v))
                        : null,
                  ),
                  const Divider(height: 20, color: homeLine),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    title: 'Yerel Haberler',
                    subtitle: city != null
                        ? '${city.label} için yerel bildirimler'
                        : 'Şehir seçince yerel bildirimler açılır',
                  ),
                  const Divider(height: 20, color: homeLine),
                  _SwitchRow(
                    key: const ValueKey('onboarding-notify-quiet'),
                    icon: Icons.nightlight_round,
                    title: 'Sessiz Saatler',
                    subtitle: quiet.enabled
                        ? '${quiet.start ?? '22:00'} – ${quiet.end ?? '07:00'} arası sessiz'
                        : 'Gece bildirim gönderilmez (22:00 – 07:00)',
                    value: quiet.enabled,
                    onChanged: enabled
                        ? (v) => _save(
                            _prefs.copyWith(
                              quietHours: QuietHoursModel(
                                enabled: v,
                                start: quiet.start ?? '22:00',
                                end: quiet.end ?? '07:00',
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Başla
  Widget _buildFinishStep(BrandingState brand) {
    final city = HomeCity.resolve(_prefs.locationIds, _provinces);
    return _StepScaffold(
      title: 'Hazırsın!',
      subtitle: 'Tercihlerini istediğin zaman Tercihler ekranından değiştirebilirsin.',
      primaryLabel: _finishing ? 'Açılıyor…' : 'GüncelGündem’e Başla',
      onPrimary: _finishing ? null : _finish,
      child: Column(
        children: [
          Image.asset('assets/brand/emblem.png', width: 112, height: 112),
          const SizedBox(height: 18),
          PrefCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Şehrim',
                  subtitle: city?.label ?? 'Seçilmedi',
                ),
                const Divider(height: 20, color: homeLine),
                _InfoRow(
                  icon: Icons.interests_outlined,
                  title: 'İlgi Alanları',
                  subtitle: _prefs.categoryIds.isEmpty
                      ? 'Seçilmedi'
                      : '${_prefs.categoryIds.length} kategori',
                ),
                const Divider(height: 20, color: homeLine),
                _InfoRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Bildirimler',
                  subtitle: _prefs.notificationsEnabled ? 'Açık' : 'Kapalı',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomeStep({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff0b1423), homeNavy, Color(0xff2a0d14)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: brand.primaryColor.withValues(alpha: .35),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/brand/emblem_disc.png',
                        width: 128,
                        height: 128,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '${brand.siteName}’e Hoş Geldin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Daha geniş bir bakış.',
                      style: TextStyle(color: Color(0xffc7d2e0), fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    const _Feature(
                      icon: Icons.bolt_rounded,
                      text: 'Son dakika gelişmeleri anında',
                    ),
                    const _Feature(
                      icon: Icons.location_city_rounded,
                      text: 'Şehrine özel haber, hava ve namaz vakitleri',
                    ),
                    const _Feature(
                      icon: Icons.menu_book_rounded,
                      text: 'Bilgi Köşesi’nde rehber içerikler',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('onboarding-start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: brand.primaryColor,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onStart,
                    child: const Text(
                      'Başlayalım',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _TopBar extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback onBack;
  const _TopBar({
    required this.step,
    required this.total,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Geri',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: homeNavy),
          ),
          Expanded(
            child: Row(
              children: List.generate(
                total - 1,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i < step ? brand.primaryColor : homeLine,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$step/${total - 1}',
            style: const TextStyle(
              color: homeMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSkip;

  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.primaryLabel,
    this.onPrimary,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: homeNavy,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: homeMuted, height: 1.45),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: homeLine)),
          ),
          child: Row(
            children: [
              if (onSkip != null)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(foregroundColor: homeMuted),
                  child: const Text('Şimdilik geç'),
                ),
              const Spacer(),
              if (primaryLabel != null)
                FilledButton(
                  key: ValueKey('onboarding-primary-$title'),
                  style: FilledButton.styleFrom(
                    backgroundColor: brand.primaryColor,
                    minimumSize: const Size(140, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onPrimary,
                  child: Text(
                    primaryLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
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
            Text(
              subtitle,
              style: const TextStyle(color: homeMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
      Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: BrandingState.instance.primaryColor,
        onChanged: onChanged,
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
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
            Text(
              subtitle,
              style: const TextStyle(color: homeMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LoadingNote extends StatelessWidget {
  final String text;
  const _LoadingNote(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(text, style: const TextStyle(color: homeMuted)),
      ],
    ),
  );
}

class _RetryNote extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RetryNote({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => PrefCard(
    child: Column(
      children: [
        const Icon(Icons.wifi_off_rounded, color: homeMuted, size: 32),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: homeMuted, height: 1.45),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tekrar Dene'),
          style: OutlinedButton.styleFrom(foregroundColor: homeNavy),
        ),
      ],
    ),
  );
}
