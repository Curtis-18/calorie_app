import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../services/web_push_service.dart';

enum WebPushStatus {
  /// Still finding out.
  checking,

  /// Not a browser, or one that cannot show push (the phone builds, old browsers).
  unsupported,

  /// An iPhone or iPad: add the app to the Home Screen first.
  installFirst,

  /// The server is not set up to notify browsers.
  unavailable,

  /// The person said no in the browser; only the browser's settings can undo it.
  blocked,

  off,
  on,
}

class WebPushState {
  const WebPushState({this.status = WebPushStatus.checking, this.busy = false, this.message});

  final WebPushStatus status;
  final bool busy;

  /// The last thing worth telling the person (a failure, or "test sent").
  final String? message;

  WebPushState copyWith({WebPushStatus? status, bool? busy, String? message, bool clearMessage = false}) => WebPushState(
        status: status ?? this.status,
        busy: busy ?? this.busy,
        message: clearMessage ? null : (message ?? this.message),
      );
}

class WebPushNotifier extends StateNotifier<WebPushState> {
  WebPushNotifier(this._service) : super(const WebPushState()) {
    load();
  }

  final WebPushService _service;
  String? _publicKey;

  Future<void> load() async {
    final browser = _service.browser;
    if (!browser.supported) {
      state = WebPushState(status: browser.needsHomeScreenInstall ? WebPushStatus.installFirst : WebPushStatus.unsupported);
      return;
    }
    final info = await _service.info();
    if (!mounted) return;
    if (!info.enabled) {
      state = const WebPushState(status: WebPushStatus.unavailable);
      return;
    }
    // Fetched now, not on the tap: Safari only asks for permission inside the tap.
    _publicKey = info.publicKey;
    if (browser.permission == 'denied') {
      state = const WebPushState(status: WebPushStatus.blocked);
      return;
    }
    final subscribed = browser.permission == 'granted' && await browser.currentSubscription() != null;
    if (!mounted) return;
    state = WebPushState(status: subscribed ? WebPushStatus.on : WebPushStatus.off);
    if (subscribed) _service.refreshRegistration();
  }

  Future<void> enable() async {
    final key = _publicKey;
    if (key == null || state.busy) return;
    state = state.copyWith(busy: true, clearMessage: true);
    final result = await _service.enable(key);
    if (!mounted) return;
    if (result == null) {
      state = const WebPushState(status: WebPushStatus.on);
    } else if (result == 'denied') {
      // 'default' means they closed the question without answering: let them try again.
      final blocked = _service.browser.permission == 'denied';
      state = WebPushState(status: blocked ? WebPushStatus.blocked : WebPushStatus.off);
    } else {
      state = WebPushState(status: WebPushStatus.off, message: result);
    }
  }

  Future<void> disable() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearMessage: true);
    await _service.disable();
    if (mounted) state = const WebPushState(status: WebPushStatus.off);
  }

  Future<void> sendTest() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearMessage: true);
    final result = await _service.sendTest();
    if (!mounted) return;
    final message = switch (result) {
      'sent' => tr('Test sent. It should appear in a moment.'),
      'dry_run' => tr('Notifications are not switched on for the server yet.'),
      'no_device' => tr('Nothing to send to yet. Turn notifications on first.'),
      'limited' => tr("That's enough tests for now. Try again in a while."),
      _ => tr("The test couldn't be sent. Try again in a moment."),
    };
    state = state.copyWith(busy: false, message: message);
  }
}

final webPushProvider = StateNotifierProvider.autoDispose<WebPushNotifier, WebPushState>(
  (ref) => WebPushNotifier(WebPushService()),
);
