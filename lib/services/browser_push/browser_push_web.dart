import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'browser_push_base.dart';

BrowserPush createBrowserPush() => _WebBrowserPush();

/// The push service worker lives in its own folder so its scope (`push/`) never
/// collides with the one Flutter registers for the app itself.
const _scriptUrl = 'push/sw.js';
const _scope = 'push/';

class _WebBrowserPush implements BrowserPush {
  JSObject get _navigator => web.window.navigator as JSObject;

  @override
  bool get supported =>
      globalContext.has('Notification') &&
      globalContext.has('PushManager') &&
      _navigator.has('serviceWorker');

  @override
  bool get needsHomeScreenInstall {
    if (supported) return false;
    final ua = web.window.navigator.userAgent;
    final ios = RegExp(r'iPhone|iPad|iPod').hasMatch(ua) ||
        (web.window.navigator.platform == 'MacIntel' && web.window.navigator.maxTouchPoints > 1);
    final standalone = web.window.matchMedia('(display-mode: standalone)').matches ||
        (_navigator.has('standalone') && _navigator['standalone'] == true.toJS);
    return ios && !standalone;
  }

  @override
  String get permission => supported ? web.Notification.permission : 'denied';

  Future<web.ServiceWorkerRegistration?> _registration() async {
    final found = await web.window.navigator.serviceWorker.getRegistration(_scope).toDart;
    return found;
  }

  /// A registration whose worker is running, so subscribing right away works.
  Future<web.ServiceWorkerRegistration> _ready() async {
    final registration = await web.window.navigator.serviceWorker
        .register(_scriptUrl.toJS, web.RegistrationOptions(scope: _scope))
        .toDart;
    if (registration.active != null) return registration;
    final worker = registration.installing ?? registration.waiting;
    if (worker == null) return registration;
    final done = Completer<void>();
    late final JSFunction listener;
    listener = ((web.Event _) {
      if (worker.state == 'activated' && !done.isCompleted) done.complete();
    }).toJS;
    worker.addEventListener('statechange', listener);
    if (worker.state == 'activated') done.complete();
    await done.future.timeout(const Duration(seconds: 15));
    return registration;
  }

  static Uint8List _decodeKey(String key) => Uint8List.fromList(base64Url.decode(base64Url.normalize(key)));

  String _json(web.PushSubscription subscription) {
    final stringify = (globalContext['JSON'] as JSObject);
    return (stringify.callMethod('stringify'.toJS, subscription) as JSString).toDart;
  }

  @override
  Future<String?> subscribe(String publicKey) async {
    if (!supported) return null;
    // First, before anything is awaited: Safari only asks while it is still
    // inside the tap that started this.
    final answer = (await web.Notification.requestPermission().toDart).toDart;
    if (answer != 'granted') return null;

    final registration = await _ready();
    final options = web.PushSubscriptionOptionsInit(
      userVisibleOnly: true,
      applicationServerKey: _decodeKey(publicKey).toJS,
    );
    try {
      return _json(await registration.pushManager.subscribe(options).toDart);
    } catch (_) {
      // A subscription made with another key blocks a new one: drop it, retry once.
      final old = await registration.pushManager.getSubscription().toDart;
      if (old == null) rethrow;
      await old.unsubscribe().toDart;
      return _json(await registration.pushManager.subscribe(options).toDart);
    }
  }

  @override
  Future<String?> currentSubscription() async {
    if (!supported) return null;
    try {
      final registration = await _registration();
      final subscription = await registration?.pushManager.getSubscription().toDart;
      return subscription == null ? null : _json(subscription);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> unsubscribe() async {
    if (!supported) return;
    try {
      final registration = await _registration();
      final subscription = await registration?.pushManager.getSubscription().toDart;
      await subscription?.unsubscribe().toDart;
    } catch (_) {}
  }
}
