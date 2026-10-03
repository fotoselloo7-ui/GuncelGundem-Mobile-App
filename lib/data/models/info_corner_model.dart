import 'package:equatable/equatable.dart';

import 'blog_article_model.dart';
import 'blog_category_model.dart';
import 'blog_json.dart';

class InfoCornerModel extends Equatable {
  final String title;
  final List<BlogArticleModel> featured;
  final List<BlogArticleModel> latest;
  final List<BlogCategoryModel> categories;
  const InfoCornerModel({
    this.title = '',
    this.featured = const [],
    this.latest = const [],
    this.categories = const [],
  });
  factory InfoCornerModel.fromJson(Map<String, dynamic> json) =>
      InfoCornerModel(
        title: BlogJson.string(json['title']) ?? '',
        featured: BlogJson.maps(json['featured'])
            .map((a) => BlogArticleModel.fromJson(a))
            .toList(),
        latest: BlogJson.maps(json['latest'])
            .map((a) => BlogArticleModel.fromJson(a))
            .toList(),
        categories: BlogJson.maps(json['categories'])
            .map((c) => BlogCategoryModel.fromJson(c))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
    'title': title,
    'featured': featured.map((a) => a.toJson()).toList(),
    'latest': latest.map((a) => a.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
  };
  @override
  List<Object?> get props => [title, featured, latest, categories];
}
