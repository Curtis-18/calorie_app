import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/notification_prefs.dart';

class NotificationPrefsException implements Exception {
  const NotificationPrefsException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reading and changing notification choices through the backend.
class NotificationPrefsService {
  NotificationPrefsService({this._client, this._tokenProvider, this._utcOffset});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final int Function()? _utcOffset;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  int get _offsetMinutes => (_utcOffset ?? () => DateTime.now().timeZoneOffset.inMinutes)();

  Future<http.Response> _send(Future<http.Response> Function(http.Client, Map<String, String>) call) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const NotificationPrefsException("You've been signed out. Please log in again.");
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const NotificationPrefsException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const NotificationPrefsException("Couldn't reach the server. Check your connection and try again.");
    } finally {
      if (_client == null) client.close();
    }
  }

  NotificationPrefs _parse(http.Response r, String failure) {
    if (r.statusCode != 200) throw NotificationPrefsException(failure);
    try {
      return NotificationPrefs.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      throw NotificationPrefsException(failure);
    }
  }

  Future<NotificationPrefs> load() async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/notifications/prefs'), headers: h));
    return _parse(r, "Couldn't load your notification settings.");
  }

  /// Send only what changed. The phone's time zone always goes along, so the
  /// server's quiet hours follow the person when they travel.
  Future<NotificationPrefs> update(Map<String, Object?> changes) async {
    final body = {...changes, 'utc_offset_minutes': _offsetMinutes};
    final r = await _send((c, h) => c.post(
          Uri.parse('${ApiConfig.baseUrl}/notifications/prefs'),
          headers: h,
          body: jsonEncode(body),
        ));
    return _parse(r, "Couldn't save that. Please try again.");
  }
}
