import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';

class UsernameException implements Exception {
  const UsernameException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UsernameCheck {
  const UsernameCheck({required this.available, this.reason});
  final bool available;
  final String? reason;
}

/// Checking and choosing a username through the backend.
class UsernameService {
  UsernameService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  static const taken = 'That username is taken.';

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response> _send(
    Future<http.Response> Function(http.Client, Map<String, String>) call,
  ) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw const UsernameException("You've been signed out. Please log in again.");
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const UsernameException('The server is taking too long. It may be waking up, so try again.');
    } on http.ClientException {
      throw const UsernameException("Couldn't reach the server. Check your connection and try again.");
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

  /// Is [name] free? Format problems are answered by the server too, so the
  /// client and server can never disagree for long.
  Future<UsernameCheck> check(String name) async {
    final r = await _send((c, h) => c.get(
          Uri.parse('${ApiConfig.baseUrl}/username/check').replace(queryParameters: {'name': name.trim()}),
          headers: h,
        ));
    if (r.statusCode != 200) throw const UsernameException("Couldn't check that name. Please try again.");
    final json = jsonDecode(r.body) as Map<String, dynamic>;
    return UsernameCheck(available: json['available'] == true, reason: json['reason'] as String?);
  }

  /// Claim [name]. Returns the saved username.
  Future<String> choose(String name) async {
    final r = await _send((c, h) => c.post(
          Uri.parse('${ApiConfig.baseUrl}/username'),
          headers: h,
          body: jsonEncode({'username': name.trim()}),
        ));
    switch (r.statusCode) {
      case 200:
        return (jsonDecode(r.body) as Map<String, dynamic>)['username'] as String;
      case 409:
        throw const UsernameException(taken);
      case 422:
      case 429:
        throw UsernameException(_detail(r, "That username can't be used."));
      default:
        throw const UsernameException("Couldn't save your username. Please try again.");
    }
  }
}
