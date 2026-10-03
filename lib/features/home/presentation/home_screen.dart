import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/storage/local_cache_service.dart';
import '../../../data/models/ad_model.dart';
import '../../../data/models/blog_article_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/home_model.dart';
import '../../../data/models/home_view_model.dart';
import '../../../data/models/info_corner_model.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/news_model.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/repositories/news_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../data/state/home_data_state.dart';
import '../../../app/bottom_nav_preferences.dart';
import '../../../design/branding_state.dart';
import '../../../services/ad_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/sync_coordinator.dart';
import 'home_city.dart';
import 'home_widgets.dart';
import 'live_data_widgets.dart';
import '../../blog/presentation/blog_widgets.dart' show BlogImage;
import '../../news/presentation/widgets/news_feed_card.dart';

/// Intent hook for the existing root Navigator. No out-of-scope screens/routes.
enum HomeAction {
  breaking,
  search,
  notifications,
  submitNews,
  selectCity,
  news,
  blog,
  blogIndex,
  ad,
}

typedef HomeActionHandler = void Function(HomeAction action, Object? payload);

class HomeScreen extends StatefulWidget {
  final HomeDataState? homeState;
  final HomeRepository? homeRepository;
  final DeviceRepository? deviceRepository;
  final TaxonomyRepository? taxonomyRepository;
  final NewsRepository? newsRepository;
  final AdService? adService;
  final AnalyticsService? analyticsService;
  final SyncCoordinator? syncCoordinator;
  final HomeActionHandler? onAction;
  final HomeViewModel? initialSlots;
  final bool loadOnStart;

  const HomeScreen({
    super.key,
    this.homeState,
    this.homeRepository,
    this.deviceRepository,
    this.taxonomyRepository,
    this.newsRepository,
    this.adService,
    this.analyticsService,
    this.syncCoordinator,
    this.onAction,
    this.initialSlots,
    this.loadOnStart = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _placement = 'home_after_hero';
  late final HomeDataState _data;
  late final HomeRepository _home;
  late final DeviceRepository _device;
  late final TaxonomyRepository _taxonomy;
  late final NewsRepository _news;
  late final AdService _ads;
  late final AnalyticsService _analytics;
  late final SyncCoordinator _sync;
  final _scroll = ScrollController();
  final _heroPager = PageController();
  final _tickerPager = PageController();
  int _heroPage = 0;
  final _breakingKey = GlobalKey();
  final _cityKey = GlobalKey();
  final _localKey = GlobalKey();
  final _videoKey = GlobalKey();
  final _adKey = GlobalKey();
  final _viewportKey = GlobalKey();
  HomeCity? _city;
  List<NewsModel> _local = const [];
  List<NewsModel> _video = const [];
  MobileAdModel? _ad;
  bool _loading = false;
  bool _homeFailed = false;
  bool _localFailed = false;
  bool _cityFailed = false;
  int _selected = 0;
  int _adGeneration = 0;
  bool _active = true;
  Future<void>? _refreshing;
  Timer? _adTimer;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _data = widget.homeState ?? HomeDataState.instance;
    _home = widget.homeRepository ?? HomeRepository(state: _data);
    _device = widget.deviceRepository ?? DeviceRepository();
    _taxonomy = widget.taxonomyRepository ?? TaxonomyRepository();
    _news = widget.newsRepository ?? NewsRepository();
    _ads = widget.adService ?? AdService();
    _analytics =
        widget.analyticsService ?? AnalyticsService(deviceRepository: _device);
    _sync =
        widget.syncCoordinator ??
        SyncCoordinator(
          homeRepository: _home,
          deviceRepository: _device,
          taxonomyRepository: _taxonomy,
        );
    final slots = widget.initialSlots;
    if (slots != null) {
      _local = slots.local;
      _video = slots.video;
      _ad = slots.ads.isEmpty ? null : slots.ads.first;
      if (slots.city != null) {
        _city = HomeCity(
          location: slots.city!,
          provinceName: slots.city!.name,
          provinceSlug: slots.city!.slug,
        );
      }
    }
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_trackVisibleAd);
    _startTickerTimer();
    if (widget.loadOnStart) {
      unawaited(_refresh());
      _startAdTimer();
    }
  }

