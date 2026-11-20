import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../l10n/app_strings.dart';
import 'browser_push/browser_push.dart';
import 'language_client.dart';

/// Whether the server can notify browsers, and the key a browser subscribes with.
class WebPushInfo {
  const WebPushInfo({required this.enabled, this.publicKey});

  final bool enabled;
  final String? publicKey;
}

/// Turning browser notifications on and off, through the backend. The browser
/// part (permission, subscription) is [BrowserPush]; this tells the server
/// which browser to notify. Nothing here throws: a failure is a message or a
/// "no" the screen can show.
class WebPushService {
  WebPushService({BrowserPush? browser, this._client, this._tokenProvider, this._utcOffset}) : browser = browser ?? createBrowserPush();

  final BrowserPush browser;
  final http.Client? _client;
  final String? Function()? _tokenProvider;
  final int Function()? _utcOffset;

  static String? _supabaseToken() => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<http.Response?> _send(Future<http.Response> Function(http.Client, Map<String, String>) call) async {
    final String? token;
    try {
      token = (_tokenProvider ?? _supabaseToken)();
    } catch (_) {
      return null;
    }
    if (token == null) return null;
    final client = _client ?? languageClient();
    try {
      return await call(client, {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<WebPushInfo> info() async {
    final r = await _send((c, h) => c.get(_uri('/notifications/web-push'), headers: h));
    if (r == null || r.statusCode != 200) return const WebPushInfo(enabled: false);
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final key = body['public_key'] as String?;
      return WebPushInfo(enabled: body['enabled'] == true && key != null && key.isNotEmpty, publicKey: key);
    } catch (_) {
      return const WebPushInfo(enabled: false);
    }
  }

  Future<bool> _register(String subscription) async {
    final offset = (_utcOffset ?? () => DateTime.now().timeZoneOffset.inMinutes)();
    final r = await _send((c, h) => c.post(
          _uri('/notifications/devices'),
          headers: h,
          body: jsonEncode({'token': subscription, 'platform': 'web', 'utc_offset_minutes': offset}),
        ));
    return r != null && r.statusCode == 204;
  }

  /// Ask permission, subscribe, tell the server. Returns null when it worked,
  /// 'denied' when the person said no, or a message to show.
  Future<String?> enable(String publicKey) async {
    String? subscription;
    try {
      subscription = await browser.subscribe(publicKey);
    } catch (_) {
      return tr("Couldn't turn notifications on. Please try again.");
    }
    if (subscription == null) return 'denied';
    if (await _register(subscription)) return null;
    // The server did not get it, so the browser should not look subscribed.
    await browser.unsubscribe();
    return tr("Couldn't turn notifications on. Please try again.");
  }

  /// Stop notifying this browser, in the browser and on the server.
  Future<void> disable() async {
    final subscription = await browser.currentSubscription();
    await browser.unsubscribe();
    if (subscription != null) await _forget(subscription);
  }

  Future<void> _forget(String subscription) async {
    await _send((c, h) => c.post(_uri('/notifications/devices/remove'), headers: h, body: jsonEncode({'token': subscription})));
  }

  /// On sign-out: this account must stop getting notifications on this browser.
  /// The browser keeps its subscription, so the next sign-in can register it again.
  Future<void> forgetThisBrowser() async {
    try {
      final subscription = await browser.currentSubscription();
      if (subscription != null) await _forget(subscription);
    } catch (_) {}
  }

  /// When the app opens: a browser that was allowed is registered again for
  /// whoever is signed in now (the server moves it to them), with today's time
  /// zone. Quiet by design.
  Future<void> refreshRegistration() async {
    try {
      if (!browser.supported || browser.permission != 'granted') return;
      final subscription = await browser.currentSubscription();
      if (subscription != null) await _register(subscription);
    } catch (_) {}
  }

  /// One notification now, to check it works. 'sent', 'dry_run', 'no_device',
  /// 'failed', 'limited' (too many tests) or null when the server was not reached.
  Future<String?> sendTest() async {
    final r = await _send((c, h) => c.post(_uri('/notifications/test'), headers: h));
    if (r == null) return null;
    if (r.statusCode == 429) return 'limited';
    if (r.statusCode != 200) return 'failed';
    try {
      return (jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>)['status'] as String?;
    } catch (_) {
      return null;
    }
  }
}
