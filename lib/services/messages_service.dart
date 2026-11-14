import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/messages.dart';
import 'snaps_service.dart' show newSnapId;

class MessagesException implements Exception {
  const MessagesException(this.message, {this.statusCode});
  final String message;

  /// The server's answer, when there was one (403 means "not friends any more").
  final int? statusCode;

  @override
  String toString() => message;
}

/// A random id for each message, so a retry can't send it twice.
String newMessageId() => newSnapId();

/// Direct messages between friends, through the backend.
class MessagesService {
  MessagesService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  /// One connection kept open: a conversation asks the server every few
  /// seconds, and a new connection each time would cost a handshake each time.
  http.Client? _shared;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client, Map<String, String>) call, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const MessagesException("You've been signed out. Please log in again.");
    final client = _client ?? (_shared ??= http.Client());
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const MessagesException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const MessagesException("Couldn't reach the server. Check your connection and try again.");
    }
  }

  static String _detail(http.Response r, String fallback) {
    try {
      final detail = (jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      // A validation error: the first message says what to fix.
      if (detail is List && detail.isNotEmpty) {
        final msg = (detail.first as Map<String, dynamic>)['msg'];
        if (msg is String) return msg.replaceFirst('Value error, ', '');
      }
    } catch (_) {}
    return fallback;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, dynamic> _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

  Future<ConversationsData> conversations() async {
    final r = await _send((c, h) => c.get(_uri('/messages'), headers: h));
    if (r.statusCode != 200) {
      throw MessagesException(_detail(r, "Couldn't load your messages."), statusCode: r.statusCode);
    }
    return ConversationsData.fromJson(_json(r));
  }

  /// The latest messages with a friend, or the ones before [before].
  Future<ChatThread> thread(String friendId, {DateTime? before}) async {
    final r = await _send(
      (c, h) => c.get(
        _uri('/messages/with/$friendId', {if (before != null) 'before': before.toUtc().toIso8601String()}),
        headers: h,
      ),
    );
    if (r.statusCode != 200) {
      throw MessagesException(_detail(r, "Couldn't load this conversation."), statusCode: r.statusCode);
    }
    return ChatThread.fromJson(_json(r));
  }

  /// Safe to repeat with the same [id]: the server returns the original.
  Future<ChatMessage> send(String friendId, {required String id, required String body}) async {
    final r = await _send(
      (c, h) => c.post(_uri('/messages/with/$friendId'), headers: h, body: jsonEncode({'id': id, 'body': body})),
    );
    if (r.statusCode == 200) return ChatMessage.fromJson(_json(r));
    throw MessagesException(_detail(r, "Couldn't send that message."), statusCode: r.statusCode);
  }

  Future<void> _action(Future<http.Response> Function(http.Client, Map<String, String>) call, String failure) async {
    final r = await _send(call);
    if (r.statusCode == 204) return;
    throw MessagesException(_detail(r, failure), statusCode: r.statusCode);
  }

  Future<void> markRead(String friendId) =>
      _action((c, h) => c.post(_uri('/messages/with/$friendId/read'), headers: h), "Couldn't mark those as read.");

  Future<void> unsend(String messageId) =>
      _action((c, h) => c.delete(_uri('/messages/$messageId'), headers: h), "Couldn't delete that message.");

  Future<void> report(String messageId, {String? reason}) => _action(
        (c, h) => c.post(_uri('/messages/$messageId/report'), headers: h, body: jsonEncode({'reason': reason})),
        "Couldn't send your report.",
      );
}
