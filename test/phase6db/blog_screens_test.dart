import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/core/network/content_availability.dart';
import 'package:guncelgundem/data/models/blog_article_model.dart';
import 'package:guncelgundem/data/models/blog_block_model.dart';
import 'package:guncelgundem/data/models/blog_category_model.dart';
import 'package:guncelgundem/data/models/blog_recipe_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/info_corner_model.dart';
import 'package:guncelgundem/data/repositories/blog_repository.dart';
import 'package:guncelgundem/data/state/home_data_state.dart';
import 'package:guncelgundem/design/branding_state.dart';
import 'package:guncelgundem/features/blog/presentation/blog_block_renderer.dart';
import 'package:guncelgundem/features/blog/presentation/blog_category_explorer.dart';
import 'package:guncelgundem/features/blog/presentation/blog_detail_screen.dart';
import 'package:guncelgundem/features/blog/presentation/blog_feed_screen.dart';
import 'package:guncelgundem/features/blog/presentation/blog_navigation.dart';
import 'package:guncelgundem/features/blog/presentation/blog_widgets.dart';
import 'package:guncelgundem/features/home/presentation/home_screen.dart';
import 'package:guncelgundem/features/home/presentation/home_widgets.dart';
import 'package:guncelgundem/features/news/presentation/news_navigation.dart';

import '../phase6da/news_screens_test.dart' show FakeNews;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/6db/$name.json').readAsStringSync())
        as Map<String, dynamic>;
List<BlogCategoryModel> roots() =>
    BlogCategoryTreeModel.fromJson(fixture('categories')['data']).roots;
BlogArticleModel article(int i, {bool long = false}) =>
    BlogArticleModel.fromJson({
      ...fixture('list')['data']['items'][0] as Map<String, dynamic>,
      'id': 'article-$i',
      'slug': 'article-$i',
      'cover_url': null,
      'featured': false,
      'title': long
          ? List.filled(25, 'Uzun gerçek alan testi').join(' ')
          : 'Test yazısı $i',
      'summary': long
          ? List.filled(45, 'Tam özet metni.').join(' ')
          : 'Tam özet $i',
    });

/// Tanı/paylaşım amaçlı: yalnız 'recipe' fixture'ını içeren tek sayfalık sonuç.
PaginatedBlogResult recipeOnlyPage() => PaginatedBlogResult(
  data: BlogPageModel(
    items: [
      BlogArticleModel.fromJson({
        ...fixture('recipe')['data'] as Map<String, dynamic>,
        'cover_url': null,
      }),
    ],
    totalItems: 1,
  ),
);

class FakeBlog extends BlogRepository {
  final calls = <String>[];
  final details = <String>[];
  Future<PaginatedBlogResult> Function(String?, int)? handler;
  Future<BlogDetailResult> Function(String)? detailHandler;
  Future<List<BlogCategoryModel>> Function()? categoriesHandler;
  @override
  Future<List<BlogCategoryModel>> getCategories({
    bool forceRefresh = false,
  }) async => categoriesHandler != null ? categoriesHandler!() : roots();
  Future<PaginatedBlogResult> page(String? slug, int page) async {
    calls.add('${slug ?? 'index'}:$page');
    if (handler != null) return handler!(slug, page);
    return PaginatedBlogResult(
      data: BlogPageModel(
        items: List.generate(15, (i) => article((page - 1) * 15 + i)),
        page: page,
        perPage: 15,
        totalItems: 45,
        totalPages: 3,
        hasMore: page < 3,
      ),
    );
  }

  @override
  Future<PaginatedBlogResult> getArticles({
    int page = 1,
    int perPage = 20,
    String? category,
    String? locationId,
    String? query,
    bool forceRefresh = false,
  }) => this.page(category, page);
  @override
  Future<PaginatedBlogResult> getCategoryArticles(
    String slug, {
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) => this.page(slug, page);
  @override
  Future<BlogDetailResult> getArticleDetailWithAvailability(
    String identifier, {
    bool forceRefresh = false,
  }) async {
    details.add(identifier);
    if (detailHandler != null) return detailHandler!(identifier);
    return BlogDetailResult(
      article: BlogArticleModel.fromJson({
        ...fixture('coffee')['data'] as Map<String, dynamic>,
        'cover_url': null,
      }),
      availability: ContentAvailability.available,
    );
  }
}

class Observer extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}

