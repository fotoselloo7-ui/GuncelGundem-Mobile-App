import 'package:equatable/equatable.dart';

/// Haber Kaynağı Modeli
class SourceModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? websiteUrl;

  const SourceModel({
    required this.id,
    required this.name,
    required this.slug,
    this.websiteUrl,
  });

  factory SourceModel.fromJson(Map<String, dynamic> json) {
    return SourceModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      websiteUrl: json['website_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'website_url': websiteUrl,
  };

  @override
  List<Object?> get props => [id, name, slug, websiteUrl];
}
