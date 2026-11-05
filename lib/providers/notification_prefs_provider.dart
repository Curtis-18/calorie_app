import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_prefs.dart';
import '../services/notification_prefs_service.dart';

class NotificationPrefsState {
  const NotificationPrefsState({this.prefs, this.loading = true, this.error, this.saveError});

  final NotificationPrefs? prefs;
  final bool loading;

  /// Loading failed (nothing to show).
  final String? error;

  /// The last change could not be saved (it was rolled back).
  final String? saveError;
}

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefsState> {
  NotificationPrefsNotifier(this._service) : super(const NotificationPrefsState()) {
    load();
  }

  final NotificationPrefsService _service;
  int _version = 0;

  Future<void> load() async {
    state = NotificationPrefsState(prefs: state.prefs, loading: true);
    try {
      final prefs = await _service.load();
      if (mounted) state = NotificationPrefsState(prefs: prefs, loading: false);
    } on NotificationPrefsException catch (e) {
      if (mounted) state = NotificationPrefsState(prefs: state.prefs, loading: false, error: e.message);
    }
  }

  /// Show [next] at once, then save [changes]. If saving fails the screen goes
  /// back to what it was and says so, so a switch never lies about the server.
  Future<void> change(NotificationPrefs next, Map<String, Object?> changes) async {
    final before = state.prefs;
    if (before == null) return;
    final mine = ++_version;
    state = NotificationPrefsState(prefs: next, loading: false);
    try {
      final saved = await _service.update(changes);
      // A newer change is already on screen: let it win.
      if (mounted && mine == _version) state = NotificationPrefsState(prefs: saved, loading: false);
    } on NotificationPrefsException catch (e) {
      if (mounted && mine == _version) {
        state = NotificationPrefsState(prefs: before, loading: false, saveError: e.message);
      }
    }
  }
}

final notificationPrefsProvider =
    StateNotifierProvider.autoDispose<NotificationPrefsNotifier, NotificationPrefsState>(
  (ref) => NotificationPrefsNotifier(NotificationPrefsService()),
);