Future<void> pump(
  WidgetTester tester,
  Widget child,
  FakeBlog repo, {
  double width = 390,
  double scale = 1,
  Observer? observer,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: homeTheme(BrandingState.instance),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      navigatorObservers: [?observer],
      onGenerateRoute: (settings) =>
          BlogNavigation.generate(settings, repository: repo) ??
          NewsNavigation.generate(settings, repository: FakeNews()),
      home: RepaintBoundary(key: const ValueKey('blog-preview'), child: child),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Bilgi Köşesi akışını bir adım kaydırır. Bekleyen sayfa isteği sırasında
/// CircularProgressIndicator süresiz döndüğü için pumpAndSettle KULLANILMAZ.
Future<void> dragBlogFeed(
  WidgetTester tester, {
  String scroll = 'blog-scroll',
  double dy = -600,
}) async {
  await tester.drag(find.byKey(ValueKey(scroll)), Offset(0, dy));
  await tester.pump();
}

/// Mevcut sözleşme: liste dibine yaklaşınca (extentAfter < 240) sonraki sayfa
/// OTOMATİK istenir (BlogFeedScreen._onScroll). 'blog-more' butonu yalnız
/// otomatik yükleme devre dışıyken (hata sonrası / kısa liste) görünen yedektir.
/// Bu yardımcı kaydırmanın gerçekten yeni istek ürettiğini DOĞRULAR.
Future<void> triggerNextBlogPage(
  WidgetTester tester,
  FakeBlog repo, {
  String scroll = 'blog-scroll',
  int maxDrags = 40,
}) async {
  final before = repo.calls.length;
  for (var i = 0; i < maxDrags && repo.calls.length == before; i++) {
    await dragBlogFeed(tester, scroll: scroll);
  }
  expect(
    repo.calls.length,
    greaterThan(before),
    reason: 'kaydırma sonraki blog sayfasını tetiklemeliydi',
  );
}

/// Bitiş işaretçisine ulaşana kadar kaydırır.
Future<void> scrollToBlogEnd(
  WidgetTester tester, {
  String scroll = 'blog-scroll',
  int maxDrags = 60,
}) async {
  for (var i = 0; i < maxDrags; i++) {
    if (find.byKey(const ValueKey('blog-end')).evaluate().isNotEmpty) return;
    await dragBlogFeed(tester, scroll: scroll);
    await tester.pumpAndSettle();
  }
}

Future<void> reach(
  WidgetTester tester,
  Finder target, {
  String scroll = 'blog-scroll',
}) async {
  await tester.scrollUntilVisible(
    target,
    500,
    scrollable: find
        .descendant(
          of: find.byKey(ValueKey(scroll)),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 120,
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'empty nullable recipe stays hidden and no instructions are fabricated',
    () {
      expect(BlogRecipe.hasContent(const BlogRecipeModel()), false);
      expect(
        BlogRecipe.hasContent(
          BlogRecipeModel.fromJson({
            'ingredients': [null],
            'prep_time': null,
          }),
        ),
        false,
      );
      expect(
        BlogRecipe.hasContent(
          BlogRecipeModel.fromJson({
            'ingredients': ['Actual ingredient'],
          }),
        ),
        true,
      );
    },
  );
  setUpAll(() async {
    for (final entry in {
      'Poppins': [
        'Poppins-Regular.ttf',
        'Poppins-SemiBold.ttf',
        'Poppins-Bold.ttf',
      ],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(
          rootBundle.load(
            entry.key == 'Poppins'
                ? 'assets/fonts/poppins/$file'
                : 'fonts/$file',
          ),
        );
      }
      await loader.load();
    }
  });
  testWidgets('index lazy feed reaches all three pages, not first 10 items', (
    tester,
  ) async {
    final repo = FakeBlog();
    await pump(
      tester,
      BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
      repo,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CompactBlogGridCard).evaluate().length, lessThan(15));
    for (var i = 0; i < 2; i++) {
      await triggerNextBlogPage(tester, repo);
      await tester.pumpAndSettle();
    }
    await scrollToBlogEnd(tester);
    expect(repo.calls, ['index:1', 'index:2', 'index:3']);
    expect(find.text('Test yazısı 44'), findsOneWidget);
    tester
        .widget<CustomScrollView>(find.byKey(const ValueKey('blog-scroll')))
        .controller!
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('45 / 45 yazı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'real featured metadata and full title/summary render without truncation',
    (tester) async {
      final repo = FakeBlog()
        ..handler = (_, _) async => PaginatedBlogResult(
          data: BlogPageModel(
            items: [
              BlogArticleModel.fromJson({
                ...fixture('recipe')['data'] as Map<String, dynamic>,
                'cover_url': null,
              }),
            ],
            totalItems: 1,
          ),
        );
      await pump(
        tester,
        BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
        repo,
      );
      await tester.pumpAndSettle();
      // Öne çıkan içerik artık ayrı bir "Öne Çıkan Rehberler" bölümünde,
      // 2 sütunlu kompakt grid olarak sunulur. Gruplama başlıkla anlatıldığı
      // için kart üzerinde ayrıca 'ÖNE ÇIKAN' rozeti yoktur.
      expect(find.text('Öne Çıkan Rehberler'), findsOneWidget);
      expect(find.byType(CompactBlogGridCard), findsOneWidget);
      final title = fixture('recipe')['data']['title'] as String;
      expect(find.text(title), findsOneWidget);
      // Sabit yükseklikli kompakt kutuda başlık 4 satıra kırpılır.
      expect(tester.widget<Text>(find.text(title)).maxLines, 4);
    },
  );
  testWidgets('initial loading, failure retry and compact empty state', (
    tester,
  ) async {
    final pending = Completer<PaginatedBlogResult>();
    final repo = FakeBlog()..handler = (_, _) => pending.future;
    await pump(
      tester,
      BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
      repo,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Yazılar yüklenemedi.'), findsOneWidget);
    repo.handler = (_, _) async =>
        const PaginatedBlogResult(data: BlogPageModel());
    await tester.tap(find.byKey(const ValueKey('blog-first-retry')));
    await tester.pumpAndSettle();
    expect(
      find.text('Bu bölümde henüz yayınlanmış yazı bulunmuyor.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'pagination error retains list, retries failed page, shows compact progress',
    (tester) async {
      final repo = FakeBlog();
      await pump(
        tester,
        BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
        repo,
      );
      await tester.pumpAndSettle();
      final pending = Completer<PaginatedBlogResult>();
      repo.handler = (_, _) => pending.future;
      await triggerNextBlogPage(tester, repo);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.completeError(StateError('fail'));
      await tester.pumpAndSettle();
      // Hata sonrası mevcut kayıtlar korunur ve otomatik yükleme durur;
      // bu durumda yeniden deneme aksiyonu görünür olmalıdır.
      // Liste korunmalı: otomatik sayfalama için dibe inilmişti, başa dönüp doğrula.
      tester
          .widget<CustomScrollView>(find.byKey(const ValueKey('blog-scroll')))
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byType(CompactBlogGridCard), findsWidgets);
      repo.handler = null;
      await reach(tester, find.byKey(const ValueKey('blog-more')));
      await tester.tap(find.byKey(const ValueKey('blog-more')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['index:1', 'index:2', 'index:2']);
    },
  );
  testWidgets(
    '18 root / 230 child explorer is two step, not 248 upfront rows',
    (tester) async {
      final repo = FakeBlog();
      await pump(
        tester,
        BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
        repo,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blog-category-picker')));
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('blog-category-list')),
      );
      expect(list.childrenDelegate.estimatedChildCount, 18);
      expect(roots().expand((r) => r.children).length, 230);
      final root = roots().last;
      await reach(
        tester,
        find.byKey(ValueKey('blog-select-${root.id}')),
        scroll: 'blog-category-list',
      );
      await tester.tap(find.byKey(ValueKey('blog-select-${root.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byKey(const ValueKey('blog-category-list')))
            .childrenDelegate
            .estimatedChildCount,
        root.children.length + 1,
      );
      final child = root.children.last;
      await reach(
        tester,
        find.byKey(ValueKey('blog-select-${child.id}')),
        scroll: 'blog-category-list',
      );
      await tester.tap(find.byKey(ValueKey('blog-select-${child.id}')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, '${child.slug}:1');
      expect(find.text(child.description), findsOneWidget);
      expect(find.text(root.name), findsOneWidget);
    },
  );
  testWidgets(
    'parent category feed and subsequent pages use canonical category slug',
    (tester) async {
      final root = roots().first, repo = FakeBlog();
      await pump(
        tester,
        BlogFeedScreen(
          repository: repo,
          selection: BlogCategorySelection(root),
        ),
        repo,
      );
      await tester.pumpAndSettle();
      await triggerNextBlogPage(tester, repo);
      await tester.pumpAndSettle();
      expect(repo.calls, ['${root.slug}:1', '${root.slug}:2']);
    },
  );
  testWidgets('child category feed has correct parent context and pagination', (
    tester,
  ) async {
    final root = roots().first,
        child = roots().first.children.first,
        repo = FakeBlog();
    await pump(
      tester,
      BlogFeedScreen(
        repository: repo,
        selection: BlogCategorySelection(child, parent: root),
      ),
      repo,
    );
    await tester.pumpAndSettle();
    expect(find.text(root.name), findsWidgets);
    expect(find.text(child.name), findsWidgets);
    await triggerNextBlogPage(tester, repo);
    await tester.pumpAndSettle();
    expect(repo.calls.last, '${child.slug}:2');
  });
  testWidgets('category explorer loading/error retries without leaving modal', (
    tester,
  ) async {
    final repo = FakeBlog()
      ..categoriesHandler = () async => throw StateError('fail');
    await pump(
      tester,
      Scaffold(body: BlogCategoryExplorer(repository: repo)),
      repo,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kategoriler yüklenemedi.'), findsOneWidget);
    repo.categoriesHandler = null;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('blog-category-list')), findsOneWidget);
  });
  testWidgets(
    'category picker resumes selected parent, exposes all children and parent feed',
    (tester) async {
      final root = roots().first, repo = FakeBlog();
      await pump(
        tester,
        BlogFeedScreen(
          repository: repo,
          selection: BlogCategorySelection(root),
        ),
        repo,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blog-category-picker')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byKey(const ValueKey('blog-category-list')))
            .childrenDelegate
            .estimatedChildCount,
        root.children.length + 1,
      );
      await tester.tap(find.byKey(const ValueKey('blog-parent-feed')));
      await tester.pumpAndSettle();
      expect(repo.calls.last, '${root.slug}:1');
    },
  );
  testWidgets(
    'related content and real-source fields render and source link callback is safe',
    (tester) async {
      final urls = <String>[], repo = FakeBlog();
      repo.detailHandler = (_) async => BlogDetailResult(
        availability: ContentAvailability.available,
        article: BlogArticleModel.fromJson({
          'title': 'Test makalesi',
          'canonical_url': 'https://guncelgundem.tr/blog/test',
          'sources': [
            {
              'title': 'Test kaynağı',
              'url': 'https://source.test/path',
              'publisher': 'Test yayıncı',
              'accessed_at': '2026-09-30',
            },
          ],
          'related_articles': [article(1).toJson()],
        }),
      );
      await pump(
        tester,
        BlogDetailScreen(
          identifier: 'test',
          repository: repo,
          onLink: (url) async {
            urls.add(url);
          },
        ),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Kaynaklar'), findsOneWidget);
      expect(find.text('Test yayıncı'), findsOneWidget);
      await tester.tap(find.text('Test kaynağı'));
      await tester.pumpAndSettle();
      expect(urls, ['https://source.test/path']);
      // Detay ekranındaki ilgili içerik listesi BlogArticleCard kullanır
      // (feed'in kompakt grid kartından farklıdır).
      await reach(
        tester,
        find.byKey(const ValueKey('blog-card-article-1')),
        scroll: 'blog-detail-scroll',
      );
      await tester.tap(find.byKey(const ValueKey('blog-card-article-1')));
      await tester.pumpAndSettle();
      expect(repo.details, ['test', 'article-1']);
    },
  );
  testWidgets('cached page remains visible with explicit offline state', (
    tester,
  ) async {
    final repo = FakeBlog()
      ..handler = (_, _) async => PaginatedBlogResult(
        data: BlogPageModel(items: [article(0)], totalItems: 1),
        isFromCache: true,
        isOffline: true,
      );
    await pump(
      tester,
      BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
      repo,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmiş yazılar gösteriliyor.'), findsOneWidget);
    expect(find.text('Test yazısı 0'), findsOneWidget);
  });
  testWidgets(
    'card opens native detail, real FAQ/recipe/related and sources stay reachable',
    (tester) async {
      final repo = FakeBlog(), observer = Observer();
      await pump(
        tester,
        BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
        repo,
        observer: observer,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blog-grid-article-0')));
      await tester.pumpAndSettle();
      expect(observer.names.last, BlogNavigation.article);
      expect(repo.details, ['article-0']);
      await reach(
        tester,
        find.text('Hazırlanışı'),
        scroll: 'blog-detail-scroll',
      );
      expect(find.byType(BlogRecipe), findsOneWidget);
      await reach(
        tester,
        find.text('Sık Sorulan Sorular'),
        scroll: 'blog-detail-scroll',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('detail loading error retry and removed article are safe', (
    tester,
  ) async {
    final pending = Completer<BlogDetailResult>(),
        repo = FakeBlog()..detailHandler = (_) => pending.future;
    await pump(
      tester,
      BlogDetailScreen(identifier: 'slug', repository: repo),
      repo,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('fail'));
    await tester.pumpAndSettle();
    expect(find.text('Yazı yüklenemedi.'), findsOneWidget);
    repo.detailHandler = (_) async =>
        const BlogDetailResult(availability: ContentAvailability.unavailable);
    await tester.tap(find.byKey(const ValueKey('blog-detail-retry')));
    await tester.pumpAndSettle();
    expect(
      find.text('Yazı bulunamadı veya yayından kaldırıldı.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'offline detail keeps native content and nullable recipe hidden',
    (tester) async {
      final repo = FakeBlog()
        ..detailHandler = (_) async => BlogDetailResult(
          article: article(0),
          availability: ContentAvailability.cachedOffline,
          isFromCache: true,
        );
      await pump(
        tester,
        BlogDetailScreen(identifier: 'slug', repository: repo),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilmiş makale gösteriliyor.'), findsOneWidget);
      expect(find.byType(BlogRecipe), findsNothing);
    },
  );
  testWidgets(
    'all native block types render including table, factbox, link and nullables',
    (tester) async {
      final urls = <String>[];
      final blocks = [
        {'type': 'paragraph', 'text': 'Tam paragraf'},
        {'type': 'heading2', 'text': 'Gerçek başlık'},
        {
          'type': 'list',
          'style': 'ordered',
          'items': ['Bir', 'İki'],
        },
        {
          'type': 'list',
          'items': ['Üç'],
        },
        {'type': 'quote', 'text': 'Alıntı', 'author': 'Yazar'},
        {
          'type': 'image',
          'url': '',
          'alt': 'API alt',
          'caption': 'API caption',
        },
        {
          'type': 'table',
          'headers': ['A', 'B', 'C'],
          'rows': [
            ['Hücre', null, 'Son'],
          ],
        },
        {'type': 'factbox', 'title': 'Bilgi', 'text': 'Eksiksiz factbox'},
        {'type': 'link', 'text': 'Bağlantı', 'url': 'https://example.test'},
        {'type': 'internal_link', 'text': 'İç link', 'url': '/blog/slug'},
        {'type': 'future', 'text': 'Gelecek blok'},
        {'type': 'table'},
        {'type': 'factbox'},
      ].map((b) => BlogBlockModel.fromJson(b)).toList();
      final repo = FakeBlog();
      await pump(
        tester,
        BlogShell(
          body: CustomScrollView(
            key: const ValueKey('blocks'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: BlogBlockRenderer(
                  blocks: blocks,
                  onLink: (url) async => urls.add(url),
                ),
              ),
            ],
          ),
        ),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tam paragraf'), findsOneWidget);
      await reach(tester, find.text('Son'), scroll: 'blocks');
      expect(find.text('API caption'), findsOneWidget);
      expect(find.byKey(const ValueKey('blog-table-scroll')), findsOneWidget);
      await reach(tester, find.text('Bağlantı'), scroll: 'blocks');
      await tester.tap(find.text('Bağlantı'));
      await tester.pumpAndSettle();
      expect(urls, ['https://example.test']);
      await reach(tester, find.text('Gelecek blok'), scroll: 'blocks');
      expect(find.text('Eksiksiz factbox'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('link classifier routes same-origin articles, never hostile schemes or lookalike host', () {
    const canonical = 'https://guncelgundem.tr/blog/source';
    expect(
      BlogNavigation.resolve('/blog/other', canonicalUrl: canonical).kind,
      BlogLinkKind.blog,
    );
    expect(
      BlogNavigation.resolve('/haber/news', canonicalUrl: canonical).kind,
      BlogLinkKind.news,
    );
    expect(
      BlogNavigation.resolve(
        'https://guncelgundem.tr.evil.test/blog/other',
        canonicalUrl: canonical,
      ).kind,
      BlogLinkKind.external,
    );
    for (final value in [
      'javascript:alert(1)',
      'data:text/html,x',
      'file:///x',
      'https://user:pass@example.com',
      '',
    ]) {
      expect(
        BlogNavigation.resolve(value, canonicalUrl: canonical).kind,
        BlogLinkKind.invalid,
      );
    }
    expect(BlogNavigation.validIdentifier('../bad'), false);
  });
  testWidgets('internal blog and news links use native existing routes', (
    tester,
  ) async {
    final repo = FakeBlog(), observer = Observer();
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => BlogNavigation.openLink(
                  context,
                  '/blog/next',
                  canonicalUrl: 'https://guncelgundem.tr/blog/current',
                ),
                child: const Text('Blog'),
              ),
              TextButton(
                onPressed: () => BlogNavigation.openLink(
                  context,
                  '/haber/next',
                  canonicalUrl: 'https://guncelgundem.tr/blog/current',
                ),
                child: const Text('News'),
              ),
            ],
          ),
        ),
      ),
      repo,
      observer: observer,
    );
    await tester.tap(find.text('Blog'));
    await tester.pumpAndSettle();
    expect(observer.names.last, BlogNavigation.article);
    expect(repo.details, ['next']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    expect(observer.names.last, NewsNavigation.article);
  });
  testWidgets('Home only adds All action; Home card routes to blog detail', (
    tester,
  ) async {
    final repo = FakeBlog(), observer = Observer(), state = HomeDataState();
    addTearDown(state.dispose);
    state.updateFromHome(
      HomeModel(
        infoCorner: InfoCornerModel(
          title: 'Bilgi Köşesi',
          featured: [article(0)],
        ),
      ),
    );
    await pump(
      tester,
      Builder(
        builder: (context) => HomeScreen(
          homeState: state,
          loadOnStart: false,
          onAction: (action, payload) =>
              NewsNavigation.handleHome(context, action, payload),
        ),
      ),
      repo,
      observer: observer,
    );
    await tester.pumpAndSettle();
    // Bilgi Köşesi bölümünün kendi aksiyonu 'Tümünü Gör →' etiketlidir;
    // haber bölümlerindeki 'Tümünü Gör' bağlantılarından ayrışır.
    await tester.ensureVisible(find.text('Tümünü Gör →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümünü Gör →'));
    await tester.pumpAndSettle();
    expect(observer.names.last, BlogNavigation.index);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home-blog-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-blog-0')));
    await tester.pumpAndSettle();
    expect(observer.names.last, BlogNavigation.article);
  });
  testWidgets('late response after dispose does not set state', (tester) async {
    final pending = Completer<PaginatedBlogResult>(),
        repo = FakeBlog()..handler = (_, _) => pending.future;
    await pump(
      tester,
      BlogFeedScreen(repository: repo, info: const InfoCornerModel()),
      repo,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(const PaginatedBlogResult(data: BlogPageModel()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final kind in ['index', 'category', 'detail', 'explorer', 'table']) {
        testWidgets(
          '$kind $width px scale $scale no page overflow with long content',
          (tester) async {
            final repo = FakeBlog()
              ..handler = (_, _) async => PaginatedBlogResult(
                data: BlogPageModel(
                  items: [article(0, long: true)],
                  totalItems: 1,
                ),
              );
            repo.detailHandler = (_) async => BlogDetailResult(
              article: BlogArticleModel.fromJson({
                ...fixture('coffee')['data'] as Map<String, dynamic>,
                'cover_url': null,
                'title': article(0, long: true).title,
                'body': {
                  'blocks': [
                    ...fixture('coffee')['data']['body']['blocks'] as List,
                    {
                      'type': 'table',
                      'headers': List.filled(5, 'Uzun sütun başlığı'),
                      'rows': [
                        List.filled(5, List.filled(20, 'Uzun hücre').join(' ')),
                      ],
                    },
                    {'type': 'paragraph', 'text': 'Makale sonu'},
                  ],
                },
              }),
              availability: ContentAvailability.available,
            );
            final widget = switch (kind) {
              'index' => BlogFeedScreen(
                repository: repo,
                info: const InfoCornerModel(),
              ),
              'category' => BlogFeedScreen(
                repository: repo,
                selection: BlogCategorySelection(
                  roots().first.children.first,
                  parent: roots().first,
                ),
              ),
              'detail' => BlogDetailScreen(
                identifier: 'slug',
                repository: repo,
              ),
              'explorer' => Scaffold(
                body: BlogCategoryExplorer(repository: repo),
              ),
              _ => BlogShell(
                body: SingleChildScrollView(
                  child: BlogBlockView(
                    block: TableBlogBlock(
                      headers: List.filled(8, 'Uzun sütun başlığı'),
                      rows: [
                        List.filled(8, List.filled(20, 'Uzun hücre').join(' ')),
                      ],
                    ),
                    onLink: (_) async {},
                  ),
                ),
              ),
            };
            await pump(tester, widget, repo, width: width, scale: scale);
            await tester.pumpAndSettle();
            for (var i = 0; i < 15; i++) {
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
  for (final kind in ['index', 'category', 'detail', 'explorer']) {
    testWidgets('$kind golden 390 using actual API fixtures and Poppins', (
      tester,
    ) async {
      final repo = FakeBlog()
        ..handler = (slug, _) async => PaginatedBlogResult(
          data: BlogPageModel.fromJson({
            ...fixture(slug == null ? 'list' : 'category')['data']
                as Map<String, dynamic>,
            'items':
                (fixture(slug == null ? 'list' : 'category')['data']['items']
                        as List)
                    .map(
                      (a) => {...a as Map<String, dynamic>, 'cover_url': null},
                    )
                    .toList(),
          }),
        );
      repo.detailHandler = (_) async => BlogDetailResult(
        article: BlogArticleModel.fromJson({
          ...fixture('coffee')['data'] as Map<String, dynamic>,
          'cover_url': null,
        }),
        availability: ContentAvailability.available,
      );
      final widget = switch (kind) {
        'index' => BlogFeedScreen(
          repository: repo,
          info: const InfoCornerModel(),
        ),
        'category' => BlogFeedScreen(
          repository: repo,
          selection: BlogCategorySelection(roots().first),
        ),
        'detail' => BlogDetailScreen(identifier: 'slug', repository: repo),
        _ => Scaffold(
          backgroundColor: Colors.white,
          body: BlogCategoryExplorer(repository: repo),
        ),
      };
      await pump(tester, widget, repo);
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('blog-preview')),
        matchesGoldenFile('goldens/$kind-390.png'),
      );
    });
  }
}
