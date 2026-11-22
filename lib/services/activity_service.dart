import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/activity.dart';

/// The Notifications list (bites and reactions from friends), from the backend.
class ActivityService {
  ActivityService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(Future<http.Response> Function(http.Client, Map<String, String>) call) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw StateError('signed out');
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
    } finally {
      if (_client == null) client.close();
    }
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Throws when it can't be loaded; the caller keeps what it already had.
  Future<ActivityData> list() async {
    final r = await _send((c, h) => c.get(_uri('/activity'), headers: h));
    if (r.statusCode != 200) throw StateError('activity ${r.statusCode}');
    return ActivityData.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> markSeen() async {
    final r = await _send((c, h) => c.post(_uri('/activity/seen'), headers: h));
    if (r.statusCode != 204 && r.statusCode != 200) throw StateError('activity seen ${r.statusCode}');
  }
}
