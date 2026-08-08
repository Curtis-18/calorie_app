import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/detected_food.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoEstimationService {
  PhotoEstimationService( );

  Future<List<DetectedFood>> analyzePhoto(List<int> imageBytes) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/estimate-photo' ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'image': base64Encode(imageBytes),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Photo analysis failed: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    
    // FIXED: Using the constructor directly since fromMap wasn't found
    return data.map((item) {
      return DetectedFood(
        name: item['name'] as String,
        estimatedGrams: (item['estimatedGrams'] as num).toDouble(),
        caloriesPer100g: item['caloriesPer100g'] != null 
            ? (item['caloriesPer100g'] as num).toDouble() 
            : null,
      );
    }).toList();
  }
}
