import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../config/api_config.dart';
import '../services/user_cache.dart';

/// The signed-in user's profile and targets.
///
/// Global and long-lived like the other providers, so it follows the signed-in
/// user: cleared on sign-out and reloaded when a different user signs in.
///
/// Loads that user's cached copy first for an instant dashboard, then
/// refreshes from `GET /targets`. Reading only the cache meant a fresh
/// install, a new browser or cleared storage showed default targets and "Set
/// up profile" even though the profile was saved on the server. The server
/// copy also wins over a stale cache after an edit on another device.
class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier({
    this._client,
    String? Function()? currentUserId,
    String? Function()? authToken,
    Stream<String?>? userIdChanges,
  })  : _authToken = authToken ?? _supabaseToken,
        super(null) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser((currentUserId ?? UserCache.currentUserId)());
  }

  static String get _baseUrl => ApiConfig.baseUrl;

  final http.Client? _client;
  final String? Function() _authToken;
  StreamSubscription<String?>? _authSubscription;
  String? _userId;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  http.Client get _http => _client ?? _sharedClient;
  static final _sharedClient = http.Client();

  /// Bumped on every user change so a slow load for a previous user can't
  /// land after someone else has signed in.
  int _generation = 0;

  void _onUser(String? userId) {
    if (userId == _userId) return; // token refresh / replayed event
    _userId = userId;
    _generation++;
    state = null;
    if (userId != null) _loadProfile(userId, _generation);
  }

  Future<void> _loadProfile(String userId, int generation) async {
    bool stillCurrent() => mounted && generation == _generation;

    await UserCache.migrateLegacy(userId);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(UserCache.profileKey(userId));
    if (!stillCurrent()) return;
    if (saved != null) {
      try {
        state = UserProfile.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        // A corrupt cache entry: behave as if there were none.
      }
    }

    final remote = await _fetchRemote();
    if (remote == null || !stillCurrent()) return;
    state = remote;
    await prefs.setString(UserCache.profileKey(userId), jsonEncode(remote.toJson()));
  }

  /// The profile from the server, or null when offline, not onboarded yet
  /// (404), or the backend predates the onboarding fields. Never throws: the
  /// cached copy, if any, stays on screen.
  Future<UserProfile?> _fetchRemote() async {
    try {
      final token = _authToken();
      if (token == null) return null;
      final response = await _http
          .get(Uri.parse('$_baseUrl/targets'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 60)); // Render cold start
      if (response.statusCode != 200) return null;
      return UserProfile.fromTargetsJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
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

    final response = await _http.post(
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
        'activity_level': profile.activityLevel.apiName,
        'goal': profile.goal.name,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ProfileSaveException.fromResponse(response.statusCode, response.body);
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

/// A profile save the server refused, with a message safe to show the user
/// (e.g. under 18, or a weight-loss goal below a healthy BMI).
class ProfileSaveException implements Exception {
  const ProfileSaveException(this.message);

  final String message;

  factory ProfileSaveException.fromResponse(int status, String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      if (status == 422 && detail is String && detail.isNotEmpty) {
        return ProfileSaveException(detail);
      }
    } catch (_) {}
    return const ProfileSaveException("We couldn't save your profile. Please try again.");
  }

  @override
  String toString() => message;
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>(
  (ref) => UserProfileNotifier(),
);