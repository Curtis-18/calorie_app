import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/week_budget.dart';
import '../l10n/app_strings.dart';

/// The weekly budget endpoints. Reads never throw (the budget is an extra: the
/// dashboard must work without it); a save returns a message when it failed.
class BudgetService {
  BudgetService({this._client, this._tokenProvider, this._now});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  String? _token() => (_tokenProvider ?? () => Supabase.instance.client.auth.currentSession?.accessToken)();

  Future<http.Response?> _send(Future<http.Response> Function(http.Client c, Map<String, String> h) call) async {
    final token = _token();
    if (token == null) return null;
    final client = _client ?? http.Client();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<WeekBudgetData?> week() async {
    final today = (_now ?? DateTime.now)().toIso8601String().substring(0, 10);
    final r = await _send((c, h) =>
        c.get(Uri.parse('${ApiConfig.baseUrl}/budget/week').replace(queryParameters: {'date': today}), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return WeekBudgetData.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<BudgetPrefs?> prefs() async {
    final r = await _send((c, h) => c.get(Uri.parse('${ApiConfig.baseUrl}/budget/prefs'), headers: h));
    if (r == null || r.statusCode != 200) return null;
    try {
      return BudgetPrefs.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Save some choices. Returns null on success, otherwise a message to show.
  Future<String?> save(Map<String, Object?> changes) async {
    final r = await _send((c, h) => c.post(Uri.parse('${ApiConfig.baseUrl}/budget/prefs'), headers: h, body: jsonEncode(changes)));
    if (r == null) return tr("Couldn't reach the server. Check your connection and try again.");
    if (r.statusCode == 200) return null;
    if (r.statusCode == 422) {
      try {
        final detail = (jsonDecode(r.body) as Map<String, dynamic>)['detail'];
        if (detail is String) return detail;
      } catch (_) {}
      return tr("That isn't allowed for your plan.");
    }
    return tr("Couldn't save that right now. Please try again.");
  }
}
