import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weight.dart';
import '../services/user_cache.dart';
import '../services/weight_service.dart';
import 'progress_provider.dart';
import 'user_provider.dart';

/// The signed-in user's weigh-ins. Follows the user like the other providers.
class WeightNotifier extends StateNotifier<AsyncValue<WeightHistory>> {
  WeightNotifier({
    WeightService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
    this.onTargetsChanged,
  })  : _service = service ?? WeightService(),
        super(const AsyncValue.loading()) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser((currentUserId ?? UserCache.currentUserId)());
  }

  final WeightService _service;

  /// Called after a weigh-in changed the targets (refresh profile, progress).
  final void Function()? onTargetsChanged;
  StreamSubscription<String?>? _authSubscription;
  String? _userId;
  int _generation = 0;

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    state = const AsyncValue.loading();
    if (userId != null) load();
  }

  Future<void> load() async {
    if (_userId == null) return;
    final generation = _generation;
    try {
      final history = await _service.fetch();
      if (mounted && generation == _generation) state = AsyncValue.data(history);
    } catch (e, st) {
      if (mounted && generation == _generation && !state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// Save a weigh-in; returns any notice for the user (e.g. goal switched).
  Future<String?> log(double weightKg, {DateTime? on}) async {
    final generation = _generation;
    final result = await _service.log(weightKg, on: on);
    if (!mounted || generation != _generation) return null;
    state = AsyncValue.data(result.history);
    onTargetsChanged?.call();
    return result.notice;
  }

  Future<void> delete(DateTime on) async {
    await _service.delete(on);
    onTargetsChanged?.call();
    await load();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final weightProvider = StateNotifierProvider<WeightNotifier, AsyncValue<WeightHistory>>((ref) {
  return WeightNotifier(
    onTargetsChanged: () {
      ref.read(userProfileProvider.notifier).refreshFromServer();
      ref.read(progressProvider.notifier).refreshSoon();
    },
  );
});

/// Display unit for weights, remembered on this device.
class WeightUnitNotifier extends StateNotifier<WeightUnit> {
  WeightUnitNotifier() : super(WeightUnit.kg) {
    SharedPreferences.getInstance().then((prefs) {
      final saved = WeightUnit.values.asNameMap()[prefs.getString(_key)];
      if (saved != null && mounted) state = saved;
    });
  }

  static const _key = 'weight_unit';

  Future<void> set(WeightUnit unit) async {
    state = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, unit.name);
  }
}

final weightUnitProvider = StateNotifierProvider<WeightUnitNotifier, WeightUnit>((ref) => WeightUnitNotifier());
