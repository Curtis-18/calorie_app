import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workouts.dart';
import '../services/user_cache.dart';
import '../services/workouts_service.dart';

/// A fresh random id for a log entry (the server treats a repeat of the same id as one entry).
String newMovementId([Random? random]) {
  final r = random ?? Random.secure();
  String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  final variant = '89ab'[r.nextInt(4)];
  return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
}

/// What the Workouts tab shows about the person's own movement.
class MoveState {
  const MoveState({this.week = const MoveWeek(), this.entries = const [], this.loaded = false});

  final MoveWeek week;
  final List<MovementEntry> entries;

  /// False until the first answer; the tab shows a quiet skeleton, not zeros.
  final bool loaded;
}

/// This week and the latest entries, for whoever is signed in. Follows the
/// person like the Notifications list does, so one person's week never shows
/// for the next.
class MoveNotifier extends StateNotifier<MoveState> {
  MoveNotifier({WorkoutsService? service, String? Function()? currentUserId, Stream<String?>? userIdChanges})
      : _service = service ?? WorkoutsService(),
        super(const MoveState()) {
    _subscription = (userIdChanges ?? _safeChanges()).listen(_onUser);
    _onUser((currentUserId ?? _safeUserId)());
  }

  static String? _safeUserId() {
    try {
      return UserCache.currentUserId();
    } catch (_) {
      return null;
    }
  }

  static Stream<String?> _safeChanges() {
    try {
      return UserCache.userIdChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  final WorkoutsService _service;
  StreamSubscription<String?>? _subscription;
  String? _userId;
  int _generation = 0;

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    state = const MoveState();
    if (userId != null) load();
  }

  Future<void> load() async {
    if (_userId == null) return;
    final generation = _generation;
    try {
      final results = await Future.wait([_service.week(), _service.entries()]);
      if (mounted && generation == _generation) {
        state = MoveState(week: results[0] as MoveWeek, entries: results[1] as List<MovementEntry>, loaded: true);
      }
    } catch (_) {
      // Keep what is on screen; the next refresh tries again.
    }
  }

  /// Log something. Returns the saved entry, or null when it couldn't be saved.
  Future<MovementEntry?> log({required int minutes, String? routineId, String? activity, String? intensity}) async {
    if (_userId == null) return null;
    try {
      final entry = await _service.log(
        id: newMovementId(),
        minutes: minutes,
        routineId: routineId,
        activity: activity,
        intensity: intensity,
      );
      await load();
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<bool> delete(String id) async {
    final before = state;
    state = MoveState(week: before.week, entries: [for (final e in before.entries) if (e.id != id) e], loaded: before.loaded);
    try {
      await _service.delete(id);
      unawaited(load());
      return true;
    } catch (_) {
      state = before;
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// One place that makes the service, so tests can swap in a fake server.
final workoutsServiceProvider = Provider<WorkoutsService>((ref) => WorkoutsService());

final moveProvider = StateNotifierProvider<MoveNotifier, MoveState>((ref) => MoveNotifier(service: ref.watch(workoutsServiceProvider)));

/// The curated library (cards, shortest first). Not per person.
final workoutLibraryProvider = FutureProvider<WorkoutLibrary>((ref) => ref.watch(workoutsServiceProvider).library());

final activityChoicesProvider = FutureProvider<List<ActivityChoice>>((ref) => ref.watch(workoutsServiceProvider).choices());
