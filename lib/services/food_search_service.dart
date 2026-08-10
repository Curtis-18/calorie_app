import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/detected_food.dart';
import '../models/food_item.dart';

class FoodSearchService {
  static const _apiKey = 'DN84n9OEF2cocrQnNRgCYN85qkPWRYCg9sXt6dmc';
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';
  static const _timeout = Duration(seconds: 8);

  Future<List<FoodItem>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': trimmedQuery,
      'api_key': _apiKey,
      'pageSize': '20',
    });

    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('Food search failed: ${response.statusCode}');
    }

    return _parseFoodItems(response.body);
  }

  List<FoodItem> _parseFoodItems(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final foods = data['foods'] as List<dynamic>? ?? [];

    return foods
        .map((f) => FoodItem.fromJson(f as Map<String, dynamic>))
        .where((item) => item.caloriesPer100g != null)
        .toList();
  }

  FoodItem _bestMatch(List<FoodItem> results) {
    // Prefer whole/raw-food entries over branded or processed ones, since
    // a plain search term like "avocado" can just as easily match "Avocado
    // oil" or a branded snack as it can match the actual whole fruit, and
    // those have very different calorie densities for the same weight.
    return results.firstWhere(
      (r) => r.dataType == 'Foundation' || r.dataType == 'SR Legacy',
      orElse: () => results.first,
    );
  }

  Future<void> enrichDetectedFoods(List<DetectedFood> items) async {
    await Future.wait(items.map((item) async {
      try {
        final results = await search(item.name);
        if (results.isEmpty) return;

        final match = _bestMatch(results);
        item
          ..caloriesPer100g = match.caloriesPer100g
          ..proteinPer100g = match.proteinPer100g
          ..carbsPer100g = match.carbsPer100g
          ..fatPer100g = match.fatPer100g
          ..matched = true;
      } catch (_) {
        // leave unmatched, don't let one bad lookup kill the others
      }
    }));
  }
}
