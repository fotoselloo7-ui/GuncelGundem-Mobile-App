import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/ad_model.dart';
import 'package:guncelgundem/data/models/blog_article_model.dart';
import 'package:guncelgundem/data/models/blog_category_model.dart';
import 'package:guncelgundem/data/models/category_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/home_view_model.dart';
import 'package:guncelgundem/data/models/info_corner_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/models/news_model.dart';
import 'package:guncelgundem/data/models/notification_preference_model.dart';
import 'package:guncelgundem/data/repositories/device_repository.dart';
import 'package:guncelgundem/data/repositories/home_repository.dart';
import 'package:guncelgundem/data/repositories/news_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/data/state/home_data_state.dart';
import 'package:guncelgundem/features/home/presentation/home_city.dart';
import 'package:guncelgundem/features/home/presentation/home_screen.dart';
import 'package:guncelgundem/features/home/presentation/home_widgets.dart';
import 'package:guncelgundem/features/news/presentation/news_navigation.dart';
import 'package:guncelgundem/services/ad_service.dart';
import 'package:guncelgundem/services/analytics_service.dart';

const item = NewsModel(
  id: 'news-1',
  slug: 'news-1',
  title: 'Kentte yeni ulaşım düzenlemesi',
  summary: 'Son gelişmeler ve yerel gündemden önemli ayrıntılar.',
  primaryCategory: CategorySnippetModel(
    id: 'gundem',
    name: 'Gündem',
    slug: 'gundem',
  ),
);
const city = LocationProvinceModel(
  id: '07',
  name: 'Antalya',
  slug: 'antalya',
  districts: [
    LocationDistrictModel(
      id: '07-alanya',
      name: 'Alanya',
      slug: 'alanya',
      provinceId: '07',
    ),
  ],
);
const ad = MobileAdModel(
  campaignId: 'campaign-1',
  advertiserName: 'Test Sponsor',
  campaignName: 'Aktif kampanya',
  type: 'external_link',
  placementIds: ['home_top'],
  title: 'Sunucudan gelen reklam',
  targetUrl: 'https://example.com',
);

