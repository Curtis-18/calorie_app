import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class RecipeService {
  // ignore: prefer_initializing_formals
  RecipeService({http.Client? client}) : _client = client;

  /// For tests; the app uses the default client.
  final http.Client? _client;

  // Free TheMealDB test key, fine for development/personal use.
  // Swap for a real supporter key before shipping to an app store.
  static const _baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  Future<List<Map<String, dynamic>>> _getMeals(String path) async {
    final uri = Uri.parse('$_baseUrl/$path');
    final response = await (_client?.get(uri) ?? http.get(uri)).timeout(const Duration(seconds: 15));

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

  Future<List<RecipeSummary>> browseDefault() async {
    // TheMealDB's free tier has no single "list many recipes" endpoint,
    // so pull a broad set by combining a few reliable categories.
    const categories = ['Chicken', 'Beef', 'Vegetarian', 'Dessert', 'Seafood'];
    final results = <RecipeSummary>[];

    for (final category in categories) {
      try {
        final meals = await _getMeals('filter.php?c=$category');
        results.addAll(meals.map(RecipeSummary.fromJson));
      } catch (_) {
        continue; // one category failing shouldn't blank the whole screen
      }
    }
    return results;
  }

  /// Recipes that use [ingredient] (TheMealDB's own names, underscores for
  /// spaces, e.g. `brown_rice`). Remembered for this session so changing mood
  /// back and forth costs nothing.
  final Map<String, List<RecipeSummary>> _byIngredient = {};

  Future<List<RecipeSummary>> filterByIngredient(String ingredient) async {
    final cached = _byIngredient[ingredient];
    if (cached != null) return cached;
    final meals = await _getMeals('filter.php?i=${Uri.encodeQueryComponent(ingredient)}');
    return _byIngredient[ingredient] = meals.map(RecipeSummary.fromJson).toList();
  }

  Set<String>? _dessertIds;

  /// The ids the catalogue files under Dessert (one request, kept for the session).
  Future<Set<String>> dessertIds() async {
    final cached = _dessertIds;
    if (cached != null) return cached;
    final meals = await _getMeals('filter.php?c=Dessert');
    return _dessertIds = meals.map((m) => m['idMeal'] as String).toSet();
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