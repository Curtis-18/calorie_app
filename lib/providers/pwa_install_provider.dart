import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pwa_install/pwa_install.dart';

/// What the install card and Settings row need to know.
class InstallState {
  const InstallState({this.mode = InstallMode.none, this.cardHidden = true});

  final InstallMode mode;

  /// The person closed the Home card (it comes back after [InstallNotifier.quietDays]).
  final bool cardHidden;

  bool get available => mode != InstallMode.none;
  bool get showCard => available && !cardHidden;

  InstallState copyWith({InstallMode? mode, bool? cardHidden}) =>
      InstallState(mode: mode ?? this.mode, cardHidden: cardHidden ?? this.cardHidden);
}

class InstallNotifier extends StateNotifier<InstallState> {
  InstallNotifier({PwaInstall? install, DateTime Function()? now})
      : _install = install ?? createPwaInstall(),
        _now = now ?? DateTime.now,
        super(const InstallState()) {
    state = state.copyWith(mode: _install.mode);
    _sub = _install.changes.listen((_) => state = state.copyWith(mode: _install.mode));
    _loadDismissal();
  }

  static const dismissedKey = 'install_card_dismissed_at';

  /// After "Not now" the card stays away this long.
  static const quietDays = 14;

  final PwaInstall _install;
  final DateTime Function() _now;
  StreamSubscription<void>? _sub;

  Future<void> _loadDismissal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(dismissedKey);
      final recent = at != null && _now().difference(DateTime.fromMillisecondsSinceEpoch(at)).inDays < quietDays;
      if (mounted) state = state.copyWith(cardHidden: recent);
    } catch (_) {
      // Storage unavailable: show the card; closing it still works this session.
      if (mounted) state = state.copyWith(cardHidden: false);
    }
  }

  /// "Not now" on the card.
  Future<void> dismissCard() async {
    state = state.copyWith(cardHidden: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(dismissedKey, _now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Opens the browser's install dialog; true if accepted. Does nothing on an
  /// iPhone, where the guide sheet is shown instead.
  Future<bool> install() async {
    if (state.mode != InstallMode.prompt) return false;
    final accepted = await _install.prompt();
    if (mounted) state = state.copyWith(mode: _install.mode);
    return accepted;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final installProvider = StateNotifierProvider<InstallNotifier, InstallState>((ref) => InstallNotifier());
