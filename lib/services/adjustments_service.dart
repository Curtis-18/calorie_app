import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/adjustment.dart';

/// The one-tap extras from `GET /adjustments`. Never throws: with no answer
/// the review screen simply offers none of them.
class AdjustmentsService {
  AdjustmentsService({this._client, this._tokenProvider});

  final http.Client? _client;
  final Future<String?> Function()? _tokenProvider;

  // The list rarely changes, so one answer is kept for the app session. A
  // failed or empty answer is not kept, so the next review tries again.
  static List<Adjustment>? _remembered;

  static void forgetForTest() => _remembered = null;

  Future<List<Adjustment>> fetch() async {
    final cached = _remembered;
    if (cached != null) return cached;
    try {
      final token = await (_tokenProvider ?? () async => Supabase.instance.client.auth.currentSession?.accessToken)();
      if (token == null) return const [];
      final client = _client ?? http.Client();
      final http.Response response;
      try {
        response = await client
            .get(Uri.parse('${ApiConfig.baseUrl}/adjustments'), headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 15));
      } finally {
        if (_client == null) client.close();
      }
      if (response.statusCode != 200) return const [];
      final list = [
        for (final raw in jsonDecode(response.body) as List<dynamic>) ?Adjustment.fromJson(raw),
      ];
      // Only a complete-looking answer is kept (the server omits an extra it
      // can't price right now).
      if (list.where((a) => !a.isScale).length >= 3) _remembered = list;
      return list;
    } catch (_) {
      return const [];
    }
  }
}
