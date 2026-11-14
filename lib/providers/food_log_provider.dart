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
    this.saveRetryDelays = defaultSaveRetryDelays,
    this.saveTimeout = const Duration(seconds: 20),
  })  : _currentUserId = currentUserId ?? UserCache.currentUserId,
        _authToken = authToken ?? _supabaseToken,
        _now = now ?? DateTime.now,
        super([]) {
    _day = _todayDateString;
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser(_currentUserId());
    _scheduleMidnightRollover();
  }

  /// Pauses before each retry of a failed save, so its length is the number
  /// of retries. Retrying is safe: the backend treats a repeated id from the
  /// same user as a successful save, so a retry after a lost response can't
  /// log the food twice.
  static const defaultSaveRetryDelays = [Duration(seconds: 1), Duration(seconds: 3)];

  final List<Duration> saveRetryDelays;

  /// Per attempt. Long enough that the first try rides out most of a Render
  /// cold start, and the retries cover the rest.
  final Duration saveTimeout;

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

  /// Changes still on their way to the server: entries being added or edited
  /// (by id) and ids being deleted. A reload that lands meanwhile (the
  /// session token refreshing is enough to trigger one) used to replace the
  /// list with the server's older copy, so a food you had just added
  /// vanished, or one you had just deleted came back, until the next reload.
  final Map<String, FoodEntry> _pendingSaves = {};
  final Set<String> _pendingDeletes = {};

  List<FoodEntry> _withPending(List<FoodEntry> fromServer) {
    if (_pendingSaves.isEmpty && _pendingDeletes.isEmpty) return fromServer;
    final seen = <String>{};
    final merged = <FoodEntry>[];
    for (final e in fromServer) {
      if (_pendingDeletes.contains(e.id)) continue;
      seen.add(e.id);
      merged.add(_pendingSaves[e.id] ?? e);
    }
    for (final e in _pendingSaves.values) {
      if (!seen.contains(e.id)) merged.add(e);
    }
    return merged;
  }

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
    _pendingSaves.clear();
    _pendingDeletes.clear();
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
      _pendingSaves.clear();
      _pendingDeletes.clear();
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
        state = _withPending(data.map((e) => FoodEntry.fromApiJson(e as Map<String, dynamic>)).toList());
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

    final userId = _userId;
    final generation = _generation;
    _pendingSaves[entry.id] = entry;
    try {
      await _postWithRetry(entry, logDate, userId);
      _settle(generation, () => _pendingSaves.remove(entry.id));
      await _persistCache(userId);
    } catch (e) {
      _settle(generation, () => _pendingSaves.remove(entry.id));
      _rollback(state.where((x) => x.id != entry.id).toList(), logDate);
      rethrow;
    }
  }

  /// Clear a pending marker, unless the day or user changed meanwhile (the
  /// markers were reset then, and may already belong to a newer change).
  void _settle(int generation, void Function() clear) {
    if (generation == _generation) clear();
  }

  /// POST the entry, retrying timeouts, dropped connections and 5xx answers.
  /// A 4xx means the server understood and refused, so retrying can't help.
  /// The entry stays on screen while this runs; the caller rolls it back only
  /// if every attempt fails.
  Future<void> _postWithRetry(FoodEntry entry, String logDate, String? userId) async {
    final body = jsonEncode({
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
      if (entry.nutrients != null) 'nutrients': entry.nutrients!.toJson(),
    });

    await _sendWithRetry(
      (token) => _http.post(
        Uri.parse('${ApiConfig.baseUrl}/logs'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: body,
      ),
      userId: userId,
      failure: 'Failed to save entry',
    );
  }

  /// Run a save that is safe to repeat (the server treats a repeat as already
  /// done), retrying timeouts, dropped connections and 5xx answers.
  Future<void> _sendWithRetry(
    Future<http.Response> Function(String token) send, {
    required String? userId,
    required String failure,
  }) async {
    for (var attempt = 0;; attempt++) {
      final retriesLeft = attempt < saveRetryDelays.length;
      // A fresh token each time: the session may have refreshed meanwhile.
      final token = _authToken();
      if (token == null) throw Exception('Not logged in - Session expired or not found');

      try {
        final response = await send(token).timeout(saveTimeout);

        if (response.statusCode == 201 || response.statusCode == 200) return;
        final transient = response.statusCode >= 500;
        if (!transient || !retriesLeft) {
          throw Exception('$failure: ${response.body}');
        }
      } on TimeoutException {
        if (!retriesLeft) rethrow;
      } on http.ClientException {
        if (!retriesLeft) rethrow;
      }

      await Future<void>.delayed(saveRetryDelays[attempt]);
      // Signed out or switched user while waiting: stop, so one user's food
      // is never sent with another user's token.
      if (!mounted || _userId != userId) throw Exception('Signed out before the entry could be saved');
    }
  }

  /// Replace a saved entry with a corrected copy (same id): a new portion, a
  /// different food, another name or meal. Shown at once and rolled back if
  /// the server can't save it. The request carries the entry's full new
  /// values, so repeating it after a lost response is harmless.
  Future<void> updateEntry(FoodEntry updated) async {
    ensureCurrentDay();
    final logDate = _day;
    final previous = state;
    if (!previous.any((e) => e.id == updated.id)) {
      throw Exception('That entry is no longer in today\'s log');
    }
    state = [for (final e in previous) e.id == updated.id ? updated : e];

    final userId = _userId;
    final generation = _generation;
    final before = previous.firstWhere((e) => e.id == updated.id);
    _pendingSaves[updated.id] = updated;
    final body = jsonEncode({
      'name': updated.name,
      'calories': updated.calories,
      'protein_g': updated.proteinG,
      'carbs_g': updated.carbsG,
      'fat_g': updated.fatG,
      'meal_type': updated.mealType.name,
      // Always sent: null tells the server the new food has no nutrient data.
      'nutrients': updated.nutrients?.toJson(),
    });
    try {
      await _sendWithRetry(
        (token) => _http.patch(
          Uri.parse('${ApiConfig.baseUrl}/logs/${Uri.encodeComponent(updated.id)}'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: body,
        ),
        userId: userId,
        failure: 'Failed to update entry',
      );
      _settle(generation, () => _pendingSaves.remove(updated.id));
      await _persistCache(userId);
    } catch (e) {
      _settle(generation, () => _pendingSaves.remove(updated.id));
      // Put back only this entry, so other changes made meanwhile survive.
      _rollback([for (final e in state) e.id == updated.id ? before : e], logDate);
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

    final generation = _generation;
    _pendingDeletes.add(id);
    try {
      final response = await _http.delete(
        // Encoded: older entries have the food's name in their id, and a
        // "/", "?" or "#" there sent the request to the wrong address.
        Uri.parse('${ApiConfig.baseUrl}/logs/${Uri.encodeComponent(id)}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      // 404: it is already gone on the server (an earlier attempt got through
      // but its answer was lost), which is what was asked for.
      if (response.statusCode != 204 && response.statusCode != 404) {
        throw Exception('Failed to remove entry: ${response.body}');
      }
      _settle(generation, () => _pendingDeletes.remove(id));
      await _persistCache(_userId);
    } catch (e) {
      _settle(generation, () => _pendingDeletes.remove(id));
      // Put back only this entry, where it was, so other changes made
      // meanwhile survive.
      final index = previous.indexWhere((e) => e.id == id);
      if (index >= 0 && generation == _generation && !state.any((e) => e.id == id)) {
        final restored = [...state];
        restored.insert(index.clamp(0, restored.length), previous[index]);
        _rollback(restored, logDate);
      }
      rethrow;
    }
  }

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
