import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/snaps.dart';
import '../models/stories.dart';
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

  /// Who this inbox belongs to, and a note each time that changes. The
  /// stories provider follows these, so the two can never disagree.
  String? get userId => _userId;
  final _users = StreamController<String?>.broadcast();
  Stream<String?> get userChanges => _users.stream;

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    if (!_users.isClosed) _users.add(userId);
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
    _users.close();
    super.dispose();
  }
}

final snapInboxProvider =
    StateNotifierProvider<SnapInboxNotifier, AsyncValue<List<InboxSnap>>>((ref) => SnapInboxNotifier());

/// Snaps waiting to be opened; drives the little dot on the Friends tab.
final unseenSnapCountProvider = Provider<int>((ref) {
  return ref.watch(snapInboxProvider).valueOrNull?.where((s) => !s.viewed).length ?? 0;
});

/// Stories: your own and your friends', for the tray at the top of Friends.
class StoriesNotifier extends StateNotifier<AsyncValue<StoryFeed>> {
  StoriesNotifier({
    required this._service,
    required String? Function() currentUserId,
    required Stream<String?> userIdChanges,
  }) : super(const AsyncValue.loading()) {
    _subscription = userIdChanges.listen(_onUser);
    _onUser(currentUserId());
  }

  final SnapsService _service;
  StreamSubscription<String?>? _subscription;
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
      final feed = await _service.stories();
      if (mounted && generation == _generation) state = AsyncValue.data(feed);
    } catch (e, st) {
      // Keep the last good feed if a refresh fails.
      if (mounted && generation == _generation && !state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  void _patch(String id, Story Function(Story) change) {
    final feed = state.valueOrNull;
    if (feed == null) return;
    state = AsyncValue.data(StoryFeed(
      mine: feed.mine,
      friends: [
        for (final g in feed.friends) g.withStories([for (final s in g.stories) s.id == id ? change(s) : s]),
      ],
    ));
  }

  /// Opened: mark it locally right away, tell the server in the background.
  Future<void> markViewed(String storyId) async {
    _patch(storyId, (s) => s.copyWith(viewed: true));
    try {
      await _service.markStoryViewed(storyId);
    } on SnapsException {
      // They just won't show as having seen it; not worth interrupting the viewer.
    }
  }

  Future<void> react(String storyId, String emoji) async {
    _patch(storyId, (s) => s.copyWith(viewed: true, reaction: emoji));
    await _service.reactToStory(storyId, emoji);
  }

  Future<void> report(String storyId) => _service.reportStory(storyId);

  /// Take one of your own photos off your story.
  Future<void> delete(String storyId) async {
    await _service.deleteStory(storyId);
    final feed = state.valueOrNull;
    if (feed != null && mounted) {
      state = AsyncValue.data(
        StoryFeed(mine: feed.mine.where((s) => s.id != storyId).toList(), friends: feed.friends),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final storiesProvider = StateNotifierProvider<StoriesNotifier, AsyncValue<StoryFeed>>((ref) {
  final inbox = ref.watch(snapInboxProvider.notifier);
  return StoriesNotifier(
    service: inbox.service,
    currentUserId: () => inbox.userId,
    userIdChanges: inbox.userChanges,
  );
});
