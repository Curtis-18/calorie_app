import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/detected_food.dart';
import 'food_search_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A photo-analysis failure with a message that is safe to show the user.
///
/// The dashboard only shows a specific message for this type. Previously the
/// service threw plain `Exception`s, so every failure (timeout, expired
/// session, Gemini down) surfaced as "Something went wrong while saving your
/// meal", which was wrong: nothing was being saved yet.
class PhotoAnalysisException implements Exception {
  final String message;

  const PhotoAnalysisException(this.message);

  @override
  String toString() => 'PhotoAnalysisException: $message';
}

class PhotoEstimationService {
  PhotoEstimationService({
    this._client,
    this._tokenProvider,
    this._fallbackSearch,
    this.timeout = const Duration(seconds: 60),
  });

  final http.Client? _client;
  final Future<String?> Function()? _tokenProvider;

  /// Only used against a backend that predates server-side enrichment.
  final FoodSearchService? _fallbackSearch;

  /// Long enough to cover a Render cold start plus the backend's own Gemini
  /// retries. At 25 s a cold start alone was enough to fail the scan.
  final Duration timeout;

  static const signedOutMessage = "You've been signed out. Please log in again.";
  static const sessionExpiredMessage = 'Your session has expired. Please log in again.';
  static const timeoutMessage =
      'The server is taking too long to respond. It may be waking up, so try again in a moment.';
  static const networkMessage = "Couldn't reach the server. Check your connection and try again.";
  static const tooLargeMessage = 'That photo is too large. Try again with a smaller photo.';
  static const unreadableMessage = "We couldn't read that photo. Try taking it again.";
  static const serviceBusyMessage =
      'Meal analysis is busy right now. Please try again in a moment.';
  static const badResponseMessage =
      'Got an unexpected response from the server. Please try again.';

  Future<String?> _getFreshToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (expiresAt != null && expiresAt < nowSeconds + 60) {
      final response = await auth.refreshSession();
      session = response.session;
    }
    return session?.accessToken;
  }

  Future<List<DetectedFood>> analyzePhoto(List<int> imageBytes) async {
    String? token;
    try {
      token = await (_tokenProvider ?? _getFreshToken)();
    } on AuthException {
      throw const PhotoAnalysisException(sessionExpiredMessage);
    }
    if (token == null) throw const PhotoAnalysisException(signedOutMessage);

    final client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/estimate-photo'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'image': base64Encode(imageBytes)}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const PhotoAnalysisException(timeoutMessage);
    } on http.ClientException {
      // Covers no connection, DNS failure and (on web) a CORS rejection.
      throw const PhotoAnalysisException(networkMessage);
    } finally {
      if (_client == null) client.close();
    }

    if (response.statusCode != 200) {
      throw PhotoAnalysisException(messageForStatus(response.statusCode));
    }

    final List<DetectedFood> foods;
    final bool enrichedByServer;
    try {
      final data = (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
      foods = data.map(DetectedFood.fromApiJson).toList();
      // The backend now fills in USDA macros in the same request. An older
      // backend only sends name + grams; then do the lookups here as before.
      enrichedByServer = data.every((item) => item.containsKey('matched'));
    } catch (_) {
      throw const PhotoAnalysisException(badResponseMessage);
    }

    if (!enrichedByServer && foods.isNotEmpty) {
      await (_fallbackSearch ?? FoodSearchService()).enrichDetectedFoods(foods);
    }
    return foods;
  }

  /// User-facing text for a non-200 from `POST /estimate-photo`.
  static String messageForStatus(int status) {
    switch (status) {
      case 401:
        return sessionExpiredMessage;
      case 413:
        return tooLargeMessage;
      case 400:
      case 422:
        return unreadableMessage;
      case 502:
      case 503:
      case 504:
        return serviceBusyMessage;
      default:
        return 'Photo analysis failed (error $status). Please try again.';
    }
  }
}
