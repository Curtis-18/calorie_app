import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/insights.dart';
import '../services/insights_service.dart';
import 'food_log_provider.dart';

typedef InsightsFetcher = Future<InsightsData> Function({bool refresh});

/// Insights for whoever is signed in right now.
///
/// The provider is global and outlives sign-out (the ProviderScope wraps the
/// whole app), and it used to load exactly once. After user A signed out and
/// user B signed in on the same device, B was shown A's narrative, tips and
/// weekly chart until a manual refresh. It now follows the signed-in user:
/// cleared on sign-out, reloaded when a different user signs in, and left
/// alone on token refreshes for the same user (no extra Gemini call).
class InsightsNotifier extends StateNotifier<AsyncValue<InsightsData>> {
  InsightsNotifier({
    InsightsFetcher? fetch,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
  })  : _fetch = fetch ?? InsightsService().fetchInsights,
        super(const AsyncValue.loading()) {
    final userIds = userIdChanges ?? _supabaseUserIds();
    _authSubscription = userIds.listen(_onUser);
    _onUser((currentUserId ?? _supabaseCurrentUserId)());
  }

  final InsightsFetcher _fetch;
  StreamSubscription<String?>? _authSubscription;

  /// The user the current [state] belongs to, or is loading for.
  String? _userId;

  /// Bumped on every load and user change, so a slow response for a previous
  /// user (or an older request) can never overwrite newer state.
  int _generation = 0;

  static String? _supabaseCurrentUserId() =>
      Supabase.instance.client.auth.currentSession?.user.id;

  static Stream<String?> _supabaseUserIds() => Supabase.instance.client.auth.onAuthStateChange
      .map((auth) => auth.event == AuthChangeEvent.signedOut ? null : auth.session?.user.id);

  void _onUser(String? userId) {
    if (userId == _userId) return; // same user: token refresh, replayed event
    _userId = userId;
    if (userId == null) {
      _generation++;
      state = const AsyncValue.loading(); // drop the previous user's data
      return;
    }
    load();
  }

  Timer? _debounceTimer;

  /// Reload after a short pause, once the food log has changed. Quiet: the
  /// screen keeps showing the current insights until the new ones arrive,
  /// instead of flashing a skeleton. Coalesces a burst of changes into one
  /// request (each reload can cost a Gemini call).
  void reloadSoon({Duration debounce = const Duration(seconds: 3)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => load(quiet: true));
  }

  Future<void> load({bool refresh = false, bool quiet = false}) async {
    if (_userId == null) return; // nothing to load while signed out
    final generation = ++_generation;
    if (!quiet || !state.hasValue) state = const AsyncValue.loading();
    try {
      final data = await _fetch(refresh: refresh);
      if (mounted && generation == _generation) state = AsyncValue.data(data);
    } catch (e, st) {
      if (!mounted || generation != _generation) return;
      // A failed quiet reload keeps the insights already on screen.
      if (quiet && state.hasValue) return;
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

final insightsProvider = StateNotifierProvider<InsightsNotifier, AsyncValue<InsightsData>>((ref) {
  final notifier = InsightsNotifier();
  // Logging a meal changes what Insights should say.
  ref.listen<List<Object>>(foodLogProvider, (_, _) => notifier.reloadSoon());
  return notifier;
});
