import 'dart:convert';

import 'package:calorie_app/models/notification_prefs.dart';
import 'package:calorie_app/providers/notification_prefs_provider.dart';
import 'package:calorie_app/providers/web_push_provider.dart';
import 'package:calorie_app/screens/notification_settings_screen.dart';
import 'package:calorie_app/services/browser_push/browser_push.dart';
import 'package:calorie_app/services/notification_prefs_service.dart';
import 'package:calorie_app/services/web_push_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _sub = '{"endpoint":"https://fcm.googleapis.com/fcm/send/abc","keys":{"p256dh":"k","auth":"a"}}';

class FakeBrowser implements BrowserPush {
  FakeBrowser({this.isSupported = true, this.install = false, this.perm = 'default', this.sub, this.allow = true});

  bool isSupported;
  bool install;
  String perm;
  String? sub;
  bool allow; // what the person answers when asked
  final subscribedWith = <String>[];
  int unsubscribed = 0;
  bool throwOnSubscribe = false;

  @override
  bool get supported => isSupported;
  @override
  bool get needsHomeScreenInstall => install;
  @override
  String get permission => perm;

  @override
  Future<String?> subscribe(String publicKey) async {
    if (throwOnSubscribe) throw StateError('boom');
    subscribedWith.add(publicKey);
    perm = allow ? 'granted' : 'denied';
    if (!allow) return null;
    return sub = _sub;
  }

  @override
  Future<String?> currentSubscription() async => sub;

  @override
  Future<void> unsubscribe() async {
    unsubscribed++;
    sub = null;
  }
}

/// A pretend backend for the web push routes.
class _Server {
  bool enabled = true;
  String key = 'PUBKEY';
  int registerStatus = 204;
  String testStatus = 'sent';
  int testHttp = 200;
  final registered = <Map<String, dynamic>>[];
  final removed = <Map<String, dynamic>>[];
  int infoCalls = 0;

