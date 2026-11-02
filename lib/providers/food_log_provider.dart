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
///
/// "Today" is the device-local date, and it rolls over: at midnight (a timer),
/// and before any add or delete. The log used to be loaded once, so an app
/// left open overnight kept yesterday's entries, counted them against the new
/// day's budget, and cached them under the new date as soon as anything was
/// logged.
class FoodLogNotifier extends StateNotifier<List<FoodEntry>> {
  FoodLogNotifier({
    this._client,
    String? Function()? currentUserId,
    String? Function()? authToken,
    Stream<String?>? userIdChanges,
    DateTime Function()? now,
  })  : _currentUserId = currentUserId ?? UserCache.currentUserId,
        _authToken = authToken ?? _supabaseToken,
        _now = now ?? DateTime.now,
        super([]) {
    _day = _todayDateString;
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser(_currentUserId());
    _scheduleMidnightRollover();
  }

  final http.Client? _client;
  final String? Function() _currentUserId;
  final String? Function() _authToken;
  final DateTime Function() _now;
  StreamSubscription<String?>? _authSubscription;
  Timer? _midnightTimer;
  String? _userId;

  /// The device-local date (yyyy-mm-dd) that [state] belongs to.
  late String _day;

  /// Bumped on every user or day change. A load that started for a previous
  /// user (e.g. still in flight at sign-out) or a previous day must not put
  /// those entries back on screen.
  int _generation = 0;

  /// The date the current entries belong to.
  DateTime get day => DateTime.parse(_day);

  /// Start a fresh day if the date has changed since the log was loaded.
  /// Returns whether it rolled over. Call it when the app returns to the
  /// foreground; adds and deletes call it themselves.
  bool ensureCurrentDay() {
    final today = _todayDateString;
    if (today == _day) return false;
    _day = today;
    _generation++;
    state = [];
    if (_userId != null) _loadToday();
    return true;
  }

  void _scheduleMidnightRollover() {
    final now = _now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // A second past midnight, so the new date is unambiguous.
    _midnightTimer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      ensureCurrentDay();
      _scheduleMidnightRollover();
    });
  }

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
    _midnightTimer?.cancel();
    super.dispose();
  }

  http.Client get _http => _client ?? _sharedClient;
  static final _sharedClient = http.Client();

  String get _todayDateString => _now().toIso8601String().substring(0, 10);

  Future<void> _loadToday() async {
    final userId = _userId;
    final token = _authToken();
    if (userId == null || token == null) return;
    final generation = _generation;
    final dayString = _day;
    final day = DateTime.parse(dayString);
    bool stillCurrent() => mounted && generation == _generation;

    await UserCache.migrateLegacy(userId);

    try {
      final response = await _http.get(
        Uri.parse('${ApiConfig.baseUrl}/logs/today?date=$dayString'),
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
    final saved = prefs.getStringList(UserCache.logKey(userId, day)) ?? [];
    state = saved.map((s) => FoodEntry.fromJson(jsonDecode(s))).toList();
  }

  Future<void> addEntry(FoodEntry entry) async {
    ensureCurrentDay();
    final logDate = _day;
    final previous = state;
    state = [...state, entry];

    final token = _authToken();
    if (token == null) {
      _rollback(previous, logDate);
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
          'log_date': logDate,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 201 && response.statusCode != 200) {
        _rollback(previous, logDate);
        throw Exception('Failed to save entry: ${response.body}');
      }
      await _persistCache(_userId);
    } catch (e) {
      _rollback(previous, logDate);
      rethrow;
    }
  }

  Future<void> removeEntry(String id) async {
    ensureCurrentDay();
    final logDate = _day;
    final previous = state;
    state = state.where((e) => e.id != id).toList();

    final token = _authToken();
    if (token == null) {
      _rollback(previous, logDate);
      throw Exception('Not logged in');
    }

    try {
      final response = await _http.delete(
        Uri.parse('${ApiConfig.baseUrl}/logs/$id'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 204) {
        _rollback(previous, logDate);
        throw Exception('Failed to remove entry: ${response.body}');
      }
      await _persistCache(_userId);
    } catch (e) {
      _rollback(previous, logDate);
      rethrow;
    }
  }

  /// Undo an optimistic change, unless the day rolled over meanwhile: then
  /// [previous] is yesterday's list and must not come back.
  void _rollback(List<FoodEntry> previous, String logDate) {
    if (mounted && _day == logDate) state = previous;
  }

  Future<void> _persistCache(String? userId) async {
    if (userId == null || userId != _userId) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      UserCache.logKey(userId, day),
      state.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}

final foodLogProvider = StateNotifierProvider<FoodLogNotifier, List<FoodEntry>>(
  (ref) => FoodLogNotifier(),
);
