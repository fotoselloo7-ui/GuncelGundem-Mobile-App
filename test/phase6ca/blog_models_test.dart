import 'package:flutter_test/flutter_test.dart';
import 'package:guncelgundem/data/models/blog_article_model.dart';
import 'package:guncelgundem/data/models/blog_block_model.dart';
import 'package:guncelgundem/data/models/blog_category_model.dart';
import 'package:guncelgundem/data/models/home_model.dart';
import 'package:guncelgundem/data/models/home_view_model.dart';
import 'package:guncelgundem/data/models/info_corner_model.dart';
import 'package:guncelgundem/data/models/location_model.dart';
import 'package:guncelgundem/data/models/news_block_model.dart';

import 'contract_fixtures.dart';

void main() {
  test('live home contract includes backend title and typed blog slots', () {
    final raw = fixture('home');
    final home = HomeModel.fromJson(raw);
    expect(home.infoCorner!.title, raw['info_corner']['title']);
    expect(home.infoCorner!.featured, isNotEmpty);
    expect(home.infoCorner!.latest, isNotEmpty);
    expect(home.infoCorner!.categories, isNotEmpty);
    expect(HomeModel.fromJson(home.toJson()), home);
  });
  test('legacy home news parsing is unchanged when info_corner is missing', () {
    final raw = fixture('home')..remove('info_corner');
    final home = HomeModel.fromJson(raw);
    expect(home.infoCorner, isNull);
    expect(home.breaking.length, (raw['breaking'] as List).length);
    expect(home.hero.first.title, raw['hero'][0]['title']);
    expect(
      home.categorySections.length,
      (raw['category_sections'] as List).length,
    );
    expect(home.latest.length, (raw['latest'] as List).length);
    expect(HomeModel.fromJson(home.toJson()), home);
  });
  test('missing and malformed info_corner are backward compatible', () {
    expect(HomeModel.fromJson({'info_corner': null}).infoCorner, isNull);
    expect(HomeModel.fromJson({'info_corner': []}).infoCorner, isNull);
    final info = InfoCornerModel.fromJson({
      'title': null,
      'featured': 'bad',
      'latest': [null],
      'categories': null,
    });
    expect(info.title, isEmpty); // No hard-coded display title.
    expect(info.featured, isEmpty);
    expect(info.latest, isEmpty);
  });
  test('blog list uses data.items and nested pagination, not news meta', () {
    final raw = fixture('blog_list');
    final page = BlogPageModel.fromJson(raw);
    expect(page.items.length, (raw['items'] as List).length);
    expect(page.page, raw['pagination']['current_page']);
    expect(page.perPage, raw['pagination']['per_page']);
    expect(page.totalItems, raw['pagination']['total_items']);
    expect(page.hasMore, raw['pagination']['has_more']);
    expect(BlogPageModel.fromJson(page.toJson()), page);
  });
  test(
    'blog detail parses live body.blocks and absent category/author/recipe',
    () {
      final detail = BlogArticleModel.fromJson(fixture('blog_detail'));
      expect(detail.blocks, isNotEmpty);
      expect(detail.publishedAt, isNotNull);
      expect(detail.canonicalUrl, contains('/blog/'));
      expect(detail.category, isNull);
      expect(detail.author, isNull);
      expect(detail.schemaRecipe, isNull);
      final fact = detail.blocks.whereType<FactboxBlogBlock>().single;
      expect(fact.title, isNotEmpty);
      expect(fact.text, isNull); // Actual backend currently omits factbox.text.
      expect(BlogArticleModel.fromJson(detail.toJson()), detail);
    },
  );
  test('blog category endpoint retains category metadata and items', () {
    final page = BlogPageModel.fromJson(fixture('blog_category'));
    expect(page.category!.slug, 'corbalar');
    expect(page.items, isNotEmpty);
    expect(BlogPageModel.fromJson(page.toJson()), page);
  });
  test('nullable and wrong optional field types do not crash the article', () {
    final article = BlogArticleModel.fromJson({
      'id': 42,
      'title': null,
      'authors': [
        null,
        {'name': true},
      ],
      'published_at': 'invalid',
      'categories': 'bad',
      'reading_time': '4',
      'schema_recipe': [],
      'body': {
        'blocks': [
          null,
          {'type': 'paragraph', 'text': []},
        ],
      },
    });
    expect(article.id, '42');
    expect(article.title, isEmpty);
    expect(article.publishedAt, isNull);
    expect(article.readingTime, 4);
    expect(article.categories, isEmpty);
    expect(article.blocks.single, isA<StandardBlogBlock>());
    expect(BlogArticleModel.fromJson({}).blocks, isEmpty);
  });
  test('18 roots and 230 children parse with correct parent IDs', () {
    final tree = BlogCategoryTreeModel.fromJson(fixture('blog_categories'));
    expect(tree.roots.length, 18);
    expect(tree.roots.expand((r) => r.children).length, 230);
    for (final root in tree.roots) {
      expect(root.parentId, isNull);
      for (final child in root.children) {
        expect(child.parentId, root.id);
        expect(child.canonicalUrl, contains('/${root.slug}/'));
      }
    }
    expect(BlogCategoryTreeModel.fromJson(tree.toJson()), tree);
  });
  test('category envelope supports categories/tree and list snapshots', () {
    final root = {'id': 'root', 'slug': 'root', 'name': 'Root'};
    expect(
      BlogCategoryTreeModel.fromJson({
        'categories': [root],
      }).roots.length,
      1,
    );
    expect(BlogCategoryTreeModel.fromJson([root]).roots.single.id, 'root');
    expect(BlogCategoryTreeModel.fromJson(null).roots, isEmpty);
  });
  test('child parent fallback, optional icon keys and nullable fields', () {
    final root = BlogCategoryModel.fromJson({
      'id': 'parent',
      'icon_key': 'soup',
      'children': [
        null,
        {'id': 'child', 'article_count': '2'},
      ],
    });
    expect(root.children.single.parentId, 'parent');
    expect(root.children.single.articleCount, 2);
    expect(root.iconKey, 'soup');
    expect(root.coverUrl, isNull);
  });
  test(
    'blog category and subcategory remain separate from news categories',
    () {
      final article = BlogArticleModel.fromJson({
        'category': {'id': 'root'},
        'subcategory': {'id': 'child', 'parent_id': 'root'},
      });
      expect(article.category, isA<BlogCategoryModel>());
      expect(article.subcategory!.parentId, article.category!.id);
    },
  );
  test('table headers, rows, numeric/null cells and optional HTML', () {
    final table = BlogBlockModel.fromJson({
      'type': 'table',
      'headers': ['A', 'B'],
      'rows': [
        ['x', 2],
        [null, 'y'],
        null,
      ],
      'html': '<table></table>',
    }) as TableBlogBlock;
    expect(table.rows, [
      ['x', '2'],
      ['', 'y'],
    ]);
    expect(table.headers, ['A', 'B']);
    expect(table.html, '<table></table>');
    expect(BlogBlockModel.fromJson(table.toJson()), table);
    expect(
      (BlogBlockModel.fromJson({'type': 'table'}) as TableBlogBlock).rows,
      isEmpty,
    );
  });
  test('factbox supports title/text and current backend items format', () {
    final fact = BlogBlockModel.fromJson({
      'type': 'factbox',
      'title': 'İpucu',
      'text': 'Metin',
      'items': ['Bir', 'İki'],
    }) as FactboxBlogBlock;
    expect(fact.text, 'Metin');
    expect(fact.items.length, 2);
    expect(BlogBlockModel.fromJson(fact.toJson()), fact);
  });
  test('root schema_recipe parses every requested recipe field', () {
    final recipe = BlogArticleModel.fromJson({'schema_recipe': recipeFixture})
        .schemaRecipe!;
    expect(recipe.recipeName, 'Mercimek Çorbası');
    expect(recipe.prepTime, 'PT10M');
    expect(recipe.cookTime, 'PT30M');
    expect(recipe.totalTime, 'PT40M');
    expect(recipe.servings, '6');
    expect(recipe.difficulty, 'Kolay');
    expect(recipe.ingredients.length, 2);
    expect(recipe.instructions.length, 2);
  });
  test(
    'current recipe alias, missing metadata and malformed arrays are safe',
    () {
      expect(
        BlogArticleModel.fromJson({'recipe': recipeFixture}).recipe,
        isNotNull,
      );
      final recipe = BlogArticleModel.fromJson({
        'recipe': {
          'ingredients': null,
          'instructions': [
            {'text': 'Pişir'},
            null,
          ],
        },
      }).recipe!;
      expect(recipe.ingredients, isEmpty);
      expect(recipe.instructions, ['Pişir', '']);
    },
  );
  test(
    'known blocks reuse existing models and future blocks preserve raw JSON',
    () {
      final paragraph = BlogBlockModel.fromJson({
        'type': 'paragraph',
        'text': 'Metin',
      }) as StandardBlogBlock;
      expect(paragraph.block, isA<ParagraphNewsBlock>());
      final unknown = BlogBlockModel.fromJson({
        'type': 'future',
        'custom': 'saved',
      });
      expect(unknown.toJson()['custom'], 'saved');
    },
  );
  test(
    'article cache round trip preserves recipe, authors and all special blocks',
    () {
      final article = BlogArticleModel.fromJson({
        'id': 'blog',
        'author': {'name': 'Yazar'},
        'schema_recipe': recipeFixture,
        'blocks': [
          {
            'type': 'table',
            'headers': ['A'],
            'rows': [
              ['B'],
            ],
          },
          {'type': 'factbox', 'title': 'T', 'text': 'X'},
        ],
      });
      expect(article.author!.name, 'Yazar');
      expect(BlogArticleModel.fromJson(article.toJson()), article);
    },
  );
  test(
    '6C-B view model offers data slots without fabricating missing home data',
    () {
      final home = HomeModel.fromJson(fixture('home'));
      final view = HomeViewModel(
        home: home,
        city: const LocationSnippetModel(
          id: 'loc_prov_antalya',
          name: 'Antalya',
          slug: 'antalya',
        ),
        local: home.latest,
        video: home.featured,
      );
      expect(view.locationId, 'loc_prov_antalya');
      expect(view.breaking, home.breaking);
      expect(view.hero, home.hero);
      expect(view.newsSections, home.categorySections);
      expect(view.infoCorner, home.infoCorner);
      expect(view.local, home.latest);
      expect(view.video, home.featured);
      expect(view.ads, isEmpty);
      expect(HomeViewModel(home: home).city, isNull);
    },
  );
}
