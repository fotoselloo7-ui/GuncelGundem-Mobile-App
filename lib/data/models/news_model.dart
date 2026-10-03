import 'package:equatable/equatable.dart';

import 'category_model.dart';
import 'location_model.dart';

/// Mobil Haber Liste Kartı Modeli
class NewsModel extends Equatable {
  final String id;
  final String slug;
  final String title;
  final String summary;
  final String? coverUrl;
  final CategorySnippetModel? primaryCategory;
  final List<CategorySnippetModel> categories;
  final List<LocationSnippetModel> locations;
  final DateTime? publishedAt;
  final DateTime? modifiedAt;
  final bool breaking;
  final bool featured;
  final int readingTime;
  final String? canonicalUrl;

  const NewsModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    this.coverUrl,
    this.primaryCategory,
    this.categories = const [],
    this.locations = const [],
    this.publishedAt,
    this.modifiedAt,
    this.breaking = false,
    this.featured = false,
    this.readingTime = 3,
    this.canonicalUrl,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    // Primary Category
    CategorySnippetModel? primaryCat;
    if (json['primary_category'] is Map<String, dynamic>) {
      primaryCat = CategorySnippetModel.fromJson(
        json['primary_category'] as Map<String, dynamic>,
      );
    }

    // Categories
    final rawCats = json['categories'] as List<dynamic>?;
    final categories = rawCats != null
        ? rawCats
              .whereType<Map<String, dynamic>>()
              .map((c) => CategorySnippetModel.fromJson(c))
              .toList()
        : const <CategorySnippetModel>[];

    // Locations
    final rawLocs = json['locations'] as List<dynamic>?;
    final locations = rawLocs != null
        ? rawLocs
              .whereType<Map<String, dynamic>>()
              .map((l) => LocationSnippetModel.fromJson(l))
              .toList()
        : const <LocationSnippetModel>[];

    return NewsModel(
      id: (json['id'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      coverUrl: json['cover_url'] as String?,
      primaryCategory: primaryCat,
      categories: categories,
      locations: locations,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      modifiedAt: DateTime.tryParse(json['modified_at'] as String? ?? ''),
      breaking: json['breaking'] as bool? ?? false,
      featured: json['featured'] as bool? ?? false,
      readingTime: (json['reading_time'] as num?)?.toInt() ?? 3,
      canonicalUrl: json['canonical_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title': title,
    'summary': summary,
    'cover_url': coverUrl,
    if (primaryCategory != null) 'primary_category': primaryCategory!.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'locations': locations.map((l) => l.toJson()).toList(),
    if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
    if (modifiedAt != null) 'modified_at': modifiedAt!.toIso8601String(),
    'breaking': breaking,
    'featured': featured,
    'reading_time': readingTime,
    if (canonicalUrl != null) 'canonical_url': canonicalUrl,
  };

  @override
  List<Object?> get props => [
    id,
    slug,
    title,
    summary,
    coverUrl,
    primaryCategory,
    categories,
    locations,
    publishedAt,
    modifiedAt,
    breaking,
    featured,
    readingTime,
    canonicalUrl,
  ];
}
