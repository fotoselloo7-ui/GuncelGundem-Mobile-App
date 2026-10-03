import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_response.dart';
import 'package:guncelgundem/core/network/content_availability.dart';
import 'package:guncelgundem/data/models/category_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/models/news_model.dart';
import 'package:guncelgundem/data/models/news_detail_model.dart';
import 'package:guncelgundem/data/models/news_block_model.dart';
import 'package:guncelgundem/data/repositories/news_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/data/state/home_data_state.dart';
import 'package:guncelgundem/features/home/presentation/home_screen.dart';
import 'package:guncelgundem/features/news/presentation/news_detail_route.dart';
import 'package:guncelgundem/features/news/presentation/news_feed_screen.dart';
import 'package:guncelgundem/features/news/presentation/news_navigation.dart';
import 'package:guncelgundem/features/news/presentation/widgets/article_block_renderer.dart';
import 'package:guncelgundem/features/news/presentation/widgets/news_feed_card.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/6da/$name.json').readAsStringSync())
        as Map<String, dynamic>;
List<CategoryModel> realCategories() => (fixture('categories')['data'] as List)
    .map((value) => CategoryModel.fromJson(value as Map<String, dynamic>))
    .toList();
const category = CategoryModel(
  id: 'category-test',
  name: 'API kategori başlığı',
  slug: 'api-kategori',
);
NewsModel news(int i, {bool long = false}) => NewsModel(
  id: '$i',
  slug: 'article-$i',
  title: long
      ? List.filled(25, 'Uzun haber başlığı').join(' ')
      : 'API haber başlığı $i',
  summary: long
      ? List.filled(35, 'Tam özet metni.').join(' ')
      : 'Sunucudan gelen özet $i.',
  primaryCategory: const CategorySnippetModel(
    id: 'test',
    name: 'API kategori etiketi',
    slug: 'test',
  ),
  locations: const [
    LocationSnippetModel(id: 'saved', name: 'API yerel konumu', slug: 'saved'),
  ],
  publishedAt: DateTime.parse('2026-09-29T09:43:06+03:00'),
  breaking: true,
);

class FakeNews extends NewsRepository {
  final calls = <String>[];
  final details = <String>[];
  Future<PaginatedNewsResult> Function(String, String, int)? handler;
  Future<PaginatedNewsResult> fetch(String kind, String key, int page) async {
    calls.add('$kind:$key:$page');
    if (handler != null) return handler!(kind, key, page);
    return PaginatedNewsResult(
      news: List.generate(15, (i) => news((page - 1) * 15 + i)),
      meta: ApiMeta(page: page, limit: 15, total: 45, hasMore: page < 3),
    );
  }

  @override
  Future<PaginatedNewsResult> getBreakingPage({int page = 1, int limit = 15}) =>
      fetch('breaking', '', page);

  /// latest / featured / mostRead akışlarının tamamı getArchive() üzerinden gider
  /// (NewsFeedScreen._fetch). Sahte bunu karşılamadığı için bu modlar gerçek ağ
  /// katmanına düşüyor ve testte boş ekran render ediliyordu.
  @override
  Future<PaginatedNewsResult> getArchive({
    int page = 1,
    int limit = 16,
    String? feed,
  }) => fetch('archive', feed ?? 'latest', page);
  @override
  Future<PaginatedNewsResult> getCategoryNews(
    String slug, {
    int page = 1,
    int limit = 15,
  }) => fetch('category', slug, page);
  @override
  Future<PaginatedNewsResult> search(
    String query, {
    int page = 1,
    int limit = 15,
  }) => fetch('search', query, page);
  @override
  Future<NewsDetailResult> getNewsDetailWithAvailability(
    String slugOrId, {
    bool forceRefresh = false,
  }) async {
    details.add(slugOrId);
    return NewsDetailResult(
      availability: ContentAvailability.available,
      news: NewsDetailModel(
        card: news(0),
        body: const NewsBodyModel(
          blocks: [
            ParagraphNewsBlock(text: 'Mevcut renderer ile haber gövdesi.'),
          ],
        ),
      ),
    );
  }
}

class FakeTaxonomy extends TaxonomyRepository {
  @override
  Future<List<CategoryModel>> getCategories({
    bool forceRefresh = false,
  }) async => realCategories();
}

