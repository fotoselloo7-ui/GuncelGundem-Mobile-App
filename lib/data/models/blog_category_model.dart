import 'package:equatable/equatable.dart';

import 'blog_json.dart';

/// Blog taxonomy is deliberately independent of news CategoryModel.
class BlogCategoryModel extends Equatable {
  final String id;
  final String? parentId;
  final String name;
  final String slug;
  final String description;
  final String? icon;
  final String? iconKey;
  final String? coverUrl;
  final String? canonicalUrl;
  final int articleCount;
  final List<BlogCategoryModel> children;

  const BlogCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.description = '',
    this.icon,
    this.iconKey,
    this.coverUrl,
    this.canonicalUrl,
    this.articleCount = 0,
    this.children = const [],
  });

  factory BlogCategoryModel.fromJson(
    Map<String, dynamic> json, {
    String? parentId,
  }) {
    final id = BlogJson.string(json['id']) ?? '';
    return BlogCategoryModel(
      id: id,
      parentId: BlogJson.string(json['parent_id']) ?? parentId,
      name: BlogJson.string(json['name']) ?? '',
      slug: BlogJson.string(json['slug']) ?? '',
      description: BlogJson.string(json['description']) ?? '',
      icon: BlogJson.string(json['icon']),
      iconKey: BlogJson.string(json['icon_key']),
      coverUrl: BlogJson.string(json['cover_url']),
      canonicalUrl: BlogJson.string(json['canonical_url']),
      articleCount: BlogJson.integer(json['article_count']),
      children: BlogJson.maps(json['children'])
          .map((c) => BlogCategoryModel.fromJson(c, parentId: id))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_id': parentId,
    'name': name,
    'slug': slug,
    'description': description,
    'icon': icon,
    'icon_key': iconKey,
    'cover_url': coverUrl,
    'canonical_url': canonicalUrl,
    'article_count': articleCount,
    'children': children.map((c) => c.toJson()).toList(),
  };

  @override
  List<Object?> get props => [
    id,
    parentId,
    name,
    slug,
    description,
    icon,
    iconKey,
    coverUrl,
    canonicalUrl,
    articleCount,
    children,
  ];
}

class BlogCategoryTreeModel extends Equatable {
  final List<BlogCategoryModel> roots;
  const BlogCategoryTreeModel({this.roots = const []});

  factory BlogCategoryTreeModel.fromJson(dynamic json) {
    final map = BlogJson.map(json);
    final raw = json is List ? json : (map['tree'] ?? map['categories']);
    return BlogCategoryTreeModel(
      roots: BlogJson.maps(raw)
          .map((c) => BlogCategoryModel.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'categories': roots.map((c) => c.toJson()).toList(),
  };
  @override
  List<Object?> get props => [roots];
}
