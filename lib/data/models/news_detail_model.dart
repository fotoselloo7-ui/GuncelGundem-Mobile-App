import 'package:equatable/equatable.dart';

import 'author_model.dart';
import 'category_model.dart';
import 'location_model.dart';
import 'media_model.dart';
import 'news_block_model.dart';
import 'news_model.dart';
import 'source_model.dart';
import 'tag_model.dart';
import 'topic_model.dart';

/// Zengin Haber Detay Modeli
class NewsDetailModel extends Equatable {
  final NewsModel card;
  final NewsBodyModel body;
  final String? coverCredit;
  final List<String> gallery;
  final List<MediaVideoModel> videos;
  final List<AuthorModel> authors;
  final List<SourceModel> sources;
  final List<TagModel> tags;
  final List<TopicModel> topics;
  final List<NewsModel> relatedNews;

  const NewsDetailModel({
    required this.card,
    required this.body,
    this.coverCredit,
    this.gallery = const [],
    this.videos = const [],
    this.authors = const [],
    this.sources = const [],
    this.tags = const [],
    this.topics = const [],
    this.relatedNews = const [],
  });

  // Delegated getters from NewsModel for ease of use
  String get id => card.id;
  String get slug => card.slug;
  String get title => card.title;
  String get summary => card.summary;
  String? get coverUrl => card.coverUrl;
  CategorySnippetModel? get primaryCategory => card.primaryCategory;
  List<CategorySnippetModel> get categories => card.categories;
  List<LocationSnippetModel> get locations => card.locations;
  DateTime? get publishedAt => card.publishedAt;
  DateTime? get modifiedAt => card.modifiedAt;
  bool get breaking => card.breaking;
  bool get featured => card.featured;
  int get readingTime => card.readingTime;
  String? get canonicalUrl => card.canonicalUrl;

  factory NewsDetailModel.fromJson(Map<String, dynamic> json) {
    final card = NewsModel.fromJson(json);

    // Body blocks
    NewsBodyModel body;
    if (json['body'] is Map<String, dynamic>) {
      body = NewsBodyModel.fromJson(json['body'] as Map<String, dynamic>);
    } else {
      body = const NewsBodyModel();
    }

    // Gallery
    final rawGallery = json['gallery'] as List<dynamic>?;
    final gallery = rawGallery != null
        ? rawGallery
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : const <String>[];

    // Videos
    final rawVideos = json['videos'] as List<dynamic>?;
    final videos = rawVideos != null
        ? rawVideos.map((v) => MediaVideoModel.fromJson(v)).toList()
        : const <MediaVideoModel>[];

    // Authors
    final rawAuthors = json['authors'] as List<dynamic>?;
    final authors = rawAuthors != null
        ? rawAuthors
              .whereType<Map<String, dynamic>>()
              .map((a) => AuthorModel.fromJson(a))
              .toList()
        : const <AuthorModel>[];

    // Sources
    final rawSources = json['sources'] as List<dynamic>?;
    final sources = rawSources != null
        ? rawSources
              .whereType<Map<String, dynamic>>()
              .map((s) => SourceModel.fromJson(s))
              .toList()
        : const <SourceModel>[];

    // Tags
    final rawTags = json['tags'] as List<dynamic>?;
    final tags = rawTags != null
        ? rawTags
              .whereType<Map<String, dynamic>>()
              .map((t) => TagModel.fromJson(t))
              .toList()
        : const <TagModel>[];

    // Topics
    final rawTopics = json['topics'] as List<dynamic>?;
    final topics = rawTopics != null
        ? rawTopics
              .whereType<Map<String, dynamic>>()
              .map((t) => TopicModel.fromJson(t))
              .toList()
        : const <TopicModel>[];

    // Related News
    final rawRelated = json['related_news'] as List<dynamic>?;
    final relatedNews = rawRelated != null
        ? rawRelated
              .whereType<Map<String, dynamic>>()
              .map((r) => NewsModel.fromJson(r))
              .toList()
        : const <NewsModel>[];

    return NewsDetailModel(
      card: card,
      body: body,
      coverCredit: json['cover_credit'] as String?,
      gallery: gallery,
      videos: videos,
      authors: authors,
      sources: sources,
      tags: tags,
      topics: topics,
      relatedNews: relatedNews,
    );
  }

  Map<String, dynamic> toJson() {
    final base = card.toJson();
    base['body'] = body.toJson();
    if (coverCredit != null) base['cover_credit'] = coverCredit;
    base['gallery'] = gallery;
    base['videos'] = videos.map((v) => v.toJson()).toList();
    base['authors'] = authors.map((a) => a.toJson()).toList();
    base['sources'] = sources.map((s) => s.toJson()).toList();
    base['tags'] = tags.map((t) => t.toJson()).toList();
    base['topics'] = topics.map((t) => t.toJson()).toList();
    base['related_news'] = relatedNews.map((r) => r.toJson()).toList();
    return base;
  }

  @override
  List<Object?> get props => [
    card,
    body,
    coverCredit,
    gallery,
    videos,
    authors,
    sources,
    tags,
    topics,
    relatedNews,
  ];
}
