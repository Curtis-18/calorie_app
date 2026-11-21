import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:calorie_app/providers/pwa_install_provider.dart';
import 'package:calorie_app/services/app_shortcut.dart';
import 'package:calorie_app/services/pwa_install/pwa_install.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/install_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

class FakeInstall implements PwaInstall {
  FakeInstall(this._mode, {this.accept = true});

  InstallMode _mode;
  final bool accept;
  int prompts = 0;
  final _changes = StreamController<void>.broadcast();

  void become(InstallMode mode) {
    _mode = mode;
    _changes.add(null);
  }

  @override
  InstallMode get mode => _mode;
  @override
  Stream<void> get changes => _changes.stream;
  @override
  Future<bool> prompt() async {
    prompts++;
    if (accept) _mode = InstallMode.none;
    return accept;
  }
}

Future<InstallNotifier> notifier(FakeInstall install, {DateTime? now}) async {
  final n = InstallNotifier(install: install, now: now == null ? null : () => now);
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return n;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the manifest', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;

    test('has what a browser needs to offer installing', () {
      expect(manifest['name'], 'NuStreak');
      expect(manifest['display'], 'standalone');
      expect(manifest['start_url'], isNotEmpty);
      expect(manifest['id'], isNotEmpty);
      expect(manifest['scope'], '/');
    });

    test('has 192 and 512 icons, and maskable ones, and every icon file exists', () {
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      final sizes = icons.map((i) => i['sizes']).toSet();
      expect(sizes, containsAll(['192x192', '512x512']));
      expect(icons.any((i) => i['purpose'] == 'maskable'), isTrue);
      for (final icon in icons) {
        expect(File('web/${icon['src']}').existsSync(), isTrue, reason: '${icon['src']} is missing');
      }
    });

    test('every shortcut opens a name the app understands, and has an icon that exists', () {
      final shortcuts = (manifest['shortcuts'] as List).cast<Map<String, dynamic>>();
      expect(shortcuts, isNotEmpty);
      expect(shortcuts.length, lessThanOrEqualTo(4), reason: 'Android shows at most four');
      for (final s in shortcuts) {
        expect(s['name'], isNotEmpty);
        expect(shortcutFromUri(Uri.parse(s['url'] as String)), isNotNull, reason: '${s['url']} is not a known shortcut');
        for (final icon in (s['icons'] as List).cast<Map<String, dynamic>>()) {
          expect(File('web/${icon['src']}').existsSync(), isTrue);
        }
      }
    });

    test('every shortcut the app knows is offered', () {
      final offered = (manifest['shortcuts'] as List)
          .map((s) => shortcutFromUri(Uri.parse((s as Map)['url'] as String)))
          .toSet();
      expect(offered, AppShortcut.values.toSet());
    });
  });

  group('the page', () {
    final html = File('web/index.html').readAsStringSync();

    test('links the manifest and a 180 px iPhone icon that exists', () {
      expect(html, contains('rel="manifest"'));
      expect(html, contains('apple-touch-icon'));
      expect(html, contains('apple-mobile-web-app-capable'));
      expect(File('web/icons/apple-touch-icon-180.png').existsSync(), isTrue);
    });

    test('keeps the early install event for the app to use', () {
      expect(html, contains('beforeinstallprompt'));
      expect(html, contains('__nustreakInstall'));
      expect(html, contains('nustreak-install-change'));
    });

    test('vercel serves the manifest properly and keeps the rewrites', () {
      final config = jsonDecode(File('vercel.json').readAsStringSync()) as Map<String, dynamic>;
      expect(jsonEncode(config['headers']), contains('application/manifest+json'));
      final rewrites = (config['rewrites'] as List).cast<Map<String, dynamic>>();
      expect(rewrites.last['source'], '/(.*)', reason: 'the catch-all must stay last');
    });
  });

  group('shortcuts', () {
    test('known names are read, in any case', () {
      expect(shortcutFromUri(Uri.parse('https://x.app/?shortcut=bites&source=pwa')), AppShortcut.bites);
      expect(shortcutFromUri(Uri.parse('https://x.app/?shortcut=Messages')), AppShortcut.messages);
      expect(shortcutFromUri(Uri.parse('/?shortcut=log')), AppShortcut.log);
    });

    test('nothing, or something unknown, opens the app normally', () {
      expect(shortcutFromUri(Uri.parse('https://x.app/')), isNull);
      expect(shortcutFromUri(Uri.parse('https://x.app/?shortcut=')), isNull);
      expect(shortcutFromUri(Uri.parse('https://x.app/?shortcut=hack')), isNull);
    });
  });

  group('install state', () {
    test('where nothing can be installed, nothing shows', () async {
      final n = await notifier(FakeInstall(InstallMode.none));
      expect(n.state.available, isFalse);
      expect(n.state.showCard, isFalse);
    });

    test('where it can, the card shows until dismissed', () async {
      final n = await notifier(FakeInstall(InstallMode.prompt));
      expect(n.state.showCard, isTrue);
      await n.dismissCard();
      expect(n.state.showCard, isFalse);
      expect(n.state.available, isTrue, reason: 'Settings keeps the row');
    });

    test('a dismissal is remembered for two weeks, then the card returns', () async {
      final start = DateTime(2026, 11, 21);
      final a = await notifier(FakeInstall(InstallMode.ios), now: start);
      await a.dismissCard();

      final soon = await notifier(FakeInstall(InstallMode.ios), now: start.add(const Duration(days: 13)));
      expect(soon.state.showCard, isFalse);

      final later = await notifier(FakeInstall(InstallMode.ios), now: start.add(const Duration(days: 15)));
      expect(later.state.showCard, isTrue);
    });

    test('installing opens the browser dialog and the card goes away', () async {
      final fake = FakeInstall(InstallMode.prompt);
      final n = await notifier(fake);
      expect(await n.install(), isTrue);
      expect(fake.prompts, 1);
      expect(n.state.available, isFalse);
    });

    test('saying no leaves the offer in place', () async {
      final fake = FakeInstall(InstallMode.prompt, accept: false);
      final n = await notifier(fake);
      expect(await n.install(), isFalse);
      expect(n.state.available, isTrue);
    });

    test('on an iPhone there is no dialog to open', () async {
      final fake = FakeInstall(InstallMode.ios);
      final n = await notifier(fake);
      expect(await n.install(), isFalse);
      expect(fake.prompts, 0);
    });

    test('when the browser decides the app is installable, the card appears', () async {
      final fake = FakeInstall(InstallMode.none);
      final n = await notifier(fake);
      expect(n.state.available, isFalse);
      fake.become(InstallMode.prompt);
      await Future<void>.delayed(Duration.zero);
      expect(n.state.available, isTrue);
    });

    test('when storage fails the card still shows', () async {
      final n = await notifier(FakeInstall(InstallMode.prompt));
      expect(n.state.showCard, isTrue);
    });
  });

  group('the card and the guide', () {
    late FakeInstall fake;

    Future<ProviderContainer> mount(WidgetTester tester, InstallMode mode, {bool accept = true}) async {
      fake = FakeInstall(mode, accept: accept);
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        installProvider.overrideWith((ref) => InstallNotifier(install: fake)),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: const CupertinoPageScaffold(child: SafeArea(child: Padding(padding: EdgeInsets.all(24), child: InstallCard()))),
        ),
      ));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('nothing to install: no card', (tester) async {
      await mount(tester, InstallMode.none);
      expect(find.byKey(const ValueKey('install_card')), findsNothing);
    }, variant: ios);

    testWidgets('a browser with an install dialog: the Add button opens it', (tester) async {
      await mount(tester, InstallMode.prompt);
      expect(find.text('Add NuStreak to your Home Screen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('install_card_add')));
      await tester.pumpAndSettle();
      expect(fake.prompts, 1);
      expect(find.byKey(const ValueKey('install_card')), findsNothing, reason: 'installed, so the card is gone');
    }, variant: ios);

    testWidgets('on an iPhone the button shows the three steps', (tester) async {
      await mount(tester, InstallMode.ios);
      expect(find.text('Show me how'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('install_card_add')));
      await tester.pumpAndSettle();
      for (final k in ['install_step_1', 'install_step_2', 'install_step_3']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget);
      }
      expect(find.textContaining('Add to Home Screen'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('install_guide_done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('install_step_1')), findsNothing);
      expect(fake.prompts, 0);
    }, variant: ios);

    testWidgets('Not now hides the card', (tester) async {
      await mount(tester, InstallMode.prompt);
      await tester.tap(find.byKey(const ValueKey('install_card_dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('install_card')), findsNothing);
    }, variant: ios);
  });
}
