import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class RecipeService {
  // Free TheMealDB test key, fine for development/personal use.
  // Swap for a real supporter key before shipping to an app store.
  static const _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  Future<List<Map<String, dynamic>>> _getMeals(String path) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/$path'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Recipe lookup failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final meals = body['meals'] as List<dynamic>?;
    if (meals == null) return [];
    return meals.cast<Map<String, dynamic>>();
  }

  Future<List<RecipeSummary>> search(String query) async {
    final meals = await _getMeals('search.php?s=${Uri.encodeQueryComponent(query)}');
    return meals.map(RecipeSummary.fromJson).toList();
  }

  Future<RecipeDetail?> getRandom() async {
    final meals = await _getMeals('random.php');
    if (meals.isEmpty) return null;
    return RecipeDetail.fromJson(meals.first);
  }

  Future<RecipeDetail?> lookupById(String id) async {
    final meals = await _getMeals('lookup.php?i=$id');
    if (meals.isEmpty) return null;
    return RecipeDetail.fromJson(meals.first);
  }
}