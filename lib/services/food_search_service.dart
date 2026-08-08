import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

class FoodSearchService {
  static const _apiKey = 'DN84n9OEF2cocrQnNRgCYN85qkPWRYCg9sXt6dmc';
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';

  Future<List<FoodItem>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': query,
      'api_key': _apiKey,
      'pageSize': '20',
    });

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Food search failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final foods = data['foods'] as List<dynamic>? ?? [];

    return foods
        .map((f) => FoodItem.fromJson(f as Map<String, dynamic>))
        .where((item) => item.caloriesPer100g != null)
        .toList();
  }
}