import 'package:equatable/equatable.dart';

/// Yazar Modeli
class AuthorModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? title;
  final String? bio;
  final String? avatarUrl;
  final String? canonicalUrl;

  const AuthorModel({
    required this.id,
    required this.name,
    required this.slug,
    this.title,
    this.bio,
    this.avatarUrl,
    this.canonicalUrl,
  });

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    return AuthorModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      title: json['title'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'title': title,
    'bio': bio,
    'avatar_url': avatarUrl,
    'canonical_url': canonicalUrl,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    title,
    bio,
    avatarUrl,
    canonicalUrl,
  ];
}
