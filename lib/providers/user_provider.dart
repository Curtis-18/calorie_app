import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../config/api_config.dart';
import '../services/user_cache.dart';

String _activityLevelToApi(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary: return 'sedentary';
    case ActivityLevel.light: return 'light';
    case ActivityLevel.moderate: return 'moderate';
    case ActivityLevel.active: return 'active';
    case ActivityLevel.veryActive: return 'very_active';
  }
}

/// The signed-in user's profile and targets.
///
/// Global and long-lived like the other providers, so it follows the signed-in
/// user: cleared on sign-out and reloaded from that user's own cache when a
/// different user signs in. It used to read one device-wide `user_profile`
/// key once, so a second account on the same device inherited the first
/// account's targets.
class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier({
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
  }) : super(null) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser((currentUserId ?? UserCache.currentUserId)());
  }

  static String get _baseUrl => ApiConfig.baseUrl;

  StreamSubscription<String?>? _authSubscription;
  String? _userId;

  /// Bumped on every user change so a slow cache read for a previous user
  /// can't land after someone else has signed in.
  int _generation = 0;

  void _onUser(String? userId) {
    if (userId == _userId) return; // token refresh / replayed event
    _userId = userId;
    _generation++;
    state = null;
    if (userId != null) _loadProfile(userId, _generation);
  }

  Future<void> _loadProfile(String userId, int generation) async {
    await UserCache.migrateLegacy(userId);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(UserCache.profileKey(userId));
    if (!mounted || generation != _generation || saved == null) return;
    try {
      state = UserProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      // A corrupt cache entry: behave as if there were none.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (session == null || token == null) {
      throw Exception('Not logged in');
    }
    final userId = session.user.id;

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(UserCache.profileKey(userId), jsonEncode(updated.toJson()));
    // Only publish if the same user is still signed in.
    if (mounted && userId == _userId) state = updated;
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>(
  (ref) => UserProfileNotifier(),
);