  MockClient get client => MockClient((r) async {
        final path = r.url.path;
        if (path == '/notifications/web-push') {
          infoCalls++;
          return http.Response(jsonEncode({'enabled': enabled, 'public_key': enabled ? key : null}), 200);
        }
        if (path == '/notifications/devices') {
          registered.add(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response('', registerStatus);
        }
        if (path == '/notifications/devices/remove') {
          removed.add(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response('', 204);
        }
        if (path == '/notifications/test') return http.Response(jsonEncode({'status': testStatus}), testHttp);
        return http.Response('', 404);
      });
}

WebPushService _service(FakeBrowser browser, _Server server) =>
    WebPushService(browser: browser, client: server.client, tokenProvider: () => 't', utcOffset: () => 120);

Future<void> _settle(WidgetTester tester, [int steps = 8]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('service', () {
    test('enabling asks the browser, then tells the server which browser, with the time zone', () async {
      final browser = FakeBrowser();
      final server = _Server();
      expect(await _service(browser, server).enable('PUBKEY'), isNull);
      expect(browser.subscribedWith, ['PUBKEY']);
      expect(server.registered.single, {'token': _sub, 'platform': 'web', 'utc_offset_minutes': 120});
    });

    test('a "no" in the browser registers nothing', () async {
      final browser = FakeBrowser(allow: false);
      final server = _Server();
      expect(await _service(browser, server).enable('PUBKEY'), 'denied');
      expect(server.registered, isEmpty);
    });

    test('if the server did not get it, the browser is not left looking subscribed', () async {
      final browser = FakeBrowser();
      final server = _Server()..registerStatus = 500;
      expect(await _service(browser, server).enable('PUBKEY'), contains('Couldn\'t turn notifications on'));
      expect(browser.unsubscribed, 1);
      expect(browser.sub, isNull);
    });

    test('a browser error is a message, never a crash', () async {
      final browser = FakeBrowser()..throwOnSubscribe = true;
      expect(await _service(browser, _Server()).enable('K'), contains('Couldn\'t turn notifications on'));
    });

    test('disabling unsubscribes the browser and tells the server by body', () async {
      final browser = FakeBrowser(perm: 'granted', sub: _sub);
      final server = _Server();
      await _service(browser, server).disable();
      expect(browser.unsubscribed, 1);
      expect(server.removed.single, {'token': _sub});
    });

    test('signing out tells the server to stop, but the browser keeps its subscription', () async {
      final browser = FakeBrowser(perm: 'granted', sub: _sub);
      final server = _Server();
      await _service(browser, server).forgetThisBrowser();
      expect(server.removed.single, {'token': _sub});
      expect(browser.unsubscribed, 0);
      await _service(FakeBrowser(), server).forgetThisBrowser(); // nothing subscribed: nothing sent
      expect(server.removed, hasLength(1));
    });

    test('opening the app registers an allowed browser again, and only an allowed one', () async {
      final server = _Server();
      await _service(FakeBrowser(perm: 'granted', sub: _sub), server).refreshRegistration();
      expect(server.registered, hasLength(1));
      await _service(FakeBrowser(perm: 'default', sub: _sub), server).refreshRegistration();
      await _service(FakeBrowser(perm: 'granted'), server).refreshRegistration();
      await _service(FakeBrowser(isSupported: false, perm: 'granted', sub: _sub), server).refreshRegistration();
      expect(server.registered, hasLength(1));
    });

    test('the server saying push is off, or being unreachable, reads as not enabled', () async {
      expect((await _service(FakeBrowser(), _Server()..enabled = false).info()).enabled, isFalse);
      final down = WebPushService(
          browser: FakeBrowser(), client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't');
      expect((await down.info()).enabled, isFalse);
      final signedOut = WebPushService(browser: FakeBrowser(), client: _Server().client, tokenProvider: () => null);
      expect((await signedOut.info()).enabled, isFalse);
      final ok = await _service(FakeBrowser(), _Server()).info();
      expect((ok.enabled, ok.publicKey), (true, 'PUBKEY'));
    });

    test('a test notification reports what the server said', () async {
      final server = _Server();
      final service = _service(FakeBrowser(), server);
      for (final status in ['sent', 'dry_run', 'no_device', 'failed']) {
        server.testStatus = status;
        expect(await service.sendTest(), status);
      }
      server.testHttp = 429;
      expect(await service.sendTest(), 'limited');
      server.testHttp = 500;
      expect(await service.sendTest(), 'failed');
    });
  });

  group('provider', () {
    Future<WebPushNotifier> make(FakeBrowser browser, _Server server) async {
      final n = WebPushNotifier(_service(browser, server));
      addTearDown(n.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return n;
    }

    test('a browser that cannot do push, and an iPhone that must install first, are told apart', () async {
      expect((await make(FakeBrowser(isSupported: false), _Server())).state.status, WebPushStatus.unsupported);
      expect((await make(FakeBrowser(isSupported: false, install: true), _Server())).state.status, WebPushStatus.installFirst);
    });

    test('a server without push, a blocked site, a fresh browser and a subscribed one', () async {
      expect((await make(FakeBrowser(), _Server()..enabled = false)).state.status, WebPushStatus.unavailable);
      expect((await make(FakeBrowser(perm: 'denied'), _Server())).state.status, WebPushStatus.blocked);
      expect((await make(FakeBrowser(), _Server())).state.status, WebPushStatus.off);
      expect((await make(FakeBrowser(perm: 'granted'), _Server())).state.status, WebPushStatus.off); // allowed, not subscribed
      final server = _Server();
      final on = await make(FakeBrowser(perm: 'granted', sub: _sub), server);
      expect(on.state.status, WebPushStatus.on);
      expect(server.registered, hasLength(1), reason: 'registered again for whoever is signed in');
    });

    test('turning on subscribes with the key fetched up front; turning off forgets it', () async {
      final browser = FakeBrowser();
      final server = _Server();
      final n = await make(browser, server);
      await n.enable();
      expect(n.state.status, WebPushStatus.on);
      expect(browser.subscribedWith, ['PUBKEY']);
      await n.disable();
      expect(n.state.status, WebPushStatus.off);
      expect(server.removed, hasLength(1));
    });

    test('saying no blocks it; closing the question without answering lets them try again', () async {
      final no = await make(FakeBrowser(allow: false), _Server());
      await no.enable();
      expect(no.state.status, WebPushStatus.blocked);

      // A browser that returns null without changing the permission (the question was closed).
      final quiet = _QuietBrowser();
      final n2 = await make(quiet, _Server());
      await n2.enable();
      expect(n2.state.status, WebPushStatus.off);
    });

    test('a failure leaves it off with a message', () async {
      final n = await make(FakeBrowser(), _Server()..registerStatus = 500);
      await n.enable();
      expect(n.state.status, WebPushStatus.off);
      expect(n.state.message, contains('Couldn\'t turn notifications on'));
    });

    test('the test button explains each outcome in plain words', () async {
      final server = _Server();
      final n = await make(FakeBrowser(perm: 'granted', sub: _sub), server);
      await n.sendTest();
      expect(n.state.message, 'Test sent. It should appear in a moment.');
      server.testStatus = 'no_device';
      await n.sendTest();
      expect(n.state.message, contains('Turn notifications on first'));
      server.testStatus = 'dry_run';
      await n.sendTest();
      expect(n.state.message, contains('not switched on'));
      server.testHttp = 429;
      await n.sendTest();
      expect(n.state.message, contains('enough tests'));
      expect(n.state.busy, isFalse);
    });
  });

  group('settings screen', () {
    Future<void> open(WidgetTester tester, FakeBrowser browser, _Server server) async {
      tester.view.physicalSize = const Size(1179, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final prefsClient = MockClient((r) async => http.Response(
          jsonEncode({
            'friend_snaps': true, 'reactions': true, 'streak_reminders': true, 'milestones': true,
            'meal_nudge_hour': null, 'quiet_start': 22, 'quiet_end': 8, 'utc_offset_minutes': 0,
            'paused_until': null, 'daily_cap': 3,
          }),
          200));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          notificationPrefsProvider.overrideWith((ref) =>
              NotificationPrefsNotifier(NotificationPrefsService(client: prefsClient, tokenProvider: () => 't'))),
          webPushProvider.overrideWith((ref) => WebPushNotifier(_service(browser, server))),
        ],
        child: CupertinoApp(theme: AppTheme.cupertino, home: const NotificationSettingsScreen()),
      ));
      await _settle(tester);
    }

    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('offers the switch instead of the "once the app is on your phone" note', (tester) async {
      await open(tester, FakeBrowser(), _Server());
      expect(find.byKey(const ValueKey('switch_browser_push')), findsOneWidget);
      expect(find.byKey(const ValueKey('push_not_live')), findsNothing);
      expect(find.byKey(const ValueKey('push_test')), findsNothing);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_browser_push'))).value, isFalse);
    }, variant: ios);

    testWidgets('switching on subscribes, then a test can be sent', (tester) async {
      final browser = FakeBrowser();
      final server = _Server();
      await open(tester, browser, server);
      await tester.tap(find.byKey(const ValueKey('switch_browser_push')));
      await _settle(tester);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_browser_push'))).value, isTrue);
      expect(server.registered, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('push_test')));
      await _settle(tester);
      expect(find.text('Test sent. It should appear in a moment.'), findsOneWidget);
    }, variant: ios);

    testWidgets('switching off forgets the browser', (tester) async {
      final server = _Server();
      await open(tester, FakeBrowser(perm: 'granted', sub: _sub), server);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_browser_push'))).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('switch_browser_push')));
      await _settle(tester);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_browser_push'))).value, isFalse);
      expect(server.removed, hasLength(1));
    }, variant: ios);

    testWidgets('a blocked site and an iPhone that must install first each say what to do', (tester) async {
      await open(tester, FakeBrowser(perm: 'denied'), _Server());
      expect(find.byKey(const ValueKey('push_blocked')), findsOneWidget);
      expect(find.byKey(const ValueKey('switch_browser_push')), findsNothing);
    }, variant: ios);

    testWidgets('an iPhone browser tab is told to add the app to the Home Screen', (tester) async {
      await open(tester, FakeBrowser(isSupported: false, install: true), _Server());
      expect(find.byKey(const ValueKey('push_install_first')), findsOneWidget);
      expect(find.textContaining('Home Screen'), findsOneWidget);
    }, variant: ios);

    testWidgets('where push cannot work, the old note stays and nothing else shows', (tester) async {
      await open(tester, FakeBrowser(isSupported: false), _Server());
      expect(find.byKey(const ValueKey('push_not_live')), findsOneWidget);
      expect(find.byKey(const ValueKey('browser_push')), findsNothing);
      await open(tester, FakeBrowser(), _Server()..enabled = false);
      expect(find.byKey(const ValueKey('push_not_live')), findsOneWidget);
    }, variant: ios);

    test('the app promises no more than it does on phones', () => expect(NotificationPrefs.pushLive, isFalse));
  });
}

/// A browser that is asked and answers nothing (the question was closed).
class _QuietBrowser extends FakeBrowser {
  @override
  Future<String?> subscribe(String publicKey) async => null;
}
