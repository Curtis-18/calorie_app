import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'pwa_install_base.dart';

PwaInstall createPwaInstall() => _WebInstall();

/// `web/index.html` keeps the browser's `beforeinstallprompt` event on
/// `window.__nustreakInstall` (it fires early, before this code runs) and
/// announces changes with a `nustreak-install-change` event.
class _WebInstall implements PwaInstall {
  _WebInstall() {
    web.window.addEventListener(
      'nustreak-install-change',
      ((web.Event _) {
        if (!_changes.isClosed) _changes.add(null);
      }).toJS,
    );
  }

  final _changes = StreamController<void>.broadcast();

  JSObject get _window => web.window as JSObject;

  JSObject? get _event {
    final found = _window.getProperty<JSAny?>('__nustreakInstall'.toJS);
    return found as JSObject?;
  }

  bool get _standalone =>
      web.window.matchMedia('(display-mode: standalone)').matches ||
      web.window.matchMedia('(display-mode: fullscreen)').matches ||
      web.window.matchMedia('(display-mode: minimal-ui)').matches ||
      (_window.getProperty<JSAny?>('navigator'.toJS) as JSObject).getProperty<JSAny?>('standalone'.toJS) == true.toJS;

  bool get _ios {
    final ua = web.window.navigator.userAgent;
    return RegExp(r'iPhone|iPad|iPod').hasMatch(ua) ||
        (web.window.navigator.platform == 'MacIntel' && web.window.navigator.maxTouchPoints > 1);
  }

  @override
  InstallMode get mode {
    if (_standalone) return InstallMode.none;
    if (_event != null) return InstallMode.prompt;
    if (_ios) return InstallMode.ios;
    return InstallMode.none;
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<bool> prompt() async {
    final event = _event;
    if (event == null) return false;
    try {
      event.callMethod<JSAny?>('prompt'.toJS);
      final choice = await (event.getProperty<JSAny?>('userChoice'.toJS) as JSPromise<JSAny?>).toDart;
      final outcome = (choice as JSObject).getProperty<JSAny?>('outcome'.toJS);
      // One event, one use: a second prompt needs the browser to fire it again.
      _window.setProperty('__nustreakInstall'.toJS, null);
      if (!_changes.isClosed) _changes.add(null);
      return outcome != null && (outcome as JSString).toDart == 'accepted';
    } catch (_) {
      return false;
    }
  }
}
