import 'package:equatable/equatable.dart';

/// Etiket Modeli
class TagModel extends Equatable {
  final String id;
  final String name;
  final String slug;

  const TagModel({required this.id, required this.name, required this.slug});

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  @override
  List<Object?> get props => [id, name, slug];
}
