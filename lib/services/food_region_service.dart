import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';

/// `GET/POST /prefs/food`. A read never throws (the region is an extra); a
/// save returns a message when it failed.
class FoodRegionService {
  FoodRegionService({this._client, this._tokenProvider});

  final http.Client? _client;
  final String? Function()? _tokenProvider;

  String? _token() => (_tokenProvider ?? () => Supabase.instance.client.auth.currentSession?.accessToken)();

  Future<http.Response?> _send(Future<http.Response> Function(http.Client c, Map<String, String> h) call) async {
    final token = _token();
    if (token == null) return null;
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// `(answered, region)`: [answered] is false when the server could not be
  /// reached, so "nothing chosen" is not mistaken for "no answer".
  Future<({bool answered, String? region})> fetch() async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/prefs/food'), headers: h));
    if (r == null || r.statusCode != 200) return (answered: false, region: null);
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return (answered: true, region: body['region'] as String?);
    } catch (_) {
      return (answered: false, region: null);
    }
  }

  /// Save [region] (null clears it). Returns null on success, else a message.
  Future<String?> save(String? region) async {
    final r = await _send(
        (c, h) => c.post(Uri.parse('${ApiConfig.baseUrl}/prefs/food'), headers: h, body: jsonEncode({'region': region})));
    if (r == null) return "Couldn't reach the server. Check your connection and try again.";
    if (r.statusCode == 200) return null;
    return "Couldn't save that right now. Please try again.";
  }
}
