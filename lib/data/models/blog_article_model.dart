import 'package:equatable/equatable.dart';

import 'author_model.dart';
import 'blog_block_model.dart';
import 'blog_category_model.dart';
import 'blog_json.dart';
import 'blog_recipe_model.dart';

class BlogArticleModel extends Equatable {
  final String id;
  final String slug;
  final String title;
  final String summary;
  final String? coverUrl;
  final String? coverAlt;
  final String? coverCaption;
  final String? coverCredit;
  final bool featured;
  final List<AuthorModel> authors;
  final DateTime? publishedAt;
  final DateTime? modifiedAt;
  final int readingTime;
  final BlogCategoryModel? category;
  final BlogCategoryModel? subcategory;
  final List<BlogCategoryModel> categories;
  final String? canonicalUrl;
  final List<BlogBlockModel> blocks;
  final BlogRecipeModel? schemaRecipe;
  final String? directAnswerSummary;
  final List<String> keyTakeaways;
  final List<Map<String, dynamic>> faq;
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> topics;
  final List<Map<String, dynamic>> entities;
  final List<Map<String, dynamic>> locations;
  final List<BlogArticleModel> relatedArticles;

  const BlogArticleModel({
    this.id = '',
    this.slug = '',
    this.title = '',
    this.summary = '',
    this.coverUrl,
    this.coverAlt,
    this.coverCaption,
    this.coverCredit,
    this.featured = false,
    this.authors = const [],
    this.publishedAt,
    this.modifiedAt,
    this.readingTime = 0,
    this.category,
    this.subcategory,
    this.categories = const [],
    this.canonicalUrl,
    this.blocks = const [],
    this.schemaRecipe,
    this.directAnswerSummary,
    this.keyTakeaways = const [],
    this.faq = const [],
    this.sources = const [],
    this.tags = const [],
    this.topics = const [],
    this.entities = const [],
    this.locations = const [],
    this.relatedArticles = const [],
  });

  AuthorModel? get author => authors.isEmpty ? null : authors.first;
  BlogRecipeModel? get recipe => schemaRecipe;

