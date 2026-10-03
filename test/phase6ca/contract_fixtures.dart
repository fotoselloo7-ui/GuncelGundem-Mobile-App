import 'dart:convert';
import 'dart:io';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/6ca/$name.json').readAsStringSync())
        as Map<String, dynamic>;

const recipeFixture = <String, dynamic>{
  'recipe_name': 'Mercimek Çorbası',
  'prep_time': 'PT10M',
  'cook_time': 'PT30M',
  'total_time': 'PT40M',
  'servings': 6,
  'difficulty': 'Kolay',
  'ingredients': ['Mercimek', 'Su'],
  'instructions': ['Yıka', 'Pişir'],
};
