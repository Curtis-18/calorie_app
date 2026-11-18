import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/week_budget.dart';
import '../services/budget_service.dart';
import '../services/user_cache.dart';
import 'food_log_provider.dart';

class BudgetState {
  const BudgetState({this.prefs, this.week});

  final BudgetPrefs? prefs;
  final WeekBudgetData? week;

  /// The flexible allowance only applies when the person turned it on and the
  /// server has answered; otherwise everything behaves as the daily target.
  bool get weekly => (prefs?.weekly ?? false) && week != null && week!.weekly;
}

/// The signed-in person's weekly budget. Refreshes when they change and a
/// moment after the food log changes (the server derives it from the logs).
/// Never an error state: with no answer the app shows the plain daily target.
class BudgetNotifier extends StateNotifier<BudgetState> {
  BudgetNotifier({
    BudgetService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
    this.debounce = const Duration(milliseconds: 900),
  })  : _service = service ?? BudgetService(),
        super(const BudgetState()) {
    // Tolerates a Supabase that isn't started (a screen under test): the
    // budget then simply stays off.
    try {
      _subscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
      _onUser((currentUserId ?? UserCache.currentUserId)());
    } catch (_) {}
  }

  final BudgetService _service;
  final Duration debounce;
  StreamSubscription<String?>? _subscription;
  Timer? _timer;
  String? _userId;
  int _generation = 0;

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    state = const BudgetState();
    if (userId != null) refresh();
  }

  void refreshSoon() {
    _timer?.cancel();
    _timer = Timer(debounce, refresh);
  }

  Future<void> refresh() async {
    if (_userId == null) return;
    final generation = _generation;
    final results = await Future.wait([_service.week(), _service.prefs()]);
    if (!mounted || generation != _generation) return;
    final week = results[0] as WeekBudgetData?;
    final prefs = results[1] as BudgetPrefs?;
    // Keep the last good answer if this one failed.
    state = BudgetState(prefs: prefs ?? state.prefs, week: week ?? state.week);
  }

  /// Save choices, then refresh. Returns a message on failure (nothing changed).
  Future<String?> update(Map<String, Object?> changes) async {
    final error = await _service.save(changes);
    if (error != null) return error;
    await refresh();
    return null;
  }

  /// "Yes, spread it" on the nudge card: turn the weekly allowance on.
  Future<String?> spread() => update({'mode': 'weekly'});

  /// "Not now": no more nudges for the rest of this week.
  Future<String?> dismissNudge() {
    final week = state.week;
    if (week == null) return Future.value(null);
    return update({'dismiss_week': week.weekStart.toIso8601String().substring(0, 10)});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}

final budgetProvider = StateNotifierProvider<BudgetNotifier, BudgetState>((ref) {
  final notifier = BudgetNotifier();
  ref.listen<List<Object>>(foodLogProvider, (_, _) => notifier.refreshSoon());
  return notifier;
});
