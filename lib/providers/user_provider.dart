import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../config/api_config.dart';

String _activityLevelToApi(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary: return 'sedentary';
    case ActivityLevel.light: return 'light';
    case ActivityLevel.moderate: return 'moderate';
    case ActivityLevel.active: return 'active';
    case ActivityLevel.veryActive: return 'very_active';
  }
}

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier() : super(null) {
    _loadProfile();
  }

  static const _key = 'user_profile';
  static String get _baseUrl => ApiConfig.baseUrl;

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = UserProfile.fromJson(jsonDecode(saved));
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not logged in');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/targets'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'date_of_birth': profile.dateOfBirth.toIso8601String().split('T').first,
        'sex': profile.gender.name,
        'height_feet': (profile.heightCm / 2.54 / 12).floor(),
        'height_inches': (profile.heightCm / 2.54) % 12,
        'weight_value': profile.weightKg,
        'weight_unit': 'kg',
        'activity_level': _activityLevelToApi(profile.activityLevel),
        'goal': profile.goal.name,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to save profile: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final updated = profile.copyWithTargets(
      bmr: (data['bmr'] as num).toDouble(),
      tdee: (data['tdee'] as num).toDouble(),
      calorieTarget: data['calorie_target'] as int,
      bmi: (data['bmi'] as num).toDouble(),
      proteinTargetG: data['protein_g'] as int,
      fatTargetG: data['fat_g'] as int,
      carbsTargetG: data['carbs_g'] as int,
    );

    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated.toJson()));
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>(
  (ref) => UserProfileNotifier(),
);