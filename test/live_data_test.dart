import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_client.dart';
import 'package:guncelgundem/core/storage/local_cache_service.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/home_view_model.dart';
import 'package:guncelgundem/data/models/live_module_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/repositories/home_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/data/state/home_data_state.dart';
import 'package:guncelgundem/features/home/presentation/live_data_widgets.dart';
import 'package:guncelgundem/features/news/presentation/city_screen.dart';
import 'package:guncelgundem/services/api_service.dart';

import 'phase6ca/blog_repository_test.dart' show ContractAdapter;
import 'phase6cb/home_screen_test.dart' as home;

class MultipleCities extends TaxonomyRepository {
  @override
  Future<List<LocationProvinceModel>> getLocations({
    bool forceRefresh = false,
  }) async => [
    home.city,
    const LocationProvinceModel(
      id: '08',
      name: 'Artvin',
      slug: 'artvin',
      districts: [
        LocationDistrictModel(
          id: '08-b',
          name: 'Borçka',
          slug: 'borcka',
          provinceId: '08',
        ),
      ],
    ),
  ];
}

// Deterministic test-only snapshots. Production exclusively consumes /home.
Map<String, dynamic> snapshot({String id = '07'}) => {
  ...home.fixtureHome().toJson(),
  'live_modules': {
    'market': {
      'available': true,
      'items': [
        for (final code in [
          'USD',
          'EUR',
          'GRAM_ALTIN_REF',
          'GBP',
          'CHF',
          'CAD',
        ])
          {
            'code': code,
            'name': code == 'GRAM_ALTIN_REF' ? 'Gram Altın (Referans)' : code,
            'provider': code == 'GRAM_ALTIN_REF' ? 'gold' : 'tcmb_fx',
            'value': '48.4598',
            'buy': 48.3727,
            'sell': 48.4598,
            'currency': 'TRY',
            'unit': 1,
            'status': 'STALE',
            'updated_at': '2026-09-09T13:52:39+03:00',
          },
      ],
    },
    'weather': {
      'available': true,
      'location_id': id,
      'city_name': 'Antalya',
      'temperature': 21,
      'condition': 'Açık',
      'icon': 'sun',
      'source': 'MET Norway',
      'status': 'STALE',
      'updated_at': '2026-09-10T07:14:45+03:00',
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late LocalCacheService cache;
  late ContractAdapter adapter;
  late HomeDataState state;
  late HomeRepository repo;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gg_live_test_');
    cache = LocalCacheService.instance;
    await cache.init(overrideDir: dir);
    await cache.clear();
    state = HomeDataState();
    adapter = ContractAdapter()..payload = snapshot();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://contract.test/api/mobile/v1',
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = adapter;
    repo = HomeRepository(
      apiService: ApiService(apiClient: ApiClient(customDio: dio)),
      state: state,
      cacheService: cache,
      deviceRepository: home.FakeDevice(['07']),
      taxonomyRepository: home.FakeTaxonomy(),
    );
  });
  tearDown(() async {
    state.dispose();
    await cache.clear();
    await dir.delete(recursive: true);
  });
  test('old Home contract remains optional and serializes existing fields', () {
    final old = home.fixtureHome();
    expect(old.liveModules, isNull);
    final value = HomeModel.fromJson(snapshot());
    final serialized = value.toJson()..remove('live_modules');
    expect(serialized, old.toJson());
    expect(value.liveModules!.market.items.take(3).map((e) => e.code), [
      'USD',
      'EUR',
      'GRAM_ALTIN_REF',
    ]);
    expect(value.liveModules!.weather.feelsLike, isNull);
  });
  test('nullable and malformed live values never manufacture zero or default weather', () {
    final data = LiveModulesModel.fromJson({
      'market': {
        'items': [
          null,
          {},
          {'code': 'USD', 'value': 'NaN'},
        ],
      },
      'weather': {'available': true, 'temperature': 'bad'},
    });
    expect(data.market.items, isEmpty);
    expect(data.weather.hasData, isFalse);
    expect(LiveModulesModel.fromJson({}).weather.cityName, isNull);
    expect(liveNumber(double.infinity), isNull);
  });
  test(
    'saved canonical location, coalesced Home, shared City state and cache',
    () async {
      final values = await Future.wait([
        repo.getHome(),
        repo.getHomeForLocation('07'),
      ]);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.queryParameters['location_id'], '07');
      expect(identical(values.first, values.last), isTrue);
      final weather = await repo.getWeatherForLocation('07');
      expect(adapter.requests, hasLength(1));
      expect(weather, state.home!.liveModules!.weather);
      expect(
        (await cache.get(HomeRepository.locationCacheKey('07')))!
            .payload['live_modules'],
        isNotNull,
      );
      expect(await cache.get(HomeRepository.locationCacheKey('08')), isNull);
    },
  );
  test(
    'multiple saved locations preserve existing district preference order',
    () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://contract.test/api/mobile/v1',
          validateStatus: (_) => true,
        ),
      )..httpClientAdapter = adapter;
      final multi = HomeRepository(
        apiService: ApiService(apiClient: ApiClient(customDio: dio)),
        state: state,
        cacheService: cache,
        deviceRepository: home.FakeDevice(['08-b', '07-alanya']),
        taxonomyRepository: MultipleCities(),
      );
      await multi.getHome();
      expect(adapter.requests.single.queryParameters['location_id'], '08-b');
    },
  );
  test('offline last successful snapshot preserves timestamp and offline label across City reuse', () async {
    final original = await repo.getHome();
    adapter.offline = true;
    final offline = await repo.getHome(forceRefresh: true);
    expect(offline.liveModules!.weather.offline, isTrue);
    expect(offline.liveModules!.market.offline, isTrue);
    expect(
      offline.liveModules!.weather.updatedAt,
      original.liveModules!.weather.updatedAt,
    );
    expect((await repo.getWeatherForLocation('07'))!.offline, isTrue);
    await expectLater(repo.getHomeForLocation('08'), throwsA(anything));
  });
  testWidgets('unavailable modules and missing feels-like hide gracefully', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WeatherSummary(weather: WeatherModuleModel()),
              HomeMarketSection(market: MarketModuleModel()),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('live-weather')), findsNothing);
    expect(find.byKey(const ValueKey('home-market')), findsNothing);
  });
  testWidgets(
    'Home uses selected city weather and contains bounded market section',
    (tester) async {
      final model = HomeModel.fromJson(snapshot());
      await home.pumpHome(
        tester,
        home: model,
        slots: HomeViewModel(
          home: model,
          city: const LocationSnippetModel(
            id: '07',
            name: 'Antalya',
            slug: 'antalya',
            type: 'province',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('live-weather')), findsOneWidget);
      expect(find.byType(HomeMarketSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Home never shows a different city weather', (tester) async {
    final model = HomeModel.fromJson(snapshot(id: '08'));
    await home.pumpHome(
      tester,
      home: model,
      slots: HomeViewModel(
        home: model,
        city: const LocationSnippetModel(
          id: '07',
          name: 'Antalya',
          slug: 'antalya',
          type: 'province',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('live-weather')), findsNothing);
  });
  testWidgets(
    'City consumes the same Home repository model without extra weather API',
    (tester) async {
      await tester.runAsync(() async {
        await repo.getHome();
        await tester.pumpWidget(
          MaterialApp(
            home: CityScreen(
              home: repo,
              device: home.FakeDevice(['07']),
              taxonomy: home.FakeTaxonomy(),
              news: home.FakeNews(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(CityWeatherCard), findsOneWidget);
      expect(find.text('21,0°C'), findsOneWidget);
      expect(adapter.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [360.0, 390.0, 411.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('live cards no clipping/overflow at $width / scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1500);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final modules = HomeModel.fromJson(snapshot()).liveModules!;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CityWeatherCard(weather: modules.weather),
                      HomeMarketSection(market: modules.market),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('market-CAD')), findsNothing);
        final scroll = find
            .descendant(
              of: find.byKey(const ValueKey('home-market')),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.drag(scroll, const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
