import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/food_region_service.dart';
import '../services/user_cache.dart';

/// Where the signed-in person mostly eats (a `foodRegions` key) or null.
///
/// Sent with every photo scan as context, so the scan itself never waits on a
/// lookup. Remembered on the device per person and refreshed from the server,
/// so a new phone picks it up. Never an error state: with no answer the scan
/// simply goes without a hint.
class FoodRegionNotifier extends StateNotifier<String?> {
  FoodRegionNotifier({
    FoodRegionService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
    Future<SharedPreferences> Function()? prefs,
  })  : _service = service ?? FoodRegionService(),
        _prefs = prefs ?? SharedPreferences.getInstance,
        super(null) {
    // Tolerates a Supabase that isn't started (a screen under test).
    try {
      _subscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
      _onUser((currentUserId ?? UserCache.currentUserId)());
    } catch (_) {}
  }

  static String storageKey(String userId) => 'food_region:$userId';

  final FoodRegionService _service;
  final Future<SharedPreferences> Function() _prefs;
  StreamSubscription<String?>? _subscription;
  String? _userId;
  int _generation = 0;

  Future<void> _onUser(String? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    final generation = ++_generation;
    state = null;
    if (userId == null) return;
    try {
      final stored = (await _prefs()).getString(storageKey(userId));
      if (mounted && generation == _generation && stored != null && stored.isNotEmpty) state = stored;
    } catch (_) {}
    final answer = await _service.fetch();
    if (!mounted || generation != _generation || !answer.answered) return;
    state = answer.region;
    await _remember(userId, answer.region);
  }

  Future<void> _remember(String userId, String? region) async {
    try {
      final prefs = await _prefs();
      if (region == null) {
        await prefs.remove(storageKey(userId));
      } else {
        await prefs.setString(storageKey(userId), region);
      }
    } catch (_) {}
  }

  /// Choose (or clear with null) where the person mostly eats. Returns a
  /// message on failure; nothing changes then.
  Future<String?> set(String? region) async {
    final error = await _service.save(region);
    if (error != null) return error;
    if (!mounted) return null;
    state = region;
    final userId = _userId;
    if (userId != null) await _remember(userId, region);
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final foodRegionProvider = StateNotifierProvider<FoodRegionNotifier, String?>((ref) => FoodRegionNotifier());
