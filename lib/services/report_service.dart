import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/weekly_report.dart';

/// The weekly report. Never throws: it is an extra on the Insights tab, and
/// with no answer the card is simply left out.
class ReportService {
  ReportService({this._client, this._tokenProvider, this._now});

  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final DateTime Function()? _now;

  Future<WeeklyReport?> weekly() async {
    final token = (_tokenProvider ?? () => Supabase.instance.client.auth.currentSession?.accessToken)();
    if (token == null) return null;
    final today = (_now ?? DateTime.now)().toIso8601String().substring(0, 10);
    final client = _client ?? http.Client();
    try {
      final r = await client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/reports/weekly').replace(queryParameters: {'date': today}),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) return null;
      return WeeklyReport.fromJson(jsonDecode(r.body));
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}
