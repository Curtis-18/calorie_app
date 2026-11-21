import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/providers/notify_prompt_provider.dart';
import 'package:calorie_app/providers/pwa_install_provider.dart';
import 'package:calorie_app/providers/web_push_provider.dart';
import 'package:calorie_app/services/browser_push/browser_push.dart';
import 'package:calorie_app/services/pwa_install/pwa_install.dart';
import 'package:calorie_app/services/web_push_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/home_prompt.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
const _sub = '{"endpoint":"https://fcm.googleapis.com/fcm/send/abc","keys":{"p256dh":"k","auth":"a"}}';

class FakeBrowser implements BrowserPush {
  FakeBrowser({this.isSupported = true, this.install = false, this.perm = 'default', this.allow = true});

  bool isSupported, install, allow;
  String perm;
  String? sub;

  @override
  bool get supported => isSupported;
  @override
  bool get needsHomeScreenInstall => install;
  @override
  String get permission => perm;
  @override
  Future<String?> subscribe(String publicKey) async {
    perm = allow ? 'granted' : 'denied';
    return allow ? sub = _sub : null;
  }

  @override
  Future<String?> currentSubscription() async => sub;
  @override
  Future<void> unsubscribe() async => sub = null;
}

class FakeInstall implements PwaInstall {
  FakeInstall(this.m);
  final InstallMode m;
  @override
  InstallMode get mode => m;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<bool> prompt() async => true;
}

class Server {
  final registered = <Map<String, dynamic>>[];
  bool enabled = true;
  MockClient get client => MockClient((r) async {
        if (r.url.path == '/notifications/web-push') {
          return http.Response(jsonEncode({'enabled': enabled, 'public_key': enabled ? 'KEY' : null}), 200);
        }
        if (r.url.path == '/notifications/devices') {
          registered.add(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response('', 204);
        }
        return http.Response('', 404);
      });
}

Future<ProviderContainer> mount(
  WidgetTester tester,
  FakeBrowser browser,
  Server server, {
  InstallMode install = InstallMode.none,
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    webPushProvider.overrideWith(
      (ref) => WebPushNotifier(WebPushService(browser: browser, client: server.client, tokenProvider: () => 't', utcOffset: () => 180)),
    ),
    installProvider.overrideWith((ref) => InstallNotifier(install: FakeInstall(install))),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: CupertinoApp(
      theme: AppTheme.cupertino,
      home: const CupertinoPageScaffold(child: SafeArea(child: Padding(padding: EdgeInsets.all(24), child: HomePrompt()))),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

final notifyCard = find.byKey(const ValueKey('notify_card'));
final installCard = find.byKey(const ValueKey('install_card'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the notifications card', () {
    testWidgets('a browser that can notify, not yet asked: the card is offered', (tester) async {
      await mount(tester, FakeBrowser(), Server());
      expect(notifyCard, findsOneWidget);
      expect(find.text('Never miss a bite'), findsOneWidget);
      expect(find.text('Turn on'), findsOneWidget);
    }, variant: ios);

    testWidgets('Turn on asks the browser, registers it with the server and the card goes away', (tester) async {
      final browser = FakeBrowser();
      final server = Server();
      await mount(tester, browser, server);
      await tester.tap(find.byKey(const ValueKey('notify_card_on')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(server.registered.single['token'], _sub);
      expect(server.registered.single['utc_offset_minutes'], 180, reason: 'so quiet hours follow their clock');
      expect(notifyCard, findsNothing);
    }, variant: ios);

    testWidgets('a "no" in the browser removes the card and registers nothing', (tester) async {
      final server = Server();
      await mount(tester, FakeBrowser(allow: false), server);
      await tester.tap(find.byKey(const ValueKey('notify_card_on')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(server.registered, isEmpty);
      expect(notifyCard, findsNothing, reason: 'blocked browsers are not nagged');
    }, variant: ios);

    testWidgets('already on, blocked, or unable: no card', (tester) async {
      final on = FakeBrowser(perm: 'granted')..sub = _sub;
      await mount(tester, on, Server());
      expect(notifyCard, findsNothing);
    }, variant: ios);

    testWidgets('a browser that blocks notifications is not asked again', (tester) async {
      await mount(tester, FakeBrowser(perm: 'denied'), Server());
      expect(notifyCard, findsNothing);
    }, variant: ios);

    testWidgets('a browser with no push at all (or a server with push off) shows no card', (tester) async {
      await mount(tester, FakeBrowser(isSupported: false), Server());
      expect(notifyCard, findsNothing);
    }, variant: ios);

    testWidgets('the server not set up for push means no card', (tester) async {
      await mount(tester, FakeBrowser(), Server()..enabled = false);
      expect(notifyCard, findsNothing);
    }, variant: ios);

    testWidgets('Not now puts it away, remembers that, and the Home Screen question takes its place', (tester) async {
      final container = await mount(tester, FakeBrowser(), Server(), install: InstallMode.prompt);
      expect(notifyCard, findsOneWidget);
      expect(installCard, findsNothing, reason: 'one question at a time');
      await tester.tap(find.byKey(const ValueKey('notify_card_dismiss')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(notifyCard, findsNothing);
      expect(installCard, findsOneWidget);
      expect(container.read(notifyPromptHiddenProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotifyPromptNotifier.dismissedKey), isNotNull);
    }, variant: ios);

    testWidgets('on an iPhone not yet installed, the Home Screen card comes first (notifications need it)', (tester) async {
      await mount(tester, FakeBrowser(isSupported: false, install: true), Server(), install: InstallMode.ios);
      expect(notifyCard, findsNothing);
      expect(installCard, findsOneWidget);
    }, variant: ios);

    testWidgets('after notifications are on, the Home Screen card shows', (tester) async {
      await mount(tester, FakeBrowser(perm: 'granted')..sub = _sub, Server(), install: InstallMode.prompt);
      expect(notifyCard, findsNothing);
      expect(installCard, findsOneWidget);
    }, variant: ios);
  });

  group('how long "Not now" lasts', () {
    Future<NotifyPromptNotifier> make(DateTime now) async {
      final n = NotifyPromptNotifier(now: () => now);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return n;
    }

    test('hidden at first, shown when nothing was dismissed', () async {
      final n = await make(DateTime(2026, 11, 21));
      expect(n.state, isFalse);
    });

    test('after Not now it stays away for a week, then asks again', () async {
      final start = DateTime(2026, 11, 21);
      final a = await make(start);
      await a.dismiss();
      expect((await make(start.add(const Duration(days: 6)))).state, isTrue);
      expect((await make(start.add(const Duration(days: 8)))).state, isFalse);
    });
  });
}
