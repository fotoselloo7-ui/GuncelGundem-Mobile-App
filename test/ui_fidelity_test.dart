import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/blog_article_model.dart';
import 'package:guncelgundem/data/models/blog_block_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/info_corner_model.dart';
import 'package:guncelgundem/features/blog/presentation/blog_block_renderer.dart';
import 'package:guncelgundem/features/blog/presentation/blog_category_explorer.dart';
import 'package:guncelgundem/features/blog/presentation/blog_detail_screen.dart';
import 'package:guncelgundem/features/blog/presentation/blog_feed_screen.dart';
import 'package:guncelgundem/features/blog/presentation/blog_widgets.dart';
import 'package:guncelgundem/features/home/presentation/home_screen.dart';
import 'package:guncelgundem/features/home/presentation/home_widgets.dart';

import 'phase6cb/home_screen_test.dart' as home;
import 'phase6db/blog_screens_test.dart' as blog;

void main() {
  setUpAll(() async {
    final loader = FontLoader('Poppins');
    for (final file in [
      'Poppins-Regular.ttf',
      'Poppins-SemiBold.ttf',
      'Poppins-Bold.ttf',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/poppins/$file'));
    }
    await loader.load();
  });

  testWidgets(
    'Home hero advances real pages and bottom nav preserves five safe actions',
    (tester) async {
      final data = home.fixtureHome();
      final actions = <HomeAction>[];
      await home.pumpHome(
        tester,
        home: data,
        onAction: (action, _) => actions.add(action),
      );
      final hero = find.byKey(const ValueKey('home-hero'));
      final next = find.byKey(const ValueKey('home-hero-next'));
      expect(next, findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: hero, matching: find.text(data.hero[1].title)),
        findsOneWidget,
      );
      // Beş yuvanın tamamı ölçülür (dokunma hedefi >= 48dp).
      for (var i = 0; i < 5; i++) {
        final target = find.byKey(ValueKey('home-nav-$i'));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      // Yalnız Ana Sayfa'ya özel aksiyon üreten yuvalar dokunularak denenir;
      // 4. ve 5. yuva adlandırılmış rota açar (kapsamı home_screen_test'tedir)
      // ve dokunulursa Ana Sayfa ekrandan kalkacağı için ölçüm bozulurdu.
      for (var i = 0; i <= 2; i++) {
        await tester.tap(find.byKey(ValueKey('home-nav-$i')));
        await tester.pumpAndSettle();
      }
      expect(actions, [HomeAction.breaking, HomeAction.submitNews]);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('Video Haberler'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home blog cover binds its own real fixture URL to existing SVG renderer',
    (tester) async {
      final article = BlogArticleModel.fromJson(
        blog.fixture('list')['data']['items'][0] as Map<String, dynamic>,
      );
      expect(Uri.parse(article.coverUrl!).path, endsWith('.svg'));
      // Network is disabled in widget tests. Compile the actual server SVG fixture
      // into flutter_svg's cache under the real URL, without production overrides.
      final markup = File('test/fixtures/6db/analysis-featured.svg')
          .readAsStringSync();
      final bytes = await SvgStringLoader(markup).loadBytes(null);
      await svg.cache.putIfAbsent(
        SvgNetworkLoader(article.coverUrl!).cacheKey(null),
        () async => bytes,
      );
      await home.pumpHome(
        tester,
        home: HomeModel(
          infoCorner: InfoCornerModel(
            title: 'Bilgi Köşesi',
            featured: [article],
          ),
        ),
      );
      final card = find.byKey(const ValueKey('home-blog-0'));
      final widget = tester.widget<HomeArticleCard>(card);
      expect(widget.coverUrl, article.coverUrl);
      expect(widget.style, HomeCardStyle.editorial);
      expect((widget.cover as BlogImage).url, article.coverUrl);
      expect(
        find.descendant(of: card, matching: find.byType(SvgPicture)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    for (final kind in ['index', 'category', 'detail', 'explorer', 'table']) {
      testWidgets(
        '$kind 411px scale $scale remains vertically readable without overflow',
        (tester) async {
          final repo = blog.FakeBlog();
          final child = switch (kind) {
            'index' => BlogFeedScreen(
              repository: repo,
              info: const InfoCornerModel(),
            ),
            'category' => BlogFeedScreen(
              repository: repo,
              selection: BlogCategorySelection(
                blog.roots().first.children.first,
                parent: blog.roots().first,
              ),
            ),
            'detail' => BlogDetailScreen(identifier: 'slug', repository: repo),
            'explorer' => Scaffold(
              body: BlogCategoryExplorer(repository: repo),
            ),
            _ => BlogShell(
              body: SingleChildScrollView(
                child: BlogBlockView(
                  block: TableBlogBlock(
                    headers: List.filled(6, 'Uzun başlık'),
                    rows: [List.filled(6, 'Uzun hücre içeriği')],
                  ),
                  onLink: (_) async {},
                ),
              ),
            ),
          };
          await blog.pump(tester, child, repo, width: 411, scale: scale);
          await tester.pumpAndSettle();
          for (var i = 0; i < 20; i++) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
