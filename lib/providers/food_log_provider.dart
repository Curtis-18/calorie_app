import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../models/food_entry.dart';
import '../services/user_cache.dart';

/// Today's food log for the signed-in user, cached per user on the device.
class FoodLogNotifier extends StateNotifier<List<FoodEntry>> {
  FoodLogNotifier({
    this._client,
    String? Function()? currentUserId,
    String? Function()? authToken,
    Stream<String?>? userIdChanges,
  })  : _currentUserId = currentUserId ?? UserCache.currentUserId,
        _authToken = authToken ?? _supabaseToken,
        super([]) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser(_currentUserId());
  }

  final http.Client? _client;
  final String? Function() _currentUserId;
  final String? Function() _authToken;
  StreamSubscription<String?>? _authSubscription;
  String? _userId;

  /// Bumped on every user change. A load that started for a previous user
  /// (e.g. still in flight at sign-out) must not put that user's entries back
  /// on screen once someone else, or no one, is signed in.
  int _generation = 0;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  void _onUser(String? userId) {
    if (userId != _userId) {
      _userId = userId;
      _generation++;
      state = [];
    }
    // Same user again (sign-in event, token refresh): just resync.
    if (userId != null) _loadToday();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  http.Client get _http => _client ?? _sharedClient;
  static final _sharedClient = http.Client();

  String get _todayDateString => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _loadToday() async {
    final userId = _userId;
    final token = _authToken();
    if (userId == null || token == null) return;
    final generation = _generation;
    bool stillCurrent() => mounted && generation == _generation;

    await UserCache.migrateLegacy(userId);
    final today = DateTime.now();

    try {
      final response = await _http.get(
        Uri.parse('${ApiConfig.baseUrl}/logs/today?date=$_todayDateString'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (!stillCurrent()) return;
        final data = jsonDecode(response.body) as List<dynamic>;
        state = data.map((e) => FoodEntry.fromApiJson(e as Map<String, dynamic>)).toList();
        await _persistCache(userId);
        return;
      }
    } catch (_) {
      // Fall back to this user's cache if offline.
    }

    final prefs = await SharedPreferences.getInstance();
    if (!stillCurrent()) return;
    final saved = prefs.getStringList(UserCache.logKey(userId, today)) ?? [];
    state = saved.map((s) => FoodEntry.fromJson(jsonDecode(s))).toList();
  }

  Future<void> addEntry(FoodEntry entry) async {
    final previous = state;
    state = [...state, entry];

    final token = _authToken();
    if (token == null) {
      state = previous;
      throw Exception('Not logged in - Session expired or not found');
    }

    try {
      final response = await _http.post(
        Uri.parse('${ApiConfig.baseUrl}/logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': entry.id,
          'name': entry.name,
          'calories': entry.calories,
          'protein_g': entry.proteinG,
          'carbs_g': entry.carbsG,
          'fat_g': entry.fatG,
          'meal_type': entry.mealType.name,
          'source': entry.source.name,
          'timestamp': entry.timestamp.toIso8601String(),
          'log_date': _todayDateString,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 201 && response.statusCode != 200) {
        state = previous;
        throw Exception('Failed to save entry: ${response.body}');
      }
      await _persistCache(_userId);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> removeEntry(String id) async {
    final previous = state;
    state = state.where((e) => e.id != id).toList();

    final token = _authToken();
    if (token == null) {
      state = previous;
      throw Exception('Not logged in');
    }

    try {
      final response = await _http.delete(
        Uri.parse('${ApiConfig.baseUrl}/logs/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 204) {
        state = previous;
        throw Exception('Failed to remove entry: ${response.body}');
      }
      await _persistCache(_userId);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> _persistCache(String? userId) async {
    if (userId == null || userId != _userId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      UserCache.logKey(userId, DateTime.now()),
      state.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

final foodLogProvider = StateNotifierProvider<FoodLogNotifier, List<FoodEntry>>(
  (ref) => FoodLogNotifier(),
);
