import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress.dart';
import '../services/progress_service.dart';
import '../services/user_cache.dart';
import 'food_log_provider.dart';

/// The signed-in user's streak, level and achievements, plus a stream of
/// one-off celebrations (perfect day, new badge, level up).
///
/// Refreshes when the user changes and shortly after the food log changes,
/// since every score is derived server-side from the logs.
class ProgressNotifier extends StateNotifier<ProgressData?> {
  ProgressNotifier({
    Future<ProgressData?> Function()? fetch,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
    this.debounce = const Duration(milliseconds: 700),
  })  : _fetch = fetch ?? ProgressService().fetch,
        super(null) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser((currentUserId ?? UserCache.currentUserId)());
  }

  final Future<ProgressData?> Function() _fetch;
  final Duration debounce;
  final _celebrations = StreamController<Celebration>.broadcast();
  StreamSubscription<String?>? _authSubscription;
  Timer? _debounceTimer;
  String? _userId;
  int _generation = 0;

  Stream<Celebration> get celebrations => _celebrations.stream;

  static String ledgerKey(String userId) => 'progress_seen:$userId';

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    state = null;
    if (userId != null) refresh();
  }

  /// Refresh after a short pause, coalescing a burst of log changes
  /// (e.g. saving four foods from one photo) into one request.
  void refreshSoon() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, refresh);
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    final generation = _generation;
    final data = await _fetch();
    if (!mounted || generation != _generation || data == null) return;
    state = data;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || generation != _generation) return;
    CelebrationLedger? seen;
    final raw = prefs.getString(ledgerKey(userId));
    if (raw != null) {
      try {
        seen = CelebrationLedger.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    final (events, ledger) = diffCelebrations(data, seen);
    await prefs.setString(ledgerKey(userId), jsonEncode(ledger.toJson()));
    for (final event in events) {
      if (!_celebrations.isClosed) _celebrations.add(event);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _debounceTimer?.cancel();
    _celebrations.close();
    super.dispose();
  }
}

final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressData?>((ref) {
  final notifier = ProgressNotifier();
  ref.listen<List<Object>>(foodLogProvider, (_, _) => notifier.refreshSoon());
  return notifier;
});