class Observer extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeNews repository,
  NewsFeedMode mode, {
  CategoryModel? selected,
  double width = 390,
  double scale = 1,
  Observer? observer,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      navigatorObservers: [?observer],
      onGenerateRoute: (settings) => NewsNavigation.generate(
        settings,
        repository: repository,
        taxonomy: FakeTaxonomy(),
      ),
      home: RepaintBoundary(
        key: const ValueKey('news-preview'),
        child: NewsFeedScreen(
          key: UniqueKey(),
          mode: mode,
          repository: repository,
          taxonomy: FakeTaxonomy(),
          initialCategory: selected,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Akışı bir adım yukarı kaydırır. Bekleyen (pending) bir sayfa isteği varken
/// CircularProgressIndicator süresiz döndüğü için burada pumpAndSettle KULLANILMAZ.
Future<void> dragFeed(WidgetTester tester, {double dy = -600}) async {
  await tester.drag(
    find.byKey(const ValueKey('news-scroll')),
    Offset(0, dy),
  );
  await tester.pump();
}

/// Mevcut sözleşme: liste dibine yaklaşınca (extentAfter < 240) sonraki sayfa
/// OTOMATİK istenir (NewsFeedScreen._onScroll). 'news-more' butonu yalnız
/// otomatik yükleme devre dışıyken (hata sonrası / kısa liste) görünen yedek
/// aksiyondur. Bu yardımcı, kaydırmanın gerçekten yeni bir sayfa isteği
/// ürettiğini DOĞRULAR; sessizce geçmez.
Future<void> triggerNextPage(
  WidgetTester tester,
  FakeNews repo, {
  int maxDrags = 40,
}) async {
  final before = repo.calls.length;
  for (var i = 0; i < maxDrags && repo.calls.length == before; i++) {
    await dragFeed(tester);
  }
  expect(
    repo.calls.length,
    greaterThan(before),
    reason: 'kaydırma sonraki sayfa isteğini tetiklemeliydi',
  );
}

/// Liste sonundaki bitiş işaretçisine ('news-end') ulaşana kadar kaydırır.
Future<void> scrollToFeedEnd(WidgetTester tester, {int maxDrags = 60}) async {
  for (var i = 0; i < maxDrags; i++) {
    if (find.byKey(const ValueKey('news-end')).evaluate().isNotEmpty) return;
    await dragFeed(tester);
    await tester.pumpAndSettle();
  }
}

Future<void> showFooter(WidgetTester tester, String key) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('news-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    650,
    scrollable: scrollable,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Poppins');
    for (final weight in ['Regular', 'SemiBold', 'Bold']) {
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/poppins/Poppins-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
    'breaking first page is lazy; all three pages remain reachable without caps',
    (tester) async {
      final repo = FakeNews();
      await pumpScreen(tester, repo, NewsFeedMode.breaking);
      expect(repo.calls, ['breaking::1']);
      expect(find.text('15 / 45 haber'), findsOneWidget);
      // İlk sayfa tembel: 15 kaydın tamamı peşinen inşa edilmez.
      expect(
        find.byType(CompactNewsGridCard).evaluate().length,
        lessThan(15),
      );
      for (var page = 2; page <= 3; page++) {
        await triggerNextPage(tester, repo);
        await tester.pumpAndSettle();
        expect(repo.calls.last, 'breaking::$page');
      }
      await scrollToFeedEnd(tester);
      expect(find.byKey(const ValueKey('news-more')), findsNothing);
      expect(find.text('Tüm haberler gösterildi.'), findsOneWidget);
      tester
          .widget<CustomScrollView>(find.byKey(const ValueKey('news-scroll')))
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('45 / 45 haber'), findsOneWidget);
    },
  );

  testWidgets(
    'initial loading stays clean, first error retries, empty result is compact',
    (tester) async {
      final repo = FakeNews();
      final pending = Completer<PaginatedNewsResult>();
      repo.handler = (_, _, _) => pending.future;
      // Do not settle an intentionally pending progress animation.
      await tester.pumpWidget(
        MaterialApp(
          home: NewsFeedScreen(mode: NewsFeedMode.breaking, repository: repo),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar Dene'), findsOneWidget);
      repo.handler = (_, _, _) async => const PaginatedNewsResult(
        news: [],
        meta: ApiMeta(hasMore: false, total: 0),
      );
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();
      expect(find.text('Bu seçime uygun haber bulunamadı.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pagination loading/error preserves news; retry repeats failed page only',
    (tester) async {
      final repo = FakeNews();
      await pumpScreen(tester, repo, NewsFeedMode.breaking);
      final pending = Completer<PaginatedNewsResult>();
      repo.handler = (_, _, _) => pending.future;
      await triggerNextPage(tester, repo);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Bekleyen sayfa sırasında mevcut kayıtlar ekranda kalır.
      expect(find.byType(CompactNewsGridCard), findsWidgets);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Tekrar Dene'), findsOneWidget);
      repo.handler = null;
      await showFooter(tester, 'news-retry');
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['breaking::1', 'breaking::2', 'breaking::2']);
    },
  );

  testWidgets(
    'all backend roots and subcategories are accessible and open canonical category',
    (tester) async {
      final repo = FakeNews();
      await pumpScreen(tester, repo, NewsFeedMode.categories);
      expect(flattenNewsCategories(realCategories()).length, 48);
      final last = flattenNewsCategories(realCategories()).last.category;
      await showFooter(tester, 'news-category-${last.id}');
      await tester.tap(find.byKey(ValueKey('news-category-${last.id}')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'category:${last.slug}:1');
      await tester.drag(
        find.byKey(const ValueKey('news-scroll')),
        const Offset(0, 10000),
      );
      await tester.pumpAndSettle();
      expect(find.text(last.name), findsOneWidget);
    },
  );

  testWidgets(
    'category article pagination does not stop at the first ten or fifteen',
    (tester) async {
      final repo = FakeNews();
      await pumpScreen(
        tester,
        repo,
        NewsFeedMode.categories,
        selected: category,
      );
      for (var page = 2; page <= 3; page++) {
        await triggerNextPage(tester, repo);
        await tester.pumpAndSettle();
      }
      expect(repo.calls, [
        'category:api-kategori:1',
        'category:api-kategori:2',
        'category:api-kategori:3',
      ]);
    },
  );

  testWidgets(
    '400ms search debounce, empty and one-character queries make no calls',
    (tester) async {
      final repo = FakeNews();
      await pumpScreen(tester, repo, NewsFeedMode.search);
      final field = find.byKey(const ValueKey('news-search'));
      await tester.enterText(field, ' ');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(field, 'a');
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.calls, isEmpty);
      await tester.enterText(field, 'ilk');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(field, 'son');
      await tester.pump(const Duration(milliseconds: 399));
      expect(repo.calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repo.calls, ['search:son:1']);
    },
  );

  testWidgets('search pagination uses same query and full result count', (
    tester,
  ) async {
    final repo = FakeNews();
    await pumpScreen(tester, repo, NewsFeedMode.search);
    await tester.enterText(find.byKey(const ValueKey('news-search')), 'gündem');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    for (var page = 2; page <= 3; page++) {
      await triggerNextPage(tester, repo);
      await tester.pumpAndSettle();
    }
    expect(repo.calls, [
      'search:gündem:1',
      'search:gündem:2',
      'search:gündem:3',
    ]);
  });

  testWidgets('clearing/changing search rejects stale asynchronous results', (
    tester,
  ) async {
    final repo = FakeNews();
    final old = Completer<PaginatedNewsResult>();
    repo.handler = (_, query, _) => query == 'eski'
        ? old.future
        : Future.value(
            PaginatedNewsResult(
              news: [news(99)],
              meta: const ApiMeta(hasMore: false),
            ),
          );
    await pumpScreen(tester, repo, NewsFeedMode.search);
    final field = find.byKey(const ValueKey('news-search'));
    await tester.enterText(field, 'eski');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(field, 'yeni');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    old.complete(
      PaginatedNewsResult(news: [news(0)], meta: const ApiMeta(hasMore: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('API haber başlığı 99'), findsOneWidget);
    expect(find.text('API haber başlığı 0'), findsNothing);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactNewsGridCard), findsNothing);
    expect(repo.calls.length, 2);
  });

  testWidgets(
    'cached offline pages show real content with a non-blocking notice',
    (tester) async {
      final repo = FakeNews()
        ..handler = (_, _, _) async => PaginatedNewsResult(
          news: [news(0)],
          meta: const ApiMeta(total: 1, hasMore: false),
          isFromCache: true,
          isOffline: true,
        );
      await pumpScreen(tester, repo, NewsFeedMode.breaking);
      expect(
        find.text('Bağlantı kurulamadı. Kaydedilmiş haberler gösteriliyor.'),
        findsOneWidget,
      );
      expect(find.text('API haber başlığı 0'), findsOneWidget);
    },
  );

  for (final mode in NewsFeedMode.values) {
    testWidgets(
      '${mode.name} card opens minimal detail with existing renderer and correct slug',
      (tester) async {
        final repo = FakeNews()
          ..handler = (_, _, _) async => PaginatedNewsResult(
            news: [news(0)],
            meta: const ApiMeta(hasMore: false),
          );
        final observer = Observer();
        await pumpScreen(
          tester,
          repo,
          mode,
          selected: mode == NewsFeedMode.categories ? category : null,
          observer: observer,
        );
        if (mode == NewsFeedMode.search) {
          await tester.enterText(
            find.byKey(const ValueKey('news-search')),
            'haber',
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('news-grid-0')),
        );
        await tester.tap(find.byKey(const ValueKey('news-grid-0')));
        await tester.pumpAndSettle();
        expect(observer.names.last, NewsNavigation.article);
        expect(repo.details, ['article-0']);
        expect(find.byType(NewsDetailRoute), findsOneWidget);
        expect(find.byType(ArticleBlockRenderer), findsOneWidget);
        expect(find.text('Mevcut renderer ile haber gövdesi.'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Home Son Dakika and search buttons open real named routes, without Home redesign',
    (tester) async {
      final repo = FakeNews();
      final observer = Observer();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          onGenerateRoute: (settings) => NewsNavigation.generate(
            settings,
            repository: repo,
            taxonomy: FakeTaxonomy(),
          ),
          home: Builder(
            builder: (context) => HomeScreen(
              homeState: HomeDataState(),
              loadOnStart: false,
              onAction: (action, payload) =>
                  NewsNavigation.handleHome(context, action, payload),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pumpAndSettle();
      expect(observer.names.last, NewsNavigation.breaking);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ara'));
      await tester.pumpAndSettle();
      expect(observer.names.last, NewsNavigation.search);
    },
  );

  testWidgets('invalid article identifiers do not initiate a detail request', (
    tester,
  ) async {
    final repo = FakeNews()
      ..handler = (_, _, _) async => const PaginatedNewsResult(
        news: [
          NewsModel(id: '', slug: '', title: 'Bağlantısız haber', summary: ''),
        ],
        meta: ApiMeta(hasMore: false),
      );
    await pumpScreen(tester, repo, NewsFeedMode.breaking);
    await tester.tap(find.byKey(const ValueKey('news-grid-')));
    await tester.pumpAndSettle();
    expect(repo.details, isEmpty);
    expect(find.byType(NewsDetailRoute), findsNothing);
  });

  testWidgets('unmounted pending screen ignores late requests safely', (
    tester,
  ) async {
    final pending = Completer<PaginatedNewsResult>();
    final repo = FakeNews()..handler = (_, _, _) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedScreen(mode: NewsFeedMode.breaking, repository: repo),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(PaginatedNewsResult(news: [news(0)]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final mode in NewsFeedMode.values) {
        testWidgets(
          '${mode.name} ${width.toInt()}px scale $scale clamps long titles in the 2-column grid without overflow',
          (tester) async {
            final repo = FakeNews()
              ..handler = (_, _, _) async => PaginatedNewsResult(
                news: [news(0, long: true)],
                meta: const ApiMeta(hasMore: false),
              );
            await pumpScreen(
              tester,
              repo,
              mode,
              selected: mode == NewsFeedMode.categories ? category : null,
              width: width,
              scale: scale,
            );
            if (mode == NewsFeedMode.search) {
              await tester.enterText(
                find.byKey(const ValueKey('news-search')),
                'haber',
              );
              await tester.pump(const Duration(milliseconds: 400));
              await tester.pumpAndSettle();
            }
            // Mevcut sözleşme: haber akışı 2 sütunlu kompakt grid'dir
            // (CompactNewsGridCard). Sabit yükseklikli kutuda uzun başlık
            // 3 satıra kırpılır ve ellipsis ile biter — bu bilinçli tasarımdır.
            expect(find.byType(CompactNewsGridCard), findsOneWidget);
            final title = tester.widget<Text>(
              find.text(news(0, long: true).title),
            );
            expect(title.maxLines, 3);
            expect(title.overflow, TextOverflow.ellipsis);
            expect(find.byType(CustomScrollView), findsOneWidget);
            for (var i = 0; i < 10; i++) {
              await tester.drag(
                find.byKey(const ValueKey('news-scroll')),
                const Offset(0, -500),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  }

  for (final mode in NewsFeedMode.values) {
    testWidgets(
      '${mode.name} visual 390px using API fixtures and existing Poppins',
      (tester) async {
        final repo = FakeNews()
          ..handler = (_, _, _) async {
            final value = fixture(
              mode == NewsFeedMode.search ? 'search' : 'breaking1',
            );
            return PaginatedNewsResult(
              news: (value['data'] as List)
                  .map(
                    (raw) => NewsModel.fromJson({
                      ...raw as Map<String, dynamic>,
                      'cover_url': null,
                    }),
                  )
                  .toList(),
              meta: ApiMeta.fromJson(value['meta'] as Map<String, dynamic>),
            );
          };
        await pumpScreen(tester, repo, mode);
        if (mode == NewsFeedMode.search) {
          await tester.enterText(
            find.byKey(const ValueKey('news-search')),
            'haber',
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
        }
        await expectLater(
          find.byKey(const ValueKey('news-preview')),
          matchesGoldenFile('goldens/${mode.name}-390.png'),
        );
      },
    );
  }
}