  factory BlogArticleModel.fromJson(Map<String, dynamic> json) {
    BlogCategoryModel? parseCategory(dynamic raw) =>
        raw is Map<String, dynamic> ? BlogCategoryModel.fromJson(raw) : null;
    final rawAuthors = json['authors'] is List
        ? json['authors']
        : (json['author'] is Map<String, dynamic>
              ? [json['author']]
              : const []);
    final recipe = json['schema_recipe'] is Map<String, dynamic>
        ? json['schema_recipe']
        : json['recipe'];
    final rawBlocks = json['blocks'] ?? BlogJson.map(json['body'])['blocks'];
    return BlogArticleModel(
      id: BlogJson.string(json['id']) ?? '',
      slug: BlogJson.string(json['slug']) ?? '',
      title: BlogJson.string(json['title']) ?? '',
      summary: BlogJson.string(json['summary']) ?? '',
      coverUrl: BlogJson.string(json['cover_url'] ?? json['cover']),
      coverAlt: BlogJson.string(json['cover_alt']),
      coverCaption: BlogJson.string(json['cover_caption']),
      coverCredit: BlogJson.string(json['cover_credit']),
      featured: json['featured'] == true,
      authors: BlogJson.maps(rawAuthors)
          .map(
            (a) => AuthorModel.fromJson({
              for (final key in [
                'id',
                'name',
                'slug',
                'title',
                'bio',
                'avatar_url',
                'canonical_url',
              ])
                key: BlogJson.string(a[key]),
            }),
          )
          .toList(),
      publishedAt: DateTime.tryParse(
        BlogJson.string(json['published_at']) ?? '',
      ),
      modifiedAt: DateTime.tryParse(BlogJson.string(json['modified_at']) ?? ''),
      readingTime: BlogJson.integer(json['reading_time']),
      category: parseCategory(json['category'] ?? json['primary_category']),
      subcategory: parseCategory(json['subcategory']),
      categories: BlogJson.maps(json['categories'])
          .map((c) => BlogCategoryModel.fromJson(c))
          .toList(),
      canonicalUrl: BlogJson.string(json['canonical_url']),
      blocks: BlogJson.maps(rawBlocks)
          .map((b) => BlogBlockModel.fromJson(b))
          .toList(),
      schemaRecipe: recipe is Map<String, dynamic>
          ? BlogRecipeModel.fromJson(recipe)
          : null,
      directAnswerSummary: BlogJson.string(json['direct_answer_summary']),
      keyTakeaways: BlogJson.strings(json['key_takeaways']),
      faq: BlogJson.maps(json['faq']),
      sources: BlogJson.maps(json['sources']),
      tags: BlogJson.maps(json['tags']),
      topics: BlogJson.maps(json['topics']),
      entities: BlogJson.maps(json['entities']),
      locations: BlogJson.maps(json['locations']),
      relatedArticles: BlogJson.maps(json['related_articles'])
          .map((a) => BlogArticleModel.fromJson(a))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'summary': summary,
    'cover_url': coverUrl,
    'cover_alt': coverAlt,
    'cover_caption': coverCaption,
    'cover_credit': coverCredit,
    'featured': featured,
    'authors': authors.map((a) => a.toJson()).toList(),
    'published_at': publishedAt?.toIso8601String(),
    'modified_at': modifiedAt?.toIso8601String(),
    'reading_time': readingTime,
    'primary_category': category?.toJson(),
    'subcategory': subcategory?.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'canonical_url': canonicalUrl,
    'body': {
      'format': 'blocks',
      'blocks': blocks.map((b) => b.toJson()).toList(),
    },
    'schema_recipe': schemaRecipe?.toJson(),
    'direct_answer_summary': directAnswerSummary,
    'key_takeaways': keyTakeaways,
    'faq': faq,
    'sources': sources,
    'tags': tags,
    'topics': topics,
    'entities': entities,
    'locations': locations,
    'related_articles': relatedArticles.map((a) => a.toJson()).toList(),
  };
  @override
  List<Object?> get props => [
    id,
    slug,
    title,
    summary,
    coverUrl,
    coverAlt,
    coverCaption,
    coverCredit,
    featured,
    authors,
    publishedAt,
    modifiedAt,
    readingTime,
    category,
    subcategory,
    categories,
    canonicalUrl,
    blocks,
    schemaRecipe,
    directAnswerSummary,
    keyTakeaways,
    faq,
    sources,
    tags,
    topics,
    entities,
    locations,
    relatedArticles,
  ];
}

/// Blog pagination lives inside data.pagination, unlike news meta pagination.
class BlogPageModel extends Equatable {
  final List<BlogArticleModel> items;
  final BlogCategoryModel? category;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final bool hasMore;
  const BlogPageModel({
    this.items = const [],
    this.category,
    this.page = 1,
    this.perPage = 20,
    this.totalItems = 0,
    this.totalPages = 1,
    this.hasMore = false,
  });
  factory BlogPageModel.fromJson(dynamic json) {
    final data = BlogJson.map(json),
        p = BlogJson.map(BlogJson.map(json)['pagination']);
    return BlogPageModel(
      items: BlogJson.maps(json is List ? json : data['items'])
          .map((a) => BlogArticleModel.fromJson(a))
          .toList(),
      category: data['category'] is Map<String, dynamic>
          ? BlogCategoryModel.fromJson(data['category'])
          : null,
      page: BlogJson.integer(p['current_page'], 1),
      perPage: BlogJson.integer(p['per_page'], 20),
      totalItems: BlogJson.integer(p['total_items']),
      totalPages: BlogJson.integer(p['total_pages'], 1),
      hasMore: p['has_more'] is bool ? p['has_more'] : false,
    );
  }
  Map<String, dynamic> toJson() => {
    'items': items.map((a) => a.toJson()).toList(),
    if (category != null) 'category': category!.toJson(),
    'pagination': {
      'current_page': page,
      'per_page': perPage,
      'total_items': totalItems,
      'total_pages': totalPages,
      'has_more': hasMore,
    },
  };
  @override
  List<Object?> get props => [
    items,
    category,
    page,
    perPage,
    totalItems,
    totalPages,
    hasMore,
  ];
}
