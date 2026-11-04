import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friends.dart';
import '../services/friends_service.dart';
import '../services/user_cache.dart';

/// The signed-in user's friends and requests. Follows the user like the
/// other providers, so one person's list is never shown to the next.
class FriendsNotifier extends StateNotifier<AsyncValue<FriendsData>> {
  FriendsNotifier({
    FriendsService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
  })  : _service = service ?? FriendsService(),
        super(const AsyncValue.loading()) {
    _authSubscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
    _onUser((currentUserId ?? UserCache.currentUserId)());
  }

  final FriendsService _service;
  StreamSubscription<String?>? _authSubscription;
  String? _userId;
  int _generation = 0;

  FriendsService get service => _service;

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
      final data = await _service.load();
      if (mounted && generation == _generation) state = AsyncValue.data(data);
    } catch (e, st) {
      // Keep showing the last good list if a refresh fails.
      if (mounted && generation == _generation && !state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// Run [action], then refresh. The action's error (a readable
  /// [FriendsException]) is rethrown for the screen to show.
  Future<T> _then<T>(Future<T> Function() action) async {
    final generation = _generation;
    try {
      return await action();
    } finally {
      if (mounted && generation == _generation) await load();
    }
  }

  Future<RequestResult> sendRequest(String username) => _then(() => _service.sendRequest(username));
  Future<void> accept(Person p) => _then(() => _service.accept(p.friendshipId!));
  Future<void> decline(Person p) => _then(() => _service.decline(p.friendshipId!));
  Future<void> remove(Person p) => _then(() => _service.remove(p.friendshipId!));
  Future<void> block(Person p) => _then(() => _service.block(p.friendshipId!));

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, AsyncValue<FriendsData>>((ref) => FriendsNotifier());

/// How many requests are waiting for an answer; drives the tab badge.
final pendingRequestCountProvider = Provider<int>((ref) {
  return ref.watch(friendsProvider).valueOrNull?.incoming.length ?? 0;
});
