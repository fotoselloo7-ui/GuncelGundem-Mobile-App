import 'package:equatable/equatable.dart';

/// Konu Modeli
class TopicModel extends Equatable {
  final String id;
  final String name;
  final String slug;

  const TopicModel({required this.id, required this.name, required this.slug});

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    return TopicModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  @override
  List<Object?> get props => [id, name, slug];
}
