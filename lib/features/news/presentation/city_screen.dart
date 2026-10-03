import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/bottom_nav_preferences.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/news_model.dart';
import '../../../data/repositories/device_repository.dart';
import '../../../data/repositories/news_repository.dart';
import '../../../data/repositories/taxonomy_repository.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../design/branding_state.dart';
import '../../home/presentation/home_city.dart';
import '../../home/presentation/home_widgets.dart';
import '../../home/presentation/live_data_widgets.dart';
import 'news_navigation.dart';
import 'widgets/news_feed_card.dart';

class CityScreen extends StatefulWidget {
  final DeviceRepository? device;
  final TaxonomyRepository? taxonomy;
  final NewsRepository? news;
  final HomeRepository? home;
  const CityScreen({
    super.key,
    this.device,
    this.taxonomy,
    this.news,
    this.home,
  });
  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  late final _device = widget.device ?? DeviceRepository();
  late final _taxonomy = widget.taxonomy ?? TaxonomyRepository();
  late final _news = widget.news ?? NewsRepository();
  late final _home = widget.home ?? HomeRepository();
  final _query = TextEditingController();
  List<LocationProvinceModel> _provinces = const [];
  LocationProvinceModel? _province;
  HomeCity? _city;
  final List<NewsModel> _items = [];
  bool _loading = true,
      _saving = false,
      _choosing = true,
      _error = false,
      _loadingNews = false,
      _hasMore = false,
      _newsError = false;
  int _page = 0, _generation = 0;
  @override
  void initState() {
    super.initState();
    _home.homeState.addListener(_weatherChanged);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    _home.homeState.removeListener(_weatherChanged);
    super.dispose();
  }

