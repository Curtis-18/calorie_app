import 'dart:convert';
import 'dart:async'; // Added for StreamSubscription
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';
import '../models/food_entry.dart';

class FoodLogNotifier extends StateNotifier<List<FoodEntry>> {
  StreamSubscription<AuthState>? _authSubscription;

  FoodLogNotifier( ) : super([]) {
    _loadToday();
    
    // FIXED: Listen to auth changes so the provider updates when the user logs in
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _loadToday();
      } else if (event == AuthChangeEvent.signedOut) {
        state = []; // Clear logs on logout
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String get _todayDateString => DateTime.now().toIso8601String().substring(0, 10);
  String get _cacheKey => 'food_log_$_todayDateString';

  String? _authToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<void> _loadToday() async {
    final token = _authToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/logs/today?date=$_todayDateString' ),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        state = data.map((e) => FoodEntry.fromApiJson(e as Map<String, dynamic>)).toList();
        await _persistCache();
        return;
      }
    } catch (_) {
      // Fallback to cache if offline
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_cacheKey) ?? [];
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
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/logs' ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': entry.id,
          'name': entry.name,
          'calories': entry.calories,
          'protein_g': entry.proteinG, // Ensure these match your backend schema
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
      await _persistCache();
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
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/logs/$id' ),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 204) {
        state = previous;
        throw Exception('Failed to remove entry: ${response.body}');
      }
      await _persistCache();
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _cacheKey,
      state.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

final foodLogProvider = StateNotifierProvider<FoodLogNotifier, List<FoodEntry>>(
  (ref) => FoodLogNotifier(),
);
