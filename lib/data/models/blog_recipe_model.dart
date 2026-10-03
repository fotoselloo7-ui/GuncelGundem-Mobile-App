import 'package:equatable/equatable.dart';

import 'blog_json.dart';

class BlogRecipeModel extends Equatable {
  final String recipeName;
  final String? description;
  final String? cuisine;
  final String? calories;
  final String? prepTime;
  final String? cookTime;
  final String? totalTime;
  final String? servings;
  final String? difficulty;
  final List<String> ingredients;
  final List<String> instructions;
  const BlogRecipeModel({
    this.recipeName = '',
    this.description,
    this.cuisine,
    this.calories,
    this.prepTime,
    this.cookTime,
    this.totalTime,
    this.servings,
    this.difficulty,
    this.ingredients = const [],
    this.instructions = const [],
  });
  factory BlogRecipeModel.fromJson(Map<String, dynamic> json) =>
      BlogRecipeModel(
        recipeName: BlogJson.string(json['recipe_name']) ?? '',
        description: BlogJson.string(json['description']),
        cuisine: BlogJson.string(json['cuisine']),
        calories: BlogJson.string(json['calories']),
        prepTime: BlogJson.string(json['prep_time']),
        cookTime: BlogJson.string(json['cook_time']),
        totalTime: BlogJson.string(json['total_time']),
        servings: BlogJson.string(json['servings']),
        difficulty: BlogJson.string(json['difficulty']),
        ingredients: BlogJson.strings(json['ingredients']),
        instructions: json['instructions'] is List
            ? (json['instructions'] as List)
                  .map(
                    (v) =>
                        BlogJson.string(v) ??
                        BlogJson.string(BlogJson.map(v)['text']) ??
                        '',
                  )
                  .toList()
            : const [],
      );
  Map<String, dynamic> toJson() => {
    'recipe_name': recipeName,
    'description': description,
    'cuisine': cuisine,
    'calories': calories,
    'prep_time': prepTime,
    'cook_time': cookTime,
    'total_time': totalTime,
    'servings': servings,
    'difficulty': difficulty,
    'ingredients': ingredients,
    'instructions': instructions,
  };
  @override
  List<Object?> get props => [
    recipeName,
    description,
    cuisine,
    calories,
    prepTime,
    cookTime,
    totalTime,
    servings,
    difficulty,
    ingredients,
    instructions,
  ];
}
