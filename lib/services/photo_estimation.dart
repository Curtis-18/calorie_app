import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/detected_food.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoAnalysisException implements Exception {
  final String message;

  const PhotoAnalysisException(this.message);
}

class PhotoEstimationService {
  PhotoEstimationService();

  Future<String?> _getFreshToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) return null;

    final expiresAt = session.expiresAt;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (expiresAt != null && expiresAt < nowSeconds + 60) {
      final response = await auth.refreshSession();
      session = response.session;
    }
    return session?.accessToken;
  }

  Future<List<DetectedFood>> analyzePhoto(List<int> imageBytes) async {
    final token = await _getFreshToken();
    if (token == null) throw Exception('Not signed in');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/estimate-photo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'image': base64Encode(imageBytes),
      }),
    ).timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw Exception(
        'Photo analysis timed out, the server may be waking up. Try again.',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Photo analysis failed: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data.map((item) {
      return DetectedFood(
        name: item['name'] as String,
        estimatedGrams: (item['estimated_grams'] as num).toDouble(),
      );
    }).toList();
  }
}