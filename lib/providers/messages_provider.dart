import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/messages.dart';
import '../services/messages_service.dart';
import '../services/user_cache.dart';

/// Your conversations with friends and how many messages you haven't opened.
/// Drives the unread dots and the list of conversations.
class ConversationsNotifier extends StateNotifier<AsyncValue<ConversationsData>> {
  ConversationsNotifier({
    MessagesService? service,
    String? Function()? currentUserId,
    Stream<String?>? userIdChanges,
  })  : _service = service ?? MessagesService(),
        super(const AsyncValue.loading()) {
    _authSubscription = (userIdChanges ?? _safeChanges()).listen(_onUser);
    _onUser((currentUserId ?? _safeUserId)());
  }

  // Before sign-in is set up there is simply nobody to load messages for.
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

  final MessagesService _service;
  StreamSubscription<String?>? _authSubscription;
  String? _userId;
  int _generation = 0;

  MessagesService get service => _service;

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
      final data = await _service.conversations();
      if (mounted && generation == _generation) state = AsyncValue.data(data);
    } catch (e, st) {
      // Keep the last good list if a refresh fails.
      if (mounted && generation == _generation && !state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  /// You opened the conversation: clear its count at once and tell the server.
  Future<void> markRead(String friendId) async {
    final current = state.valueOrNull;
    final had = current?.forUser(friendId)?.unread ?? 0;
    if (current != null && had > 0) {
      state = AsyncValue.data(ConversationsData([
        for (final c in current.conversations) c.userId == friendId ? c.copyWith(unread: 0) : c,
      ]));
    }
    try {
      await _service.markRead(friendId);
    } on MessagesException {
      // They'll just still look unread on the next refresh; not worth interrupting.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final conversationsProvider = StateNotifierProvider<ConversationsNotifier, AsyncValue<ConversationsData>>(
  (ref) => ConversationsNotifier(),
);

/// Messages waiting to be opened; part of the dot on the Friends tab.
final unreadMessagesProvider = Provider<int>((ref) {
  return ref.watch(conversationsProvider).valueOrNull?.unreadTotal ?? 0;
});
