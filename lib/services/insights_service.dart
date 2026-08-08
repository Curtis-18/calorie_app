import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../models/insights.dart';

class InsightsService {
  Future<InsightsData> fetchInsights({bool refresh = false}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not logged in');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/insights?refresh=$refresh');
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 45)); // cache-miss triggers a Gemini call server-side

    if (response.statusCode != 200) {
      throw Exception('Failed to load insights: ${response.body}');
    }

    return InsightsData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}