import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../models/insights.dart';

/// An insights failure with a message that is safe to show the user.
class InsightsException implements Exception {
  const InsightsException(this.message);

  final String message;

  // The insights screen renders the error with string interpolation, so keep
  // this to the message rather than "Exception: Failed to load insights: {...}".
  @override
  String toString() => message;
}

class InsightsService {
  InsightsService({
    this._client,
    this._tokenProvider,
    this._now,
    this.timeout = const Duration(seconds: 60),
  });

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  /// A cache miss means a Gemini call server-side, possibly after a Render
  /// cold start.
  final Duration timeout;

  static const signedOutMessage = "You've been signed out. Please log in again.";
  static const timeoutMessage =
      'Insights are taking too long. The server may be waking up, so pull to refresh in a moment.';
  static const networkMessage = "Couldn't reach the server. Check your connection and try again.";
  static const unavailableMessage = "Insights aren't available right now. Please try again in a moment.";

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<InsightsData> fetchInsights({bool refresh = false}) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const InsightsException(signedOutMessage);

    // The device-local date, the same one food logs are saved under. Without
    // it the server used its own UTC date, so away from UTC the week and the
    // "today" numbers were a day off for part of every day.
    final today = (_now ?? DateTime.now)().toIso8601String().substring(0, 10);
    final uri = Uri.parse('${ApiConfig.baseUrl}/insights').replace(
      queryParameters: {'refresh': '$refresh', 'date': today},
    );

    final client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(timeout);
    } on TimeoutException {
      throw const InsightsException(timeoutMessage);
    } on http.ClientException {
      throw const InsightsException(networkMessage);
    } finally {
      if (_client == null) client.close();
    }

    if (response.statusCode == 401) {
      throw const InsightsException('Your session has expired. Please log in again.');
    }
    if (response.statusCode != 200) throw const InsightsException(unavailableMessage);

    try {
      return InsightsData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      throw const InsightsException(unavailableMessage);
    }
  }
}
