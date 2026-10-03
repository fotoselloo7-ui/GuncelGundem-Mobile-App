import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/category_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/notification_preference_model.dart';
import 'package:guncelgundem/data/repositories/device_repository.dart';
import 'package:guncelgundem/data/repositories/taxonomy_repository.dart';
import 'package:guncelgundem/features/home/presentation/home_screen.dart';
import 'package:guncelgundem/features/news/presentation/city_screen.dart';
import 'package:guncelgundem/features/news/presentation/news_category_explorer_screen.dart';
import 'package:guncelgundem/features/news/presentation/news_feed_screen.dart';
import 'package:guncelgundem/features/news/presentation/news_navigation.dart';
import 'package:guncelgundem/features/news/presentation/news_submit_screen.dart';
import 'package:guncelgundem/features/news/presentation/video_screen.dart';
import 'package:guncelgundem/features/news/presentation/widgets/news_feed_card.dart';

import '../phase6cb/home_screen_test.dart' as home;
import '../phase6da/news_screens_test.dart' as news;
import '../phase6db/blog_screens_test.dart' as blog;

class Device extends DeviceRepository {
  NotificationPreferenceModel prefs = const NotificationPreferenceModel(
    categoryIds: ['keep-category'],
    breakingNews: false,
  );
  @override
  Future<NotificationPreferenceModel> getPreferences() async => prefs;
  @override
  Future<bool> updatePreferences(NotificationPreferenceModel value) async {
    prefs = value;
    return false;
  }
}

class Taxonomy extends TaxonomyRepository {
  @override
  Future<List<CategoryModel>> getCategories({
    bool forceRefresh = false,
  }) async => const [
    CategoryModel(
      id: 'legacy-blog',
      name: 'Yalnız Blog Konusu',
      slug: 'legacy-blog',
      contentTypes: ['blog'],
    ),
    CategoryModel(
      id: 'root',
      name: 'Ana Haber Kategorisi',
      slug: 'root',
      children: [
        CategoryModel(
          id: 'child',
          name: 'Alt Haber Kategorisi',
          slug: 'child',
          parentId: 'root',
        ),
      ],
    ),
  ];
}

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  double width = 390,
  double scale = 1,
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
      onGenerateRoute: (settings) => NewsNavigation.generate(
        settings,
        repository: news.FakeNews(),
        taxonomy: Taxonomy(),
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'home limits every visible news section and hides missing market/video modules',
    (tester) async {
      final items = List.generate(20, news.news);
      await home.pumpHome(
        tester,
        home: HomeModel(latest: items, featured: items, mostRead: items),
      );
      final grids = tester.widgetList<GridView>(find.byType(GridView)).toList();
      expect(grids.length, 3);
      for (final grid in grids) {
        expect(
          (grid.childrenDelegate as SliverChildBuilderDelegate).childCount,
          4,
        );
      }
      expect(find.text('Video Haberler'), findsNothing);
      expect(find.text('Piyasalar'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ticker advances after five seconds, supports swipe and opens the active article',
    (tester) async {
      final actions = <Object?>[];
      await home.pumpHome(
        tester,
        home: HomeModel(breaking: [news.news(1), news.news(2)]),
        onAction: (action, payload) {
          if (action == HomeAction.news) actions.add(payload);
        },
      );
      final ticker = find.byType(PageView).first;
      final controller = tester.widget<PageView>(ticker).controller!;
      expect(controller.page, 0);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.page, 1);
      await tester.tap(find.text('API haber başlığı 2'));
      expect(actions.single, news.news(2));
      await tester.drag(ticker, const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'news and blog domains stay separate and hierarchy reveals one step at a time',
    (tester) async {
      await pump(
        tester,
        NewsCategoryExplorerScreen(
          taxonomy: Taxonomy(),
          blogRepository: blog.FakeBlog(),
        ),
      );
      expect(find.text('Ana Haber Kategorisi'), findsOneWidget);
      expect(find.text('Yalnız Blog Konusu'), findsNothing);
      expect(find.text('Alt Haber Kategorisi'), findsNothing);
      await tester.tap(find.text('Ana Haber Kategorisi'));
      await tester.pumpAndSettle();
      expect(find.text('Alt Haber Kategorisi'), findsOneWidget);
      await tester.tap(find.text('Bilgi Köşesi'));
      await tester.pumpAndSettle();
      expect(find.text('Alt Haber Kategorisi'), findsNothing);
      expect(find.byKey(const ValueKey('blog-category-list')), findsOneWidget);
      final root = blog.roots().firstWhere((item) => item.children.isNotEmpty);
      await tester.tap(find.byKey(ValueKey('blog-select-${root.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('blog-parent-feed')), findsOneWidget);
    },
  );

  testWidgets(
    'city selection persists canonical IDs while preserving other preferences',
    (tester) async {
      final device = Device();
      final repo = home.FakeNews();
      await pump(
        tester,
        CityScreen(device: device, taxonomy: home.FakeTaxonomy(), news: repo),
      );
      await tester.tap(find.byKey(ValueKey('province-${home.city.id}')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('district-${home.city.districts.first.id}')),
      );
      await tester.pumpAndSettle();
      expect(device.prefs.locationIds, [home.city.districts.first.id]);
      expect(device.prefs.categoryIds, ['keep-category']);
      expect(device.prefs.breakingNews, false);
      expect(repo.districtUsed, home.city.districts.first.slug);
      expect(find.byKey(const ValueKey('city-change')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        CityScreen(device: device, taxonomy: home.FakeTaxonomy(), news: repo),
      );
      expect(find.byKey(const ValueKey('city-change')), findsOneWidget);
      expect(find.text('Alanya / Antalya'), findsOneWidget);
    },
  );

  testWidgets('bottom video and submission routes are reachable', (
    tester,
  ) async {
    await pump(tester, const VideoScreen());
    expect(find.text('Henüz video haberi bulunmuyor'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-nav-2')));
    await tester.pumpAndSettle();
    expect(find.byType(NewsSubmitScreen), findsOneWidget);
    expect(find.textContaining('henüz bağlı değil'), findsNothing);
  });

  for (final width in [360.0, 390.0, 411.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'category grid $width at text scale $scale has two lazy columns without overflow',
        (tester) async {
          final repo = news.FakeNews();
          await news.pumpScreen(
            tester,
            repo,
            NewsFeedMode.categories,
            selected: news.category,
            width: width,
            scale: scale,
          );
          final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
          expect(
            (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
                .crossAxisCount,
            2,
          );
          expect(
            find.byType(CompactNewsGridCard).evaluate().length,
            lessThan(15),
          );
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'category domains $width at text scale $scale remain usable',
        (tester) async {
          await pump(
            tester,
            NewsCategoryExplorerScreen(
              taxonomy: Taxonomy(),
              blogRepository: blog.FakeBlog(),
            ),
            width: width,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Bilgi Köşesi'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
