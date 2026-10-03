import 'package:equatable/equatable.dart';

/// Compact Kategori Özeti (Haber kartlarında primary_category veya categories içinde kullanılır)
class CategorySnippetModel extends Equatable {
  final String id;
  final String name;
  final String slug;

  const CategorySnippetModel({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory CategorySnippetModel.fromJson(Map<String, dynamic> json) {
    return CategorySnippetModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  @override
  List<Object?> get props => [id, name, slug];
}

/// Tam Kategori Modeli (Ağaç yapısı ve detay bilgileri)
class CategoryModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final int displayOrder;
  final bool isMenu;
  final bool isHomepage;
  final String? coverUrl;
  final String? canonicalUrl;
  final List<CategoryModel> children;
  final List<String> contentTypes;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.displayOrder = 50,
    this.isMenu = true,
    this.isHomepage = true,
    this.coverUrl,
    this.canonicalUrl,
    this.children = const [],
    this.contentTypes = const ['news', 'blog'],
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>?;
    final children = rawChildren != null
        ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map((c) => CategoryModel.fromJson(c))
              .toList()
        : const <CategoryModel>[];

    return CategoryModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      parentId: json['parent_id'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 50,
      isMenu: json['is_menu'] as bool? ?? true,
      isHomepage: json['is_homepage'] as bool? ?? true,
      coverUrl: json['cover_url'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
      children: children,
      contentTypes: json['content_types'] is List
          ? (json['content_types'] as List).whereType<String>().toList()
          : const ['news', 'blog'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'parent_id': parentId,
    'display_order': displayOrder,
    'is_menu': isMenu,
    'is_homepage': isHomepage,
    'cover_url': coverUrl,
    'canonical_url': canonicalUrl,
    'content_types': contentTypes,
    if (children.isNotEmpty)
      'children': children.map((c) => c.toJson()).toList(),
  };

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    parentId,
    displayOrder,
    isMenu,
    isHomepage,
    coverUrl,
    canonicalUrl,
    children,
    contentTypes,
  ];
}
