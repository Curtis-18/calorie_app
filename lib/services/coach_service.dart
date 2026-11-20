import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import '../models/messages.dart';
import 'language_client.dart';
import 'messages_service.dart' show MessagesException;

export 'messages_service.dart' show MessagesException, newMessageId;

/// The AI coach, through the backend: text only, one thread per person.
/// What the coach knows about the person is built on the server; the app only
/// sends what the person typed.
class CoachService {
  CoachService({this._client, this._tokenProvider, this._now});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client, Map<String, String>) call, {
    Duration timeout = const Duration(seconds: 45), // a model answer can take a while
  }) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw MessagesException(tr("You've been signed out. Please log in again."));
    final client = _client ?? languageClient();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}).timeout(timeout);
    } on TimeoutException {
      throw MessagesException(tr('The server is taking too long. It may be waking up, so try again.'));
    } on http.ClientException {
      throw MessagesException(tr("Couldn't reach the server. Check your connection and try again."));
    } finally {
      if (_client == null) client.close();
    }
  }

  Map<String, dynamic> _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

  /// The server's own words are in English, so the app says it in its language.
  static String _why(int status, String fallback) {
    switch (status) {
      case 429:
        return tr("You're sending a lot of messages. Give it a few minutes.");
      case 503:
        return tr("The coach isn't available right now. Please try again in a moment.");
      case 404:
        return tr('Finish setting up your plan first.');
      default:
        return fallback;
    }
  }

  /// The newest page, oldest first, or the page before [before].
  Future<ChatThread> thread({DateTime? before}) async {
    final r = await _send((c, h) => c.get(
          Uri.parse('${ApiConfig.baseUrl}/coach/messages')
              .replace(queryParameters: {if (before != null) 'before': before.toUtc().toIso8601String()}),
          headers: h,
        ));
    if (r.statusCode != 200) {
      throw MessagesException(_why(r.statusCode, tr("Couldn't load your chat.")), statusCode: r.statusCode);
    }
    final body = _json(r);
    return ChatThread(
      messages: [for (final m in (body['messages'] as List)) ChatMessage.fromCoachJson(m as Map<String, dynamic>)],
      hasMore: body['has_more'] == true,
    );
  }

  /// Ask the coach. Safe to repeat with the same [id]: the server returns the
  /// answer it already gave, or answers now if it never got that far.
  Future<ChatMessage> ask({required String id, required String text}) async {
    final today = (_now ?? DateTime.now)().toIso8601String().substring(0, 10);
    final r = await _send((c, h) => c.post(
          Uri.parse('${ApiConfig.baseUrl}/coach/messages').replace(queryParameters: {'date': today}),
          headers: h,
          body: jsonEncode({'id': id, 'text': text}),
        ));
    if (r.statusCode == 200) return ChatMessage.fromCoachJson(_json(r));
    throw MessagesException(_why(r.statusCode, tr("Couldn't send that message.")), statusCode: r.statusCode);
  }

  Future<void> clear() async {
    final r = await _send((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/coach/messages'), headers: h));
    if (r.statusCode == 204) return;
    throw MessagesException(_why(r.statusCode, tr("Couldn't clear the conversation.")), statusCode: r.statusCode);
  }
}
