import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/snaps.dart';

class SnapsException implements Exception {
  const SnapsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A random v4 id the app picks for each snap, so a retry can't send it twice.
String newSnapId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Food snaps through the backend: send, inbox, sent, react, report.
class SnapsService {
  SnapsService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client, Map<String, String>) call, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const SnapsException("You've been signed out. Please log in again.");
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const SnapsException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const SnapsException("Couldn't reach the server. Check your connection and try again.");
    } finally {
      if (_client == null) client.close();
    }
  }

  static String _detail(http.Response r, String fallback) {
    try {
      final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return fallback;
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Send [image] to [recipientIds]. Returns each friend's streak after the send.
  Future<List<SendOutcome>> send({
    required String id,
    required Uint8List image,
    required List<String> recipientIds,
    String? caption,
  }) async {
    final trimmed = caption?.trim();
    final r = await _send(
      (c, h) => c.post(
        _uri('/snaps'),
        headers: h,
        body: jsonEncode({
          'id': id,
          'image': base64Encode(image),
          if (trimmed != null && trimmed.isNotEmpty) 'caption': trimmed,
          'recipient_ids': recipientIds,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        }),
      ),
      timeout: const Duration(seconds: 90),
    );
    if (r.statusCode == 200) {
      final json = jsonDecode(r.body) as Map<String, dynamic>;
      return ((json['recipients'] as List?) ?? const [])
          .map((e) => SendOutcome.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw SnapsException(_detail(r, "Couldn't send your snap. Please try again."));
  }

  Future<List<InboxSnap>> inbox() async {
    final r = await _send((c, h) => c.get(_uri('/snaps/inbox'), headers: h));
    if (r.statusCode != 200) throw SnapsException(_detail(r, "Couldn't load your snaps."));
    return (jsonDecode(r.body) as List).map((e) => InboxSnap.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SentSnap>> sent() async {
    final r = await _send((c, h) => c.get(_uri('/snaps/sent'), headers: h));
    if (r.statusCode != 200) throw SnapsException(_detail(r, "Couldn't load the snaps you sent."));
    return (jsonDecode(r.body) as List).map((e) => SentSnap.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _action(Future<http.Response> Function(http.Client, Map<String, String>) call, String failure) async {
    final r = await _send(call);
    if (r.statusCode == 204) return;
    throw SnapsException(_detail(r, failure));
  }

  Future<void> markViewed(String snapId) =>
      _action((c, h) => c.post(_uri('/snaps/$snapId/view'), headers: h), "Couldn't mark that snap as seen.");

  Future<void> react(String snapId, String emoji) => _action(
      (c, h) => c.post(_uri('/snaps/$snapId/react'), headers: h, body: jsonEncode({'emoji': emoji})),
      "Couldn't send that reaction.");

  Future<void> report(String snapId, {String? reason}) => _action(
      (c, h) => c.post(_uri('/snaps/$snapId/report'), headers: h, body: jsonEncode({'reason': reason})),
      "Couldn't send your report.");

  Future<void> delete(String snapId) =>
      _action((c, h) => c.delete(_uri('/snaps/$snapId'), headers: h), "Couldn't delete that snap.");
}