  void _startAdTimer() {
    _adTimer?.cancel();
    // Only active-screen ads revalidate; no new cache or background home polling.
    _adTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_loadAd()),
    );
  }

  void _startTickerTimer() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final count =
          (_data.home ?? widget.initialSlots?.home)?.breaking.length ?? 0;
      if (!mounted || count < 2 || !_tickerPager.hasClients) return;
      if (ModalRoute.of(context)?.isCurrent == false ||
          _tickerPager.position.isScrollingNotifier.value) {
        return;
      }
      final next = ((_tickerPager.page ?? 0).round() + 1) % count;
      unawaited(
        _tickerPager.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.loadOnStart) return;
    if (state == AppLifecycleState.resumed) {
      _active = true;
      unawaited(_resume());
      _startAdTimer();
      _startTickerTimer();
    } else {
      _active = false;
      _adTimer?.cancel();
      _tickerTimer?.cancel();
      _adGeneration++;
      if (mounted) setState(() => _ad = null);
    }
  }

  Future<void> _resume() async {
    await Future.wait([_sync.syncOnResume(), _loadCityAndAd()]);
  }

  Future<void> _refresh() {
    if (_refreshing != null) return _refreshing!;
    final future = Future.wait([_loadHome(), _loadCityAndAd()])
        .then<void>((_) {});
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<void> _loadHome() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _homeFailed = false;
      });
    }
    try {
      if (_data.home == null) await _home.getCachedHome();
      await _home.getHome();
    } catch (_) {
      if (mounted) setState(() => _homeFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCityAndAd() async {
    _adGeneration++;
    if (mounted) setState(() => _ad = null);
    // Never show an untargeted ad while a saved location is being resolved.
    await _loadCity();
    if (mounted) await _loadAd();
  }

  Future<void> _loadCity() async {
    try {
      final preferences = await _device.getPreferences();
      if (preferences.locationIds.isEmpty) {
        if (mounted) {
          setState(() {
            _city = null;
            _local = const [];
            _cityFailed = false;
          });
        }
        return;
      }
      // Read the existing taxonomy snapshot for immediate saved-city presentation.
      final cached = await LocalCacheService.instance.get(
        TaxonomyRepository.locationsCacheKey,
      );
      if (cached?.payload is List) {
        final provinces = (cached!.payload as List)
            .whereType<Map<String, dynamic>>()
            .map(LocationProvinceModel.fromJson)
            .toList();
        final city = HomeCity.resolve(preferences.locationIds, provinces);
        if (mounted && city != null) setState(() => _city = city);
      }
      final provinces = await _taxonomy.getLocations();
      final city = HomeCity.resolve(preferences.locationIds, provinces);
      if (!mounted) return;
      setState(() {
        if (_city?.location.id != city?.location.id) _local = const [];
        _city = city;
        _cityFailed = false;
        _localFailed = false;
      });
      if (city != null) {
        try {
          final result = await _news.getLocationNews(
            city.provinceSlug,
            district: city.districtSlug,
            limit: 3,
          );
          if (mounted && _city?.location.id == city.location.id) {
            setState(() => _local = result.news);
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _local = const [];
              _localFailed = true;
            });
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _cityFailed = true);
    }
  }

  Future<void> _loadAd() async {
    if (!mounted || !_active) return;
    final generation = ++_adGeneration;
    if (mounted) setState(() => _ad = null);
    final ad = await _ads.getTopAd(
      placement: _placement,
      locationId: _city?.location.id,
    );
    if (!mounted || !_active || generation != _adGeneration) return;
    setState(() => _ad = ad);
  }

  void _trackVisibleAd() {
    if (!mounted || _ad == null || !widget.loadOnStart) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final box = _adKey.currentContext?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.hasSize ||
        !viewport.hasSize) {
      return;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
    if (!rect.overlaps(visible)) return;
    unawaited(
      _analytics.trackAdImpression(
        campaignId: _ad!.campaignId,
        placementId: _placement,
        newsId: _ad!.newsId,
        locationId: _city?.location.id,
      ),
    );
  }

  void _action(HomeAction action, [Object? payload]) {
    if (widget.onAction != null) {
      widget.onAction!(action, payload);
      return;
    }
    final label = switch (action) {
      HomeAction.breaking => 'Son Dakika',
      HomeAction.search => 'Arama',
      HomeAction.notifications => 'Bildirimler',
      HomeAction.submitNews => 'Haber gönderme',
      HomeAction.selectCity => 'Şehir seçimi',
      HomeAction.news => 'Haber detayı',
      HomeAction.blog => 'Yazı detayı',
      HomeAction.blogIndex => 'Bilgi Köşesi',
      HomeAction.ad => 'Reklam hedefi',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label ekranı şu an açılamıyor.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _anchor(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          alignment: .03,
        ),
      );
    }
  }

  Future<void> _openCity() async {
    await Navigator.of(context).pushNamed('/sehrim');
    if (mounted) unawaited(_refresh());
  }

  void _navigate(int index) {
    if (index == 3 || index == 4) {
      // Slot 4-5 kullanıcı tercihidir (Alt Menü Düzeni); Şehrim dönüşte Home'u tazeler.
      final target = BottomNavPreferences.instance.destinationAt(index);
      if (target == NavDestination.city) {
        _openCity();
      } else {
        Navigator.of(context).pushNamed(target.route);
      }
      return;
    }
    if (index == 1 && widget.onAction != null) {
      _action(HomeAction.breaking);
      return;
    }
    if (index == 2) {
      _action(HomeAction.submitNews);
      return;
    }
    setState(() => _selected = index);
    switch (index) {
      case 0:
        unawaited(
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          ),
        );
      case 1:
        _anchor(_breakingKey);
      case 3:
        _openCity();
      case 4:
        Navigator.of(context).pushNamed('/videolar');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adTimer?.cancel();
    _tickerTimer?.cancel();
    _adGeneration++;
    _scroll.dispose();
    _heroPager.dispose();
    _tickerPager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_data, BrandingState.instance]),
    builder: (context, _) {
      final brand = BrandingState.instance;
      final home = _data.home ?? widget.initialSlots?.home ?? const HomeModel();
      final theme = homeTheme(brand);
      WidgetsBinding.instance.addPostFrameCallback((_) => _trackVisibleAd());
      return Theme(
        data: theme,
        child: Scaffold(
          appBar: _header(brand),
          bottomNavigationBar: HomeBottomBar(
            selected: _selected,
            onSelect: _navigate,
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: RefreshIndicator(
              color: brand.primaryColor,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                key: _viewportKey,
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ticker(home.breaking, brand.primaryColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _categoryShortcuts(home),
                              if (_loading && _data.home == null)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              if (_homeFailed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: HomeMessage(
                                    _data.home == null
                                        ? 'Haberlere ulaşılamadı. Yenilemek için aşağı çekin.'
                                        : 'Güncelleme yapılamadı. Son kaydedilen haberler gösteriliyor.',
                                  ),
                                ),
                              _hero(home),
                              const SizedBox(height: 12),
                              _citySummary(brand.primaryColor),
                              if (_city != null)
                                HomeSection(
                                  key: _localKey,
                                  title:
                                      '${_city!.location.name}’den Son Haberler',
                                  child: _local.isEmpty
                                      ? HomeMessage(
                                          _localFailed
                                              ? 'Yerel haberlere şu anda ulaşılamıyor.'
                                              : 'Henüz yerel haber bulunmuyor.',
                                        )
                                      : _miniNews(_local.take(3).toList()),
                                ),
                              if (_ad != null) _adSlot(_ad!),
                              if (home.liveModules != null)
                                HomeMarketSection(
                                  market: home.liveModules!.market,
                                ),
                              if (home.infoCorner != null &&
                                  home.infoCorner!.title.trim().isNotEmpty)
                                _infoCorner(home.infoCorner!),
                              if (home.liveModules != null)
                                HomeEarthquakeSection(
                                  module: home.liveModules!.earthquake,
                                ),
                              HomeSection(
                                key: const ValueKey('home-current'),
                                title: 'Güncel Haberler',
                                actionLabel: 'Tümünü Gör',
                                onAction: () =>
                                    Navigator.of(context)
                                        .pushNamed('/guncel-haberler'),
                                child: home.latest.isEmpty
                                    ? const HomeMessage(
                                        'Henüz güncel haber bulunmuyor.',
                                      )
                                    : _newsGrid(home.latest.take(4)),
                              ),
                              // Video kategorisi AŞAĞIDAKİ ayrı "Video Haberler"
                              // bölümünde (_videos) sunulur; burada tekrar
                              // çizilirse aynı içerik iki kez görünür.
                              for (final section in home.categorySections.where(
                                (section) => !_isVideo(section),
                              ))
                                HomeSection(
                                  key: ValueKey(
                                    'home-category-${section.category.id}',
                                  ),
                                  title: section.category.name,
                                  actionLabel: 'Tümünü Gör',
                                  onAction: () => Navigator.of(context)
                                      .pushNamed(
                                        '/haber-kategorileri',
                                        arguments: section.category,
                                      ),
                                  child: section.news.isEmpty
                                      ? const HomeMessage(
                                          'Henüz yayınlanmış haber bulunmuyor.',
                                        )
                                      : _newsGrid(section.news.take(5)),
                                ),
                              _videos(home),
                              if (home.featured.isNotEmpty)
                                HomeSection(
                                  title: 'Öne Çıkan Haberler',
                                  actionLabel: 'Tümünü Gör',
                                  onAction: () =>
                                      Navigator.of(context)
                                          .pushNamed('/one-cikan-haberler'),
                                  child: _newsGrid(home.featured.take(4)),
                                ),
                              if (home.mostRead.isNotEmpty)
                                HomeSection(
                                  title: 'Çok Okunanlar',
                                  actionLabel: 'Tümünü Gör',
                                  onAction: () =>
                                      Navigator.of(context)
                                          .pushNamed('/cok-okunanlar'),
                                  child: _newsGrid(home.mostRead.take(4)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  PreferredSizeWidget _header(BrandingState brand) => HomeBrandHeader(
    brand: brand,
    onSearch: () => _action(HomeAction.search),
    onNotifications: () => _action(HomeAction.notifications),
  );

  Widget _ticker(List<NewsModel> breaking, Color red) => Padding(
    key: _breakingKey,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: homeNavy,
        height: MediaQuery.textScalerOf(context).scale(12) + 36,
        child: Row(
          children: [
            Container(
              color: red,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: const Text(
                'ϟ SON DAKİKA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: breaking.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Yeni gelişmeler burada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    )
                  : PageView.builder(
                      controller: _tickerPager,
                      itemCount: breaking.length,
                      itemBuilder: (context, index) {
                        final item = breaking[index];
                        return Semantics(
                          label: 'Son dakika: ${item.title}',
                          child: InkWell(
                            onTap: () => _action(HomeAction.news, item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _categoryShortcuts(HomeModel home) {
    final categories = <String, CategoryModel>{};
    for (final section in home.categorySections) {
      categories[section.category.slug] = section.category;
    }
    for (final news in [
      ...home.hero,
      ...home.latest,
      ...home.featured,
      ...home.breaking,
    ]) {
      final category = news.primaryCategory;
      if (category != null && category.slug.isNotEmpty) {
        categories.putIfAbsent(
          category.slug,
          () => CategoryModel(
            id: category.id,
            name: category.name,
            slug: category.slug,
          ),
        );
      }
    }
    if (categories.isEmpty) return const SizedBox.shrink();
    final items = categories.values.toList();
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 50 + scaler.scale(11) * 2.6,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final category = i < items.length ? items[i] : null;
            final active = i == 0;
            final color = active
                ? Theme.of(context).colorScheme.primary
                : homeNavy;
            final icon = switch (category?.slug) {
              'ekonomi' => Icons.bar_chart_rounded,
              'spor' => Icons.sports_soccer_rounded,
              'teknoloji' => Icons.memory_rounded,
              'yasam' => Icons.eco_outlined,
              null => Icons.format_list_bulleted_rounded,
              _ => Icons.newspaper_rounded,
            };
            return SizedBox(
              width: 84,
              child: Material(
                color: active ? color.withAlpha(18) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => category == null
                      ? Navigator.of(context).pushNamed('/tum-kategoriler')
                      : Navigator.of(
                          context,
                        ).pushNamed('/haber-kategorileri', arguments: category),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 26),
                        const SizedBox(height: 4),
                        Text(
                          category?.name ?? 'Tüm Kategoriler',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _citySummary(Color red) => Material(
    key: _cityKey,
    color: homeNavy,
    clipBehavior: Clip.antiAlias,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: _openCity,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 20, color: red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _city?.label ?? 'Şehrini seç',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _cityFailed
                  ? 'Şehir bilgisi şu anda güncellenemiyor.'
                  : _city == null
                  ? 'Yerel gündemi sana yaklaştıralım.'
                  : _local.isEmpty
                  ? 'Yerel gündeme göz at.'
                  : '${_local.length} son haber · Yerel gündeme göz at',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Şehrimde Neler Var?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
            if (_city != null &&
                _data.home?.liveModules?.weather.locationId ==
                    _city!.location.id)
              WeatherSummary(weather: _data.home!.liveModules!.weather),
          ],
        ),
      ),
    ),
  );

  Widget _hero(HomeModel home) {
    final items = home.hero.isNotEmpty
        ? home.hero
        : home.featured.isNotEmpty
        ? home.featured
        : home.latest;
    if (items.isEmpty) return const SizedBox.shrink();
    final page = _heroPage.clamp(0, items.length - 1);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth / 1.62).clamp(280.0, 400.0) +
            (scaler.scale(23) - 23) * 5.8 +
            (scaler.scale(12) - 12) * 4;
        return SizedBox(
          key: const ValueKey('home-hero'),
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _heroPager,
                itemCount: items.length,
                onPageChanged: (value) => setState(() => _heroPage = value),
                itemBuilder: (context, index) {
                  final news = items[index];
                  return HomeArticleCard(
                    title: news.title,
                    summary: news.summary,
                    coverUrl: news.coverUrl,
                    category: news.primaryCategory?.name,
                    date: news.publishedAt,
                    readingTime: news.readingTime,
                    style: HomeCardStyle.hero,
                    onTap: () => _action(HomeAction.news, news),
                  );
                },
              ),
              if (items.length > 1) ...[
                Positioned(
                  right: 4,
                  bottom: 44,
                  child: IconButton(
                    key: const ValueKey('home-hero-next'),
                    tooltip: 'Sonraki manşet',
                    style: IconButton.styleFrom(
                      backgroundColor: homeNavy.withAlpha(220),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _heroPager.animateToPage(
                      (page + 1) % items.length,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Semantics(
                          label: 'Manşet ${i + 1} / ${items.length}',
                          selected: i == page,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == page ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == page
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _miniNews(List<NewsModel> items) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 16) / 3;
      final scale = MediaQuery.textScalerOf(context);
      return SizedBox(
        height:
            width / 1.5 + scale.scale(12) * 4.2 + scale.scale(10) * 3.5 + 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => SizedBox(
            width: width,
            child: HomeArticleCard(
              title: items[i].title,
              coverUrl: items[i].coverUrl,
              date: items[i].publishedAt,
              style: HomeCardStyle.mini,
              onTap: () => _action(HomeAction.news, items[i]),
            ),
          ),
        ),
      );
    },
  );
  Widget _newsCard(NewsModel news, {bool compact = true, bool video = false}) =>
      HomeArticleCard(
        title: news.title,
        summary: news.summary,
        coverUrl: news.coverUrl,
        category: news.primaryCategory?.name,
        date: news.publishedAt,
        readingTime: news.readingTime,
        compact: compact,
        video: video,
        onTap: () => _action(HomeAction.news, news),
      );

  Widget _newsGrid(Iterable<NewsModel> items) {
    final values = items.toList();
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 2,
          mainAxisExtent: compactNewsGridHeight(
            context,
            (constraints.maxWidth - 10) / 2,
          ),
        ),
        itemCount: values.length,
        itemBuilder: (_, index) {
          final news = values[index];
          return CompactNewsGridCard(
            news: news,
            onTap: () => _action(HomeAction.news, news),
          );
        },
      ),
    );
  }

  Widget _infoCorner(InfoCornerModel info) {
    final seen = <String>{};
    final articles = <BlogArticleModel>[];
    for (final article in [...info.featured, ...info.latest]) {
      final identity = article.id.isNotEmpty
          ? article.id
          : article.slug.isNotEmpty
          ? article.slug
          : article.title;
      if (article.title.trim().isNotEmpty && seen.add(identity)) {
        articles.add(article);
        if (articles.length == 4) break;
      }
    }
    final scale = MediaQuery.textScalerOf(context);
    return Container(
      key: const ValueKey('home-info-corner'),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: homeNavy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => _action(HomeAction.blogIndex, info),
                child: const Text(
                  'Tümünü Gör →',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (articles.isEmpty)
            const HomeMessage('Henüz yayınlanmış yazı bulunmuyor.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth * .48).clamp(150.0, 210.0);
                return SizedBox(
                  height:
                      208 +
                      (scale.scale(14) - 14) * 4 +
                      (scale.scale(10) - 10) * 2,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final article = articles[i];
                      final color = switch (article.category?.slug) {
                        'teknoloji-dijital-yasam' => const Color(0xff0284c7),
                        'saglik-yasam' => const Color(0xff059669),
                        'gezi-kesif' => const Color(0xff0284c7),
                        _ => Theme.of(context).colorScheme.primary,
                      };
                      return SizedBox(
                        width: width,
                        child: HomeArticleCard(
                          key: ValueKey('home-blog-$i'),
                          title: article.title,
                          coverUrl: article.coverUrl,
                          cover: BlogImage(url: article.coverUrl),
                          category:
                              article.subcategory?.name ??
                              article.category?.name,
                          style: HomeCardStyle.editorial,
                          badgeColor: color,
                          onTap: () => _action(HomeAction.blog, article),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  bool _isVideo(HomeCategorySectionModel section) =>
      section.category.slug == 'video' ||
      section.category.slug == 'video-haberler';

  Widget _videos(HomeModel home) {
    final items = _video.isNotEmpty
        ? _video
        : home.categorySections.where(_isVideo).expand((s) => s.news).toList();
    if (items.isEmpty) return SizedBox(key: _videoKey);
    return HomeSection(
      key: _videoKey,
      title: 'Video Haberler',
      child: items.isEmpty
          ? const HomeMessage(
              'Henüz video haber bulunmuyor.',
              icon: Icons.play_circle_outline,
            )
          : Column(
              children: [
                for (final news in items.take(4))
                  _newsCard(news, compact: false, video: true),
              ],
            ),
    );
  }

  Widget _adSlot(MobileAdModel ad) => Padding(
    key: _adKey,
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'REKLAM',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: homeMuted, letterSpacing: 1.4),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: homeLine),
          ),
          child: InkWell(
            onTap: () {
              unawaited(
                _analytics.trackAdClick(
                  campaignId: ad.campaignId,
                  placementId: _placement,
                  newsId: ad.newsId,
                  locationId: _city?.location.id,
                ),
              );
              _action(HomeAction.ad, ad);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((ad.effectiveImageUrl ?? '').isNotEmpty)
                  AspectRatio(
                    aspectRatio: 4,
                    child: HomeCover(
                      url: ad.effectiveImageUrl,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.advertiserName,
                        style: const TextStyle(fontSize: 10, color: homeMuted),
                      ),
                      if (ad.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            ad.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: homeNavy,
                            ),
                          ),
                        ),
                      if ((ad.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            ad.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: homeMuted,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        ad.ctaText,
                        style: TextStyle(
                          fontSize: 12,
                          color: BrandingState.instance.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
