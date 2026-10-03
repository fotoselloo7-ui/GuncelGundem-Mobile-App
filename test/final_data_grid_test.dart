import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/api_response.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/live_module_model.dart';
import 'package:guncelgundem/data/repositories/news_repository.dart';
import 'package:guncelgundem/data/state/home_data_state.dart';
import 'package:guncelgundem/features/blog/presentation/blog_category_explorer.dart';
import 'package:guncelgundem/features/blog/presentation/blog_feed_screen.dart';
import 'package:guncelgundem/features/blog/presentation/blog_widgets.dart';
import 'package:guncelgundem/features/home/presentation/live_data_widgets.dart';
import 'package:guncelgundem/features/news/presentation/news_feed_screen.dart';
import 'package:guncelgundem/features/news/presentation/widgets/news_feed_card.dart';

import 'phase6cb/home_screen_test.dart' as home;
import 'phase6da/news_screens_test.dart' as news;
import 'phase6db/blog_screens_test.dart' as blog;

class GridNews extends news.FakeNews {
  @override
  Future<PaginatedNewsResult> getArchive({
    int page = 1,
    int limit = 15,
    String? feed,
  }) => fetch(feed ?? 'latest', '', page);
}

void assertTwoColumns(WidgetTester tester) {
  final grids = tester.widgetList<SliverGrid>(find.byType(SliverGrid));
  expect(grids, isNotEmpty);
  for (final grid in grids) {
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  test('Home accepts old news and backend articles/items contracts', () {
    for (final key in ['news', 'articles', 'items']) {
      final section = HomeCategorySectionModel.fromJson({
        'category': news.category.toJson(),
        key: [news.news(1).toJson()],
      });
      expect(section.news.single.id, '1');
    }
    expect(home.fixtureHome().liveModules, isNull);
  });
  test('Location epoch invalidates weather/local modules and protects ABA requests', () {
    final state = HomeDataState();
    final old = state.activateLocation('a');
    state.updateFromHome(
      const HomeModel(
        liveModules: LiveModulesModel(
          weather: WeatherModuleModel(
            available: true,
            locationId: 'a',
            temperature: 20,
          ),
          market: MarketModuleModel(available: true),
          prayerTimes: LiveListModuleModel(available: true, locationId: 'a'),
        ),
      ),
    );
    state.activateLocation('b');
    expect(state.home!.liveModules!.weather.locationId, 'b');
    expect(state.home!.liveModules!.weather.hasData, false);
    expect(state.home!.liveModules!.prayerTimes.available, false);
    expect(state.home!.liveModules!.market.available, true);
    expect(state.isActiveLocation('a', old), false);
    state.activateLocation('a');
    expect(state.isActiveLocation('a', old), false);
    state.dispose();
  });
  test('Expired and offline time-sensitive modules never remain fresh', () {
    final expired = LiveListModuleModel.fromJson({
      'available': true,
      'status': 'FRESH',
      'expires_at': '2026-01-01T00:00:00Z',
    });
    expect(expired.stale, true);
    expect(expired.asOffline().stale, true);
  });
  for (final width in [360.0, 390.0, 411.0, 430.0]) {
    for (final mode in NewsFeedMode.values.where(
      (m) => m != NewsFeedMode.search,
    )) {
      testWidgets('$mode 2-column at $width with 200% text', (tester) async {
        final repo = GridNews()
          ..handler = (kind, key, page) async => PaginatedNewsResult(
            news: List.generate(5, (i) => news.news(i, long: true)),
            meta: ApiMeta(page: 1, limit: 15, total: 5, hasMore: false),
          );
        await news.pumpScreen(
          tester,
          repo,
          mode,
          selected: news.category,
          width: width,
          scale: 2,
        );
        assertTwoColumns(tester);
        expect(find.byType(CompactNewsGridCard), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    for (final category in [
      null,
      blog.roots().first,
      blog.roots().first.children.first,
    ]) {
      testWidgets('Blog ${category?.slug ?? 'index'} 2-column at $width', (
        tester,
      ) async {
        final repo = blog.FakeBlog();
        await blog.pump(
          tester,
          BlogFeedScreen(
            repository: repo,
            selection: category == null
                ? null
                : BlogCategorySelection(category),
          ),
          repo,
          width: width,
          scale: 2,
        );
        await tester.pumpAndSettle();
        if (category != null) {
          await tester.drag(
            find.byKey(const ValueKey('blog-scroll')),
            const Offset(0, -620),
          );
          await tester.pumpAndSettle();
        }
        assertTwoColumns(tester);
        expect(find.byType(CompactBlogGridCard), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('Search results use two columns', (tester) async {
    final repo = GridNews();
    await news.pumpScreen(tester, repo, NewsFeedMode.search);
    await tester.enterText(find.byType(TextField).first, 'haber');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    assertTwoColumns(tester);
    expect(repo.calls.last, contains('search:haber:1'));
  });
  testWidgets(
    'News lazy pagination deduplicates and reaches subsequent pages',
    (tester) async {
      final repo = GridNews()
        ..handler = (kind, key, page) async => PaginatedNewsResult(
          news: List.generate(15, (i) => news.news((page - 1) * 14 + i)),
          meta: ApiMeta(page: page, limit: 15, total: 43, hasMore: page < 3),
        );
      await news.pumpScreen(tester, repo, NewsFeedMode.breaking);
      final scroll = tester
          .widget<CustomScrollView>(find.byKey(const ValueKey('news-scroll')))
          .controller!;
      for (var i = 0; i < 2; i++) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(repo.calls, ['breaking::1', 'breaking::2', 'breaking::3']);
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect((grid.delegate as SliverChildBuilderDelegate).childCount, 43);
    },
  );
  testWidgets(
    'Blog lazy pagination remains reachable without duplicate fetch',
    (tester) async {
      final repo = blog.FakeBlog();
      await blog.pump(tester, BlogFeedScreen(repository: repo), repo);
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<CustomScrollView>(find.byKey(const ValueKey('blog-scroll')))
          .controller!;
      for (var i = 0; i < 2; i++) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(repo.calls, ['index:1', 'index:2', 'index:3']);
    },
  );
  testWidgets(
    'Home category summaries enforce max5 even with oversized payload',
    (tester) async {
      await home.pumpHome(
        tester,
        home: HomeModel(
          categorySections: [
            HomeCategorySectionModel(
              category: news.category,
              news: List.generate(12, news.news),
            ),
          ],
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        5,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('No invented quake magnitude and wrong-city prayer hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HomeEarthquakeSection(
                module: LiveListModuleModel(
                  available: true,
                  items: [
                    {'location': 'missing magnitude'},
                  ],
                ),
              ),
              CityLiveModules(
                locationId: 'b',
                modules: LiveModulesModel(
                  prayerTimes: LiveListModuleModel(
                    available: true,
                    status: 'FRESH',
                    locationId: 'a',
                    items: [
                      {'time': '05:00'},
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Son Depremler'), findsNothing);
    expect(find.text('Namaz Vakitleri'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
