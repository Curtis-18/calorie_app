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

/// What arrives while the coach answers (POST /coach/messages/stream).
sealed class CoachEvent {
  const CoachEvent();
}

/// The next piece of the answer, already checked by the server: whole sentences.
class CoachTextArrived extends CoachEvent {
  const CoachTextArrived(this.text);
  final String text;
}

/// Drop what was shown so far: a different answer follows (the server stopped
/// one that broke a rule, or the app is asking again another way).
class CoachStartOver extends CoachEvent {
  const CoachStartOver();
}

/// The finished answer as stored, with any recipe or routine cards. Always
/// the last event; its text is the one to keep.
class CoachAnswered extends CoachEvent {
  const CoachAnswered(this.message);
  final ChatMessage message;
}

/// The server said something went wrong after the answer began. Not a
/// [CoachEvent]: the service handles it by asking again, the screen never sees it.
class _StreamFailed {
  const _StreamFailed();
}

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

  /// Ask the coach and get the answer while it is being written. If the server
  /// is older (no stream route), refuses, goes quiet for [quietLimit], or the
  /// stream breaks, it asks [ask] with the same [id] instead; the server never
  /// answers one turn twice, so nothing is lost or doubled. Throws
  /// [MessagesException] only when that also fails.
  Stream<CoachEvent> askStream({
    required String id,
    required String text,
    Duration quietLimit = const Duration(seconds: 45),
  }) async* {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw MessagesException(tr("You've been signed out. Please log in again."));
    final today = (_now ?? DateTime.now)().toIso8601String().substring(0, 10);
    final client = _client ?? languageClient();
    var answered = false;
    var shownAny = false;
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/coach/messages/stream').replace(queryParameters: {'date': today}),
      )
        ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'text/event-stream'})
        ..body = jsonEncode({'id': id, 'text': text});
      final response = await client.send(request).timeout(quietLimit);
      if (response.statusCode == 200) {
        final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter()).timeout(quietLimit);
        await for (final line in lines) {
          final event = _event(line);
          if (event is _StreamFailed) break;
          if (event is! CoachEvent) continue;
          if (event is CoachTextArrived) shownAny = true;
          if (event is CoachStartOver) shownAny = false;
          yield event;
          if (event is CoachAnswered) {
            answered = true;
            break;
          }
        }
      } else {
        // An older server (404) or a refusal: the plain request below gets the
        // same answer and says what is wrong in the app's own words.
        response.stream.listen(null, onError: (_) {}, cancelOnError: true).cancel();
      }
    } on TimeoutException {
      // fall through to the plain request
    } on http.ClientException {
      // fall through to the plain request
    } finally {
      if (_client == null) client.close();
    }
    if (answered) return;
    if (shownAny) yield const CoachStartOver();
    yield CoachAnswered(await ask(id: id, text: text));
  }

  /// One `data:` line of the stream as a [CoachEvent] or [_StreamFailed];
  /// null for anything else, including kinds a newer server might add.
  static Object? _event(String line) {
    if (!line.startsWith('data:')) return null;
    final Object? json;
    try {
      json = jsonDecode(line.substring(5).trim());
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;
    switch (json['type']) {
      case 'delta':
        final piece = json['text'];
        return piece is String && piece.isNotEmpty ? CoachTextArrived(piece) : null;
      case 'reset':
        return const CoachStartOver();
      case 'done':
        final message = json['message'];
        if (message is! Map<String, dynamic>) return const _StreamFailed();
        try {
          return CoachAnswered(ChatMessage.fromCoachJson(message));
        } catch (_) {
          return const _StreamFailed();
        }
      case 'error':
        return const _StreamFailed();
    }
    return null;
  }

  Future<void> clear() async {
    final r = await _send((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/coach/messages'), headers: h));
    if (r.statusCode == 204) return;
    throw MessagesException(_why(r.statusCode, tr("Couldn't clear the conversation.")), statusCode: r.statusCode);
  }
}
