import 'package:equatable/equatable.dart';

import 'category_model.dart';
import 'news_model.dart';
import 'info_corner_model.dart';
import 'live_module_model.dart';

/// Ana Sayfa Kategori Bölümü Modeli
class HomeCategorySectionModel extends Equatable {
  final CategoryModel category;
  final List<NewsModel> news;

  const HomeCategorySectionModel({required this.category, required this.news});

  factory HomeCategorySectionModel.fromJson(Map<String, dynamic> json) {
    final catJson = json['category'] as Map<String, dynamic>? ?? {};
    final rawNews = json['news'] ?? json['articles'] ?? json['items'];
    final newsJson = rawNews is List ? rawNews : const [];

    return HomeCategorySectionModel(
      category: CategoryModel.fromJson(catJson),
      news: newsJson
          .whereType<Map<String, dynamic>>()
          .map((n) => NewsModel.fromJson(n))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category.toJson(),
    'news': news.map((n) => n.toJson()).toList(),
  };

  @override
  List<Object?> get props => [category, news];
}

/// Mobil Ana Sayfa Veri Modeli
class HomeModel extends Equatable {
  final List<NewsModel> breaking;
  final List<NewsModel> hero;
  final List<HomeCategorySectionModel> categorySections;
  final List<NewsModel> featured;
  final List<NewsModel> mostRead;
  final List<NewsModel> latest;
  final InfoCornerModel? infoCorner;
  final LiveModulesModel? liveModules;

  const HomeModel({
    this.breaking = const [],
    this.hero = const [],
    this.categorySections = const [],
    this.featured = const [],
    this.mostRead = const [],
    this.latest = const [],
    this.infoCorner,
    this.liveModules,
  });

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    List<NewsModel> parseNewsList(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((n) => NewsModel.fromJson(n))
            .toList();
      }
      return const [];
    }

    final rawSections = json['category_sections'] as List<dynamic>?;
    final sections = rawSections != null
        ? rawSections
              .whereType<Map<String, dynamic>>()
              .map((s) => HomeCategorySectionModel.fromJson(s))
              .toList()
        : const <HomeCategorySectionModel>[];

    return HomeModel(
      breaking: parseNewsList(json['breaking']),
      hero: parseNewsList(json['hero']),
      categorySections: sections,
      featured: parseNewsList(json['featured']),
      mostRead: parseNewsList(json['most_read']),
      latest: parseNewsList(json['latest']),
      infoCorner: json['info_corner'] is Map<String, dynamic>
          ? InfoCornerModel.fromJson(json['info_corner'])
          : null,
      liveModules: json['live_modules'] is Map<String, dynamic>
          ? LiveModulesModel.fromJson(json['live_modules'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'breaking': breaking.map((n) => n.toJson()).toList(),
    'hero': hero.map((n) => n.toJson()).toList(),
    'category_sections': categorySections.map((s) => s.toJson()).toList(),
    'featured': featured.map((n) => n.toJson()).toList(),
    'most_read': mostRead.map((n) => n.toJson()).toList(),
    'latest': latest.map((n) => n.toJson()).toList(),
    if (infoCorner != null) 'info_corner': infoCorner!.toJson(),
    if (liveModules != null) 'live_modules': liveModules!.toJson(),
  };

  @override
  List<Object?> get props => [
    breaking,
    hero,
    categorySections,
    featured,
    mostRead,
    latest,
    infoCorner,
    liveModules,
  ];

  HomeModel withOfflineLiveModules() => HomeModel(
    breaking: breaking,
    hero: hero,
    categorySections: categorySections,
    featured: featured,
    mostRead: mostRead,
    latest: latest,
    infoCorner: infoCorner,
    liveModules: liveModules?.asOffline(),
  );

  HomeModel withLiveModules(LiveModulesModel? modules) => HomeModel(
    breaking: breaking,
    hero: hero,
    categorySections: categorySections,
    featured: featured,
    mostRead: mostRead,
    latest: latest,
    infoCorner: infoCorner,
    liveModules: modules,
  );
}
