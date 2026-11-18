import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/food_entry.dart';
import '../models/house_recipe.dart';

class RecipeSaveResult {
  const RecipeSaveResult.ok(this.recipe) : error = null;
  const RecipeSaveResult.failed(this.error) : recipe = null;

  final HouseRecipe? recipe;
  final String? error;
}

/// The person's own recipes. Reads never throw; a save says why it failed.
class HouseRecipeService {
  HouseRecipeService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  String? _token() => (_tokenProvider ?? () => Supabase.instance.client.auth.currentSession?.accessToken)();

  Future<http.Response?> _send(
    Future<http.Response> Function(http.Client c, Map<String, String> h) call, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final token = _token();
    if (token == null) return null;
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Null when it couldn't be loaded (as opposed to an empty list).
  Future<List<HouseRecipe>?> list() async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/recipes'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return [for (final j in jsonDecode(r.body) as List) ?HouseRecipe.fromJson(j)];
    } catch (_) {
      return null;
    }
  }

  Future<HouseRecipe?> get(String id) async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/recipes/$id'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return HouseRecipe.fromJson(jsonDecode(r.body));
    } catch (_) {
      return null;
    }
  }

  String _message(http.Response? r) {
    if (r == null) return "Couldn't reach the server. Check your connection and try again.";
    if (r.statusCode == 422) {
      try {
        final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
        if (detail is String) return detail;
        // A validation list: the first message is enough.
        if (detail is List && detail.isNotEmpty && detail.first is Map) {
          final msg = (detail.first as Map)['msg'];
          if (msg is String) return msg.replaceFirst('Value error, ', '');
        }
      } catch (_) {}
      return "That recipe isn't complete yet.";
    }
    if (r.statusCode == 503) return "Recipes aren't available right now. Please try again later.";
    return "Couldn't save that right now. Please try again.";
  }

  /// Save a new recipe from ingredients, or (no ingredients) from one
  /// per-serving estimate. [id] is made by the app so a retry is safe.
  Future<RecipeSaveResult> create({
    required String id,
    required String title,
    required double servings,
    List<DraftIngredient> ingredients = const [],
    Map<String, Object?>? perServing,
  }) async {
    final r = await _send((c, h) => c.post(
          Uri.parse('${ApiConfig.baseUrl}/recipes'),
          headers: h,
          body: jsonEncode({
            'id': id,
            'title': title,
            'servings': servings,
            if (ingredients.isNotEmpty) 'ingredients': [for (final i in ingredients) i.toJson()],
            'per_serving': ?perServing,
          }),
        ));
    if (r == null || (r.statusCode != 200 && r.statusCode != 201)) return RecipeSaveResult.failed(_message(r));
    final recipe = HouseRecipe.fromJson(jsonDecode(r.body));
    return recipe == null ? const RecipeSaveResult.failed("Couldn't read the saved recipe.") : RecipeSaveResult.ok(recipe);
  }

  /// Null on success, otherwise a message.
  Future<String?> delete(String id) async {
    final r = await _send((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/recipes/$id'), headers: h));
    if (r != null && (r.statusCode == 204 || r.statusCode == 404)) return null;
    return _message(r);
  }

  /// Quietly tell the server this recipe was logged (it creates the entry and
  /// records the event). Best effort: the app saves the entry itself, so a
  /// failure here changes nothing the person can see.
  Future<void> recordLog(String recipeId, FoodEntry entry, double servings, DateTime day) async {
    await _send(
      (c, h) => c.post(
        Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/log'),
        headers: h,
        body: jsonEncode({
          'id': entry.id,
          'servings': servings,
          'meal_type': entry.mealType.name,
          'log_date': day.toIso8601String().substring(0, 10),
          'timestamp': entry.timestamp.toIso8601String(),
        }),
      ),
      timeout: const Duration(seconds: 8),
    );
  }
}
