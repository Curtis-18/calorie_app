import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../services/activity_service.dart';
import '../services/user_cache.dart';
import 'whats_new_provider.dart';

/// Bites and reactions from friends, for the Notifications list and the dot on
/// the bell. Follows the signed-in person, so one person's list never shows
/// for the next.
class ActivityNotifier extends StateNotifier<ActivityData> {
  ActivityNotifier({ActivityService? service, String? Function()? currentUserId, Stream<String?>? userIdChanges})
      : _service = service ?? ActivityService(),
        super(const ActivityData()) {
    _subscription = (userIdChanges ?? _safeChanges()).listen(_onUser);
    _onUser((currentUserId ?? _safeUserId)());
  }

  // Before sign-in is set up there is simply nobody to load for.
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

  final ActivityService _service;
  StreamSubscription<String?>? _subscription;
  String? _userId;
  int _generation = 0;

  void _onUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    state = const ActivityData();
    if (userId != null) load();
  }

  Future<void> load() async {
    if (_userId == null) return;
    final generation = _generation;
    try {
      final data = await _service.list();
      if (mounted && generation == _generation) state = data;
    } catch (_) {
      // Keep what is on screen; the next refresh tries again.
    }
  }

  /// The list was opened: the dot goes at once, and the server is told.
  Future<void> markSeen() async {
    if (_userId == null) return;
    state = ActivityData(items: [for (final i in state.items) i.asSeen()], unread: 0);
    try {
      await _service.markSeen();
    } catch (_) {
      // It will look unread again on the next refresh; not worth interrupting.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityData>((ref) => ActivityNotifier());

/// The dot on the bell: an unread "What's new", or a bite or reaction you haven't seen.
final bellDotProvider = Provider<bool>((ref) => ref.watch(whatsNewProvider) || ref.watch(activityProvider).unread > 0);