  // Eski (yavaş) yükleme yanıtlarının yeni seçimi ezmesini engeller.
  int _loadGeneration = 0, _selectionVersion = 0;

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final selectionAtStart = _selectionVersion;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      // Geçici yavaşlıkta tek denemede hata göstermez; önce yeniden dener.
      final provinces = await _taxonomy.getLocationsResilient();
      final prefs = await _device.getPreferences();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _provinces = provinces;
        if (selectionAtStart == _selectionVersion) {
          _city = HomeCity.resolve(prefs.locationIds, provinces);
          _choosing = _city == null;
        }
        _error = provinces.isEmpty;
        _loading = false;
      });
      // Haber/hava kendi yükleme göstergeleriyle arka planda tazelenir;
      // şehir ekranı bunları beklerken tam ekran spinner'da kalmaz.
      if (_city != null) unawaited(_refreshCity());
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save(String id) async {
    if (_saving) return;
    _selectionVersion++;
    setState(() => _saving = true);
    try {
      final prefs = await _device.getPreferences();
      await _device.updatePreferences(
        prefs.copyWith(locationIds: [id], allLocations: false),
      );
      if (!mounted) return;
      setState(() {
        _city = HomeCity.resolve([id], _provinces);
        _choosing = false;
      });
      await _refreshCity(forceWeather: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şehir tercihi kaydedilemedi. Tekrar deneyin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadNews({bool reset = false}) async {
    if (_city == null || _loadingNews && !reset) return;
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : _page + 1;
    final city = _city!;
    setState(() {
      _loadingNews = true;
      _newsError = false;
      if (reset) {
        _items.clear();
        _page = 0;
        _hasMore = false;
      }
    });
    try {
      final result = await _news.getLocationNews(
        city.provinceSlug,
        district: city.districtSlug,
        page: page,
        limit: 16,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _items
            .map((item) => item.id.isNotEmpty ? item.id : item.slug)
            .toSet();
        _items.addAll(
          result.news.where(
            (item) => seen.add(item.id.isNotEmpty ? item.id : item.slug),
          ),
        );
        _page = page;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _newsError = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingNews = false);
      }
    }
  }

  void _weatherChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshCity({bool forceWeather = false}) async {
    final city = _city;
    if (city == null) return;
    await Future.wait([
      _loadNews(reset: true),
      _home
          .getWeatherForLocation(city.location.id, forceRefresh: forceWeather)
          .then<void>((_) {})
          .catchError((Object _) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandingState.instance;
    final q = _query.text.trim().toLowerCase();
    final provinces = _provinces
        .where((item) => q.isEmpty || item.name.toLowerCase().contains(q))
        .toList();
    final districts = (_province?.districts ?? const <LocationDistrictModel>[])
        .where((item) => q.isEmpty || item.name.toLowerCase().contains(q))
        .toList();
    return Theme(
      data: homeTheme(brand),
      child: Scaffold(
        appBar: HomeBrandHeader(
          brand: brand,
          allowBack: true,
          onSearch: () => NewsNavigation.openSearch(context),
          onNotifications: () => NewsNavigation.openNotifications(context),
        ),
        bottomNavigationBar: HomeBottomBar(
          selected: BottomNavPreferences.instance.indexOf(NavDestination.city),
          onSelect: (index) {
            if (index !=
                BottomNavPreferences.instance.indexOf(NavDestination.city)) {
              NewsNavigation.handleBottom(context, index);
            }
          },
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HomeMessage(
                        'Bölgeler şu an yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _choosing
              ? CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _province?.name ?? 'Şehir Seç',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: homeNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _province == null
                                  ? 'Yerel gündemi takip etmek için ilini seç.'
                                  : 'İlçe seçebilir veya şehir düzeyinde devam edebilirsin.',
                              style: const TextStyle(
                                color: homeMuted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _query,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: _province == null
                                    ? 'İl ara'
                                    : 'İlçe ara',
                                filled: true,
                                fillColor: Colors.white,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            if (_province != null) ...[
                              const SizedBox(height: 12),
                              FilledButton(
                                key: const ValueKey('city-save-province'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _saving
                                    ? null
                                    : () => _save(_province!.id),
                                child: Text('${_province!.name} ile devam et'),
                              ),
                              TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => setState(() {
                                        _province = null;
                                        _query.clear();
                                      }),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('İl seçimine dön'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: _province == null
                          ? provinces.length
                          : districts.length,
                      itemBuilder: (_, index) {
                        final name = _province == null
                            ? provinces[index].name
                            : districts[index].name;
                        final id = _province == null
                            ? provinces[index].id
                            : districts[index].id;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: homeLine),
                            ),
                            child: ListTile(
                              key: ValueKey(
                                '${_province == null ? 'province' : 'district'}-$id',
                              ),
                              minTileHeight: 56,
                              title: Text(name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _saving
                                  ? null
                                  : () {
                                      if (_province == null) {
                                        setState(() {
                                          _province = provinces[index];
                                          _query.clear();
                                        });
                                      } else {
                                        _save(id);
                                      }
                                    },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: () => _refreshCity(forceWeather: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _city?.label ?? 'Şehrim',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: homeNavy,
                                ),
                              ),
                              TextButton.icon(
                                key: const ValueKey('city-change'),
                                onPressed: () => setState(() {
                                  _choosing = true;
                                  _province = null;
                                  _query.clear();
                                }),
                                icon: const Icon(Icons.location_on_outlined),
                                label: const Text('Şehri Değiştir'),
                              ),
                              if (_home
                                      .homeState
                                      .home
                                      ?.liveModules
                                      ?.weather
                                      .locationId ==
                                  _city?.location.id)
                                CityWeatherCard(
                                  weather: _home
                                      .homeState
                                      .home!
                                      .liveModules!
                                      .weather,
                                ),
                              CityLiveModules(
                                modules: _home.homeState.home?.liveModules,
                                locationId: _city!.location.id,
                              ),
                              const Text(
                                'Yerel Haberler',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: homeNavy,
                                ),
                              ),
                              if (_items.isEmpty &&
                                  !_loadingNews &&
                                  !_newsError)
                                const HomeMessage(
                                  'Henüz yerel haber bulunmuyor.',
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid.builder(
                          itemCount: _items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: compactNewsGridHeight(
                                  context,
                                  (MediaQuery.sizeOf(context).width - 42) / 2,
                                ),
                              ),
                          itemBuilder: (_, index) => CompactNewsGridCard(
                            news: _items[index],
                            onTap: () => NewsNavigation.openArticle(
                              context,
                              _items[index],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              if (_loadingNews)
                                const CircularProgressIndicator(),
                              if (_newsError)
                                const HomeMessage(
                                  'Yerel haberler yüklenemedi. Mevcut içerik korunuyor.',
                                ),
                              if (!_loadingNews && (_newsError || _hasMore))
                                OutlinedButton(
                                  onPressed: () => _loadNews(),
                                  child: Text(
                                    _newsError
                                        ? 'Tekrar Dene'
                                        : 'Daha Fazla Haber',
                                  ),
                                ),
                            ],
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