HomeModel fixtureHome() {
  final json = jsonDecode(
    File('test/fixtures/6ca/home.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  // Deterministic, offline layout tests; production still uses real cached images.
  void withoutImages(dynamic value) {
    if (value is Map) {
      for (final key in ['cover_url', 'cover']) {
        if (value.containsKey(key)) value[key] = null;
      }
      for (final child in value.values) {
        withoutImages(child);
      }
    } else if (value is List) {
      for (final child in value) {
        withoutImages(child);
      }
    }
  }

  withoutImages(json);
  return HomeModel.fromJson(
    json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json,
  );
}

class FakeHome extends HomeRepository {
  final HomeDataState state;
  final HomeModel value;
  bool fail = false;
  FakeHome(this.state, this.value);
  @override
  Future<HomeModel?> getCachedHome() async => null;
  @override
  Future<HomeModel> getHome({bool forceRefresh = false}) async {
    if (fail) throw StateError('offline');
    state.updateFromHome(value);
    return value;
  }
}

class FakeDevice extends DeviceRepository {
  List<String> ids;
  FakeDevice(this.ids);
  @override
  Future<NotificationPreferenceModel> getPreferences() async =>
      NotificationPreferenceModel(locationIds: ids);
}

class FakeTaxonomy extends TaxonomyRepository {
  @override
  Future<List<LocationProvinceModel>> getLocations({
    bool forceRefresh = false,
  }) async => [city];
}

class FakeNews extends NewsRepository {
  String? province;
  String? districtUsed;
  bool fail = false;
  @override
  Future<PaginatedNewsResult> getLocationNews(
    String slug, {
    String? district,
    int? hours,
    int page = 1,
    int limit = 15,
  }) async {
    province = slug;
    districtUsed = district;
    if (fail) throw StateError('offline');
    return const PaginatedNewsResult(news: [item]);
  }

  @override
  Future<List<NewsModel>> getBreaking({int limit = 10}) async => const [item];
}

class FakeAds extends AdService {
  MobileAdModel? active = ad;
  final List<String?> locations = [];
  final List<String> placements = [];
  @override
  Future<MobileAdModel?> getTopAd({
    required String placement,
    String? categoryId,
    String? locationId,
  }) async {
    placements.add(placement);
    locations.add(locationId);
    return active;
  }
}

class FakeAnalytics extends AnalyticsService {
  final Set<String> impressions = {};
  int clicks = 0;
  @override
  Future<bool> trackAdImpression({
    required String campaignId,
    required String placementId,
    String? newsId,
    String? categoryId,
    String? locationId,
  }) async {
    impressions.add('$campaignId:$placementId');
    return true;
  }

  @override
  Future<bool> trackAdClick({
    required String campaignId,
    required String placementId,
    String? newsId,
    String? categoryId,
    String? locationId,
  }) async {
    clicks++;
    return true;
  }
}

/// Alt gezinmenin adlandırılmış rota açan yuvalarını doğrulayabilmek için
/// basit bir gözlemci.
class RouteObserverSpy extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}

Future<void> pumpHome(
  WidgetTester tester, {
  HomeModel? home,
  HomeViewModel? slots,
  HomeDataState? state,
  HomeActionHandler? onAction,
  double width = 390,
  double textScale = 1,
  RouteObserverSpy? observer,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final data = state ?? HomeDataState();
  if (home != null) data.updateFromHome(home);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      // Alt gezinmenin 4. ve 5. yuvaları (Şehrim / Video) adlandırılmış rota
      // açar; üretici bağlanmazsa bu dokunuşlar "Could not find a generator
      // for route" ile düşerdi. Burada Ana Sayfa'nın DOĞRU KANONİK ROTA ADINI
      // ittiği doğrulanır; hedef ekranların kendi testleri vardır. Gerçek
      // ekranlar veri yüklerken süresiz dönen gösterge içerdiği için bu
      // pakette yer tutucu sayfa kullanılır (deterministik kalır).
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: SizedBox.shrink()),
      ),
      navigatorObservers: [?observer],
      home: RepaintBoundary(
        key: const ValueKey('home-preview'),
        child: HomeScreen(
          key: ObjectKey(data),
          homeState: data,
          initialSlots: slots,
          loadOnStart: false,
          onAction: onAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final name in ['Regular', 'SemiBold', 'Bold']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            Uint8List.fromList(
              File('assets/fonts/poppins/Poppins-$name.ttf').readAsBytesSync(),
            ),
          ),
        ),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(
    () async =>
        LocalCacheService.instance.remove(TaxonomyRepository.locationsCacheKey),
  );

  test('saved canonical district wins over its province; unknown IDs do not invent a city', () {
    final selected = HomeCity.resolve(['07', '07-alanya'], [city]);
    expect(selected?.label, 'Alanya / Antalya');
    expect(selected?.location.id, '07-alanya');
    expect(selected?.provinceSlug, 'antalya');
    expect(selected?.districtSlug, 'alanya');
    expect(HomeCity.resolve(['07'], [city])?.label, 'Antalya');
    expect(HomeCity.resolve(['old-id'], [city]), isNull);
  });

  testWidgets('actual home contract renders in required section order', (
    tester,
  ) async {
    final home = fixtureHome();
    await pumpHome(
      tester,
      home: home,
      slots: HomeViewModel(
        home: home,
        city: const LocationSnippetModel(
          id: '07',
          name: 'Antalya',
          slug: 'antalya',
        ),
        local: const [item],
        ads: const [ad],
        video: const [item],
      ),
    );
    final selectors = [
      find.text('ϟ SON DAKİKA'),
      find.text('REKLAM'),
      find.byKey(const ValueKey('home-hero')),
      find.text('Şehrimde Neler Var?'),
      find.text('Antalya’den Son Haberler'),
      find.byKey(const ValueKey('home-info-corner')),
      // Mevcut final sırada Güncel bölümü Video Haberler'den ÖNCE gelir.
      find.byKey(const ValueKey('home-current')),
      find.text('Video Haberler'),
    ];
    var lastY = -1.0;
    for (final selector in selectors) {
      expect(selector, findsOneWidget);
      final y = tester.getTopLeft(selector).dy;
      expect(y, greaterThan(lastY));
      lastY = y;
    }
    expect(find.byIcon(Icons.person), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'infoCorner backend title, dark editorial gallery and deduplicated accessible articles',
    (tester) async {
      final blogs = List.generate(
        7,
        (i) => BlogArticleModel(id: '$i', title: 'Sunucu yazısı $i'),
      );
      final info = InfoCornerModel(
        title: 'Sunucunun editoryal başlığı',
        featured: [blogs.first],
        latest: blogs,
        categories: List.generate(
          248,
          (i) => BlogCategoryModel(id: '$i', name: 'Konu $i', slug: 'konu-$i'),
        ),
      );
      await pumpHome(tester, home: HomeModel(infoCorner: info));
      expect(find.text(info.title), findsOneWidget);
      expect(find.text('Bilgi Köşesi'), findsNothing);
      expect(find.byKey(const ValueKey('home-blog-0')), findsOneWidget);
      expect(
        tester
            .widget<HomeArticleCard>(find.byKey(const ValueKey('home-blog-0')))
            .compact,
        isFalse,
      );
      expect(
        tester
            .widget<HomeArticleCard>(find.byKey(const ValueKey('home-blog-0')))
            .style,
        HomeCardStyle.editorial,
      );
      final gallery = find.descendant(
        of: find.byKey(const ValueKey('home-info-corner')),
        matching: find.byType(Scrollable),
      );
      // Ana Sayfa'daki Bilgi Köşesi galerisi bir ÖNİZLEMEDİR: tekilleştirilmiş
      // en fazla 4 editoryal kart gösterir (tamamı 'Tümünü Gör →' ile açılır).
      expect(gallery, findsOneWidget);
      // Galeri tembeldir: son kart yatay kaydırmayla erişilebilir olmalı.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-blog-3')),
        180,
        scrollable: gallery,
        maxScrolls: 15,
      );
      expect(find.byKey(const ValueKey('home-blog-3')), findsOneWidget);
      // Sona kadar kaydırıldıktan sonra 5. kart hiç üretilmez (önizleme sınırı).
      expect(find.byKey(const ValueKey('home-blog-4')), findsNothing);
      // 248 kategori Ana Sayfa'ya dökülmez.
      expect(find.text('Konu 4'), findsNothing);
    },
  );

  testWidgets('null and empty data remain usable without fabricated content', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.text('Şehrini seç'), findsOneWidget);
    expect(find.text('Henüz güncel haber bulunmuyor.'), findsOneWidget);
    expect(find.text('Henüz video haber bulunmuyor.'), findsNothing);
    expect(find.byKey(const ValueKey('home-info-corner')), findsNothing);
    expect(find.text('REKLAM'), findsNothing);
    await pumpHome(
      tester,
      home: const HomeModel(infoCorner: InfoCornerModel(title: 'Rehberler')),
    );
    expect(find.text('Henüz yayınlanmış yazı bulunmuyor.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'HomeDataState authoritative updates rerender without stale blogs',
    (tester) async {
      final state = HomeDataState()
        ..updateFromHome(
          const HomeModel(
            infoCorner: InfoCornerModel(
              title: 'Rehberler',
              featured: [BlogArticleModel(id: '1', title: 'Yayındaki yazı')],
            ),
          ),
        );
      await pumpHome(tester, state: state);
      expect(find.text('Yayındaki yazı'), findsOneWidget);
      state.updateFromHome(const HomeModel());
      await tester.pumpAndSettle();
      expect(find.text('Yayındaki yazı'), findsNothing);
    },
  );

  testWidgets(
    'selected city uses repository province/district and admin-disabled ad disappears',
    (tester) async {
      final state = HomeDataState();
      final ads = FakeAds(),
          news = FakeNews(),
          device = FakeDevice(['07', '07-alanya']);
      final analytics = FakeAnalytics();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            homeState: state,
            homeRepository: FakeHome(state, const HomeModel(hero: [item])),
            deviceRepository: device,
            taxonomyRepository: FakeTaxonomy(),
            newsRepository: news,
            adService: ads,
            analyticsService: analytics,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alanya / Antalya'), findsOneWidget);
      expect(find.text('Alanya’den Son Haberler'), findsOneWidget);
      expect(news.province, 'antalya');
      expect(news.districtUsed, 'alanya');
      expect(ads.placements.toSet(), {'home_top'});
      expect(ads.locations.last, '07-alanya');
      expect(find.text(ad.title), findsOneWidget);
      await tester.ensureVisible(find.text(ad.title));
      await tester.pumpAndSettle();
      expect(analytics.impressions, {'campaign-1:home_top'});
      ads.active = null;
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text(ad.title), findsNothing);
      expect(find.text('REKLAM'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'home network failure preserves usable shell and isolated local failure',
    (tester) async {
      final state = HomeDataState();
      final home = FakeHome(state, const HomeModel())..fail = true;
      final news = FakeNews()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            homeState: state,
            homeRepository: home,
            deviceRepository: FakeDevice(['07-alanya']),
            taxonomyRepository: FakeTaxonomy(),
            newsRepository: news,
            adService: FakeAds()..active = null,
            analyticsService: FakeAnalytics(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Haberlere ulaşılamadı. Yenilemek için aşağı çekin.'),
        findsOneWidget,
      );
      expect(
        find.text('Yerel haberlere şu anda ulaşılamıyor.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home-nav-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'bottom navigation keeps five ordered targets and home-only anchors',
    (tester) async {
      final actions = <HomeAction>[];
      final observer = RouteObserverSpy();
      await pumpHome(
        tester,
        onAction: (action, _) => actions.add(action),
        observer: observer,
      );
      const labels = [
        'Ana Sayfa',
        'Son Dakika',
        'Haber Gönder',
        'Şehrim',
        'Video',
      ];
      // 4. ve 5. yuva (Şehrim / Video) adlandırılmış rota açar; bu ekranlar
      // veri yüklerken süresiz dönen bir gösterge içerdiğinden burada
      // pumpAndSettle KULLANILMAZ. Rotanın gerçekten açıldığı doğrulanır.
      const routedSlots = {3: NewsNavigation.city, 4: NewsNavigation.video};
      // 1) Etiket ve dokunma hedefi ölçümleri: hiçbir rota açılmadan yapılır.
      for (var i = 0; i < labels.length; i++) {
        final target = find.byKey(ValueKey('home-nav-$i'));
        expect(
          find.descendant(of: target, matching: find.text(labels[i])),
          findsOneWidget,
        );
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      // 2) Ana Sayfa'ya özel aksiyon üreten yuvalar (0-2) ve üst bar.
      for (var i = 0; i <= 2; i++) {
        await tester.tap(find.byKey(ValueKey('home-nav-$i')));
        await tester.pumpAndSettle();
      }
      expect(actions, [HomeAction.breaking, HomeAction.submitNews]);
      expect(find.text('Video Haberler'), findsNothing);
      await tester.tap(find.byTooltip('Ara'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bildirimler'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bize Ulaşın'));
      await tester.pumpAndSettle();
      expect(actions, [
        HomeAction.breaking,
        HomeAction.submitNews,
        HomeAction.search,
        HomeAction.notifications,
        HomeAction.contact,
      ]);
      // 3) Rota açan yuvalar (Şehrim / Video) EN SON denenir: açılan sayfa
      //    üstte kaldığı için Ana Sayfa'nın periyodik ticker'ı pumpAndSettle'ı
      //    süresiz meşgul edemez. Kanonik rota adının itildiği doğrulanır.
      for (final entry in routedSlots.entries) {
        final before = actions.length;
        await tester.tap(find.byKey(ValueKey('home-nav-${entry.key}')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(observer.names.last, entry.value);
        // Bu yuvalar Ana Sayfa aksiyonu üretmez; yalnız rota açar.
        expect(actions.length, before);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        // Geri dönüş animasyonu bitene kadar sınırlı adımlarla ilerle
        // (Ana Sayfa'nın periyodik ticker'ı pumpAndSettle'ı engeller).
        for (var k = 0; k < 8; k++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

    },
  );

  testWidgets('video renders only existing supplied slot/category data', (
    tester,
  ) async {
    const home = HomeModel(
      categorySections: [
        HomeCategorySectionModel(
          category: CategoryModel(
            id: 'video',
            name: 'Video Haberler',
            slug: 'video',
          ),
          news: [item],
        ),
      ],
    );
    await pumpHome(tester, home: home);
    expect(
      find.descendant(
        of: find.byType(HomeSection),
        matching: find.text('Video Haberler'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('breaking news and header controls have 48px touch targets', (
    tester,
  ) async {
    final actions = <HomeAction>[];
    await pumpHome(
      tester,
      home: const HomeModel(breaking: [item]),
      onAction: (action, _) => actions.add(action),
    );
    final breaking = find.ancestor(
      of: find.text(item.title),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(breaking).height, greaterThanOrEqualTo(48));
    for (final tooltip in ['Ara', 'Bildirimler', 'Bize Ulaşın']) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    }
    await tester.tap(breaking);
    await tester.pumpAndSettle();
    expect(actions, [HomeAction.news]);
  });

  for (final width in [360.0, 390.0, 411.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('no overflow at ${width.toInt()}px, text scale $scale', (
        tester,
      ) async {
        final home = fixtureHome();
        await pumpHome(
          tester,
          home: home,
          width: width,
          textScale: scale,
          slots: HomeViewModel(
            home: home,
            city: const LocationSnippetModel(
              id: 'long',
              name: 'Uzun isimli kayıtlı şehir',
              slug: 'long',
            ),
            local: const [item],
            ads: const [ad],
            video: const [item],
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -620),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        final nav = find.byType(HomeBottomBar);
        expect(tester.getSize(nav).width, width);
      });
    }
    if (width == 411) {
      continue; // Responsive coverage above; existing goldens use 360/390/430.
    }
    testWidgets('home visual ${width.toInt()}px', (tester) async {
      final home = fixtureHome();
      await pumpHome(
        tester,
        home: home,
        width: width,
        slots: HomeViewModel(
          home: home,
          city: const LocationSnippetModel(
            id: '07',
            name: 'Antalya',
            slug: 'antalya',
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('home-preview')),
        matchesGoldenFile('goldens/home-${width.toInt()}.png'),
      );
      if (width == 390) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('home-info-corner')),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('home-preview')),
          matchesGoldenFile('goldens/info-corner-390.png'),
        );
      }
    });
  }
}
