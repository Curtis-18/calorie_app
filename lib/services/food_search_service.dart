import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../models/detected_food.dart';
import '../models/food_item.dart';

/// A food search failure with a message that is safe to show the user.
class FoodSearchException implements Exception {
  const FoodSearchException(this.message);

  final String message;

  // The search screen renders `e.toString()`, so keep it to the message
  // rather than "Exception: Food search failed: 500".
  @override
  String toString() => message;
}

/// Food search through the backend's `/foods/search` proxy.
///
/// This used to call USDA directly with the API key compiled into the app,
/// which shipped the key in every web bundle and mobile build. The backend
/// holds the key now; the client only sends the user's session token.
class FoodSearchService {
  FoodSearchService({
    this._client,
    this._tokenProvider,
    this.timeout = const Duration(seconds: 30),
  });

  final http.Client? _client;
  final Future<String?> Function()? _tokenProvider;

  /// Covers a Render cold start. USDA itself answers in about a second.
  final Duration timeout;

  static const pageSize = 20;

  static const signedOutMessage = "You've been signed out. Please log in again.";
  static const timeoutMessage = 'Search is taking too long. The server may be waking up, so try again.';
  static const networkMessage = "Couldn't reach the server. Check your connection and try again.";
  static const unavailableMessage = 'Food search is unavailable right now. Please try again in a moment.';

  static Future<String?> _currentToken() async =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Future<List<FoodItem>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final token = await (_tokenProvider ?? _currentToken)();
    if (token == null) throw const FoodSearchException(signedOutMessage);

    final uri = Uri.parse('${ApiConfig.baseUrl}/foods/search').replace(
      queryParameters: {
        'query': trimmedQuery,
        'page_size': '$pageSize',
      },
    );

    final client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(timeout);
    } on TimeoutException {
      throw const FoodSearchException(timeoutMessage);
    } on http.ClientException {
      throw const FoodSearchException(networkMessage);
    } finally {
      if (_client == null) client.close();
    }

    if (response.statusCode == 401) {
      throw const FoodSearchException('Your session has expired. Please log in again.');
    }
    if (response.statusCode != 200) {
      throw const FoodSearchException(unavailableMessage);
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? const [];
      return results
          .map((r) => FoodItem.fromApiJson(r as Map<String, dynamic>))
          .where((item) => item.caloriesPer100g != null)
          .toList();
    } catch (_) {
      throw const FoodSearchException(unavailableMessage);
    }
  }

  FoodItem _bestMatch(List<FoodItem> results, String query) {
    final queryWords = query
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((w) => w.isNotEmpty)
        .toSet();

    const dataTypeRank = {
      'Foundation': 0,
      'SR Legacy': 1,
      'Survey (FNDDS)': 2,
      'Branded': 3,
    };

    const penalizedWords = {
      'oil',
      'powder',
      'extract',
      'dried',
      'juice',
      'sauce',
      'syrup',
      'flour',
      'concentrate',
      'flavored',
      'flavor',
      'seasoning',
      'dressing',
      'chips',
      'flakes',
      'paste',
      'butter',
      'dehydrated',
      'canned',
      'frozen',
      'candied',
      'imitation',
      'substitute',
    };

    int score(FoodItem item) {
      final descWords = item.description
          .toLowerCase()
          .split(RegExp(r'[\s,]+'))
          .where((w) => w.isNotEmpty)
          .toSet();

      final typeRank = dataTypeRank[item.dataType] ?? 4;
      final extraWords = descWords.difference(queryWords);
      final penalizedCount = extraWords.where(penalizedWords.contains).length;

      return (penalizedCount * 1000) + (typeRank * 10) + extraWords.length;
    }

    final ranked = [...results]..sort((a, b) => score(a).compareTo(score(b)));
    return ranked.first;
  }

  Future<void> enrichDetectedFoods(List<DetectedFood> items) async {
    await Future.wait(
      items.map((item) async {
        try {
          final results = await search(item.name);
          if (results.isEmpty) return;

          final match = _bestMatch(results, item.name);
          item
            ..caloriesPer100g = match.caloriesPer100g
            ..proteinPer100g = match.proteinPer100g
            ..carbsPer100g = match.carbsPer100g
            ..fatPer100g = match.fatPer100g
            ..matched = true;
        } catch (_) {
          // leave unmatched, don't let one bad lookup kill the others
        }
      }),
    );
  }
}
