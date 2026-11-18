import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/user_cache.dart';
import '../services/whats_new_service.dart';

/// Whether the signed-in person has an unopened "What's new". Follows the user,
/// so one person opening it never clears it for the next.
class WhatsNewNotifier extends StateNotifier<bool> {
  WhatsNewNotifier({String? Function()? currentUserId, Stream<String?>? userIdChanges}) : super(false) {
    // Tolerates a Supabase that isn't started (a screen under test): no dot.
    try {
      _subscription = (userIdChanges ?? UserCache.userIdChanges()).listen(_onUser);
      _onUser((currentUserId ?? UserCache.currentUserId)());
    } catch (_) {}
  }

  StreamSubscription<String?>? _subscription;
  String? _userId;
  int _generation = 0;

  Future<void> _onUser(String? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    final generation = ++_generation;
    state = false;
    if (userId == null) return;
    bool unread;
    try {
      unread = await WhatsNewService.hasUnread(userId);
    } catch (_) {
      return;
    }
    if (mounted && generation == _generation) state = unread;
  }

  /// Opened: clear the dot.
  Future<void> markSeen() async {
    final userId = _userId;
    state = false;
    if (userId == null) return;
    try {
      await WhatsNewService.markSeen(userId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final whatsNewProvider = StateNotifierProvider<WhatsNewNotifier, bool>((ref) => WhatsNewNotifier());
