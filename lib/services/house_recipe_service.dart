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
    if (r.statusCode == 403) return 'You can only send recipes to your friends.';
    if (r.statusCode == 404) return "That recipe isn't available any more.";
    if (r.statusCode == 413) return 'That photo is too large.';
    if (r.statusCode == 415) return "That photo can't be used. Try a different one.";
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

  // ---- collections, Highlights, sharing ------------------------------------

  Future<List<RecipeCollection>?> collections() async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/collections'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return [for (final j in jsonDecode(r.body) as List) ?RecipeCollection.fromJson(j)];
    } catch (_) {
      return null;
    }
  }

  Future<List<RecipeBrief>?> highlights() async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/highlights'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return [for (final j in jsonDecode(r.body) as List) ?RecipeBrief.fromJson(j)];
    } catch (_) {
      return null;
    }
  }

  /// Every write below returns null on success, otherwise a message to show.
  Future<String?> _write(
    Future<http.Response> Function(http.Client c, Map<String, String> h) call, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final r = await _send(call, timeout: timeout);
    if (r != null && r.statusCode >= 200 && r.statusCode < 300) return null;
    return _message(r);
  }

  Future<String?> createCollection(String id, String name) => _write((c, h) =>
      c.post(Uri.parse('${ApiConfig.baseUrl}/collections'), headers: h, body: jsonEncode({'id': id, 'name': name})));

  Future<String?> deleteCollection(String id) =>
      _write((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/collections/$id'), headers: h));

  Future<String?> addToCollection(String collectionId, String recipeId) => _write((c, h) => c.post(
        Uri.parse('${ApiConfig.baseUrl}/collections/$collectionId/items'),
        headers: h,
        body: jsonEncode({'recipe_id': recipeId}),
      ));

  Future<String?> removeFromCollection(String collectionId, String recipeId) => _write(
      (c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/collections/$collectionId/items/$recipeId'), headers: h));

  /// Keep a recipe in "Saved".
  Future<String?> save(String recipeId) =>
      _write((c, h) => c.post(Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/save'), headers: h));

  Future<String?> setHighlights(List<String> recipeIds) => _write((c, h) =>
      c.put(Uri.parse('${ApiConfig.baseUrl}/highlights'), headers: h, body: jsonEncode({'recipe_ids': recipeIds})));

  /// Send a recipe to a friend as a chat card. [messageId] is chosen by the app
  /// so a retry sends it once.
  Future<String?> share(String recipeId, String friendId, String messageId) => _write((c, h) => c.post(
        Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/share/$friendId'),
        headers: h,
        body: jsonEncode({'id': messageId}),
      ));

  Future<String?> unshare(String recipeId, String friendId) =>
      _write((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/share/$friendId'), headers: h));

  // ---- who can see it, photos, a friend's recipes, editing -----------------

  /// Null when it couldn't be loaded.
  Future<List<RecipeSharee>?> sharedWith(String recipeId) async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/shares'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return [for (final j in jsonDecode(r.body) as List) ?RecipeSharee.fromJson(j)];
    } catch (_) {
      return null;
    }
  }

  /// "private" or "friends". Null on success, otherwise a message.
  Future<String?> setVisibility(String recipeId, String visibility) => _write((c, h) =>
      c.patch(Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId'), headers: h, body: jsonEncode({'visibility': visibility})));

  /// The recipes a friend lets me open and has pinned. Null when it couldn't be loaded.
  Future<List<RecipeBrief>?> friendHighlights(String friendId) async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/users/$friendId/highlights'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return [for (final j in jsonDecode(r.body) as List) ?RecipeBrief.fromJson(j)];
    } catch (_) {
      return null;
    }
  }

  /// Add or replace the cover (position 0) or a slide (1-5). [jpeg] is already
  /// shrunk. Null on success, otherwise a message.
  Future<String?> putPhoto(String recipeId, int position, List<int> jpeg, {String? caption}) => _write(
        (c, h) => c.put(
          Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/media/$position'),
          headers: h,
          body: jsonEncode({'image': base64Encode(jpeg), if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim()}),
        ),
        timeout: const Duration(seconds: 60),
      );

  Future<String?> deletePhoto(String recipeId, int position) =>
      _write((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/media/$position'), headers: h));

  Future<String?> report(String recipeId, {String? reason}) => _write((c, h) => c.post(
        Uri.parse('${ApiConfig.baseUrl}/recipes/$recipeId/report'),
        headers: h,
        body: jsonEncode({if (reason != null && reason.isNotEmpty) 'reason': reason}),
      ));

  /// Change the details and (optionally) replace the whole ingredient list;
  /// the server prices it again. The photos stay.
  Future<RecipeSaveResult> update(String id, {String? title, double? servings, List<DraftIngredient>? ingredients}) async {
    final r = await _send((c, h) => c.patch(
          Uri.parse('${ApiConfig.baseUrl}/recipes/$id'),
          headers: h,
          body: jsonEncode({
            'title': ?title,
            'servings': ?servings,
            if (ingredients != null && ingredients.isNotEmpty) 'ingredients': [for (final i in ingredients) i.toJson()],
          }),
        ));
    if (r == null || r.statusCode != 200) return RecipeSaveResult.failed(_message(r));
    final recipe = HouseRecipe.fromJson(jsonDecode(r.body));
    return recipe == null ? const RecipeSaveResult.failed("Couldn't read the saved recipe.") : RecipeSaveResult.ok(recipe);
  }
}
