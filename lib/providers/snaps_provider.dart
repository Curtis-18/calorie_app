import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/snaps.dart';
import '../services/snaps_service.dart';
import '../services/user_cache.dart';

/// Snaps friends have sent the signed-in user in the last 24 hours.
class SnapInboxNotifier extends StateNotifier<AsyncValue<List<InboxSnap>>> {
  SnapInboxNotifier({
    SnapsService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
  })  : _service = service ?? SnapsService(),
        super(const AsyncValue.loading()) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser((currentUserId ?? UserCache.currentUserId)());
  }

  final SnapsService _service;
  StreamSubscription<String?>? _authSubscription;
  String? _userId;
  int _generation = 0;

  SnapsService get service => _service;

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
      final snaps = await _service.inbox();
      if (mounted && generation == _generation) state = AsyncValue.data(snaps);
    } catch (e, st) {
      // Keep the last good inbox if a refresh fails.
      if (mounted && generation == _generation && !state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  void _patch(String id, InboxSnap Function(InboxSnap) change) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([for (final s in current) s.id == id ? change(s) : s]);
  }

  /// Opened: mark it locally right away, tell the server in the background.
  Future<void> markViewed(InboxSnap snap) async {
    if (snap.viewed) return;
    _patch(snap.id, (s) => s.copyWith(viewed: true));
    try {
      await _service.markViewed(snap.id);
    } on SnapsException {
      // The sender just won't see "seen"; not worth interrupting the viewer.
    }
  }

  Future<void> react(InboxSnap snap, String emoji) async {
    _patch(snap.id, (s) => s.copyWith(reaction: emoji));
    await _service.react(snap.id, emoji);
  }

  Future<void> report(InboxSnap snap, {String? reason}) => _service.report(snap.id, reason: reason);

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final snapInboxProvider =
    StateNotifierProvider<SnapInboxNotifier, AsyncValue<List<InboxSnap>>>((ref) => SnapInboxNotifier());

/// Snaps waiting to be opened; drives the little dot on the Friends tab.
final unseenSnapCountProvider = Provider<int>((ref) {
  return ref.watch(snapInboxProvider).valueOrNull?.where((s) => !s.viewed).length ?? 0;
});
