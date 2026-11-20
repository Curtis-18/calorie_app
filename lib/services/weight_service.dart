import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/weight.dart';
import '../l10n/app_strings.dart';
import 'language_client.dart';

class WeightException implements Exception {
  const WeightException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WeightService {
  WeightService({this._client, this._tokenProvider, this._now});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  static String day(DateTime d) => d.toIso8601String().substring(0, 10);

  String get _today => day((_now ?? DateTime.now)());

  Future<http.Response> _send(Future<http.Response> Function(http.Client, Map<String, String>) call) async {
    final token = (_tokenProvider ?? _supabaseToken)();
    if (token == null) throw WeightException(tr("You've been signed out. Please log in again."));
    final client = _client ?? languageClient();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw WeightException(tr('The server is taking too long. It may be waking up, so try again.'));
    } on http.ClientException {
      throw WeightException(tr("Couldn't reach the server. Check your connection and try again."));
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<WeightHistory> fetch() async {
    final r = await _send((c, h) => c.get(
          Uri.parse('${ApiConfig.baseUrl}/weights').replace(queryParameters: {'date': _today}),
          headers: h,
        ));
    if (r.statusCode != 200) throw WeightException(tr("Couldn't load your weight history."));
    return WeightHistory.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<WeightSaveResult> log(double weightKg, {DateTime? on}) async {
    final r = await _send((c, h) => c.post(
          Uri.parse('${ApiConfig.baseUrl}/weights').replace(queryParameters: {'today': _today}),
          headers: h,
          body: jsonEncode({'weight_kg': double.parse(weightKg.toStringAsFixed(2)), 'date': day(on ?? (_now ?? DateTime.now)())}),
        ));
    if (r.statusCode != 200) throw WeightException(tr("Couldn't save your weigh-in. Please try again."));
    return WeightSaveResult.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> delete(DateTime on) async {
    final r = await _send((c, h) => c.delete(Uri.parse('${ApiConfig.baseUrl}/weights/${day(on)}'), headers: h));
    if (r.statusCode != 204 && r.statusCode != 404) {
      throw WeightException(tr("Couldn't delete that weigh-in. Please try again."));
    }
  }
}
