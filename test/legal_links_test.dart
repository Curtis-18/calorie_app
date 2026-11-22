import 'package:calorie_app/screens/login_screen.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/screens/signup_screen.dart';
import 'package:calorie_app/services/legal_links.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/legal_note.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(child: CupertinoApp(theme: AppTheme.cupertino, home: CupertinoPageScaffold(child: SafeArea(child: child)))));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('the addresses', () {
    test('point at the app\'s own /privacy and /terms pages', () {
      expect(LegalLinks.privacy(base: 'https://app.example.com').toString(), 'https://app.example.com/privacy');
      expect(LegalLinks.terms(base: 'https://app.example.com').toString(), 'https://app.example.com/terms');
    });

    test('opening hands the address over; a launcher that fails or throws gives false, never an error', () async {
      Uri? seen;
      expect(await LegalLinks.open(Uri.parse('https://x.test/privacy'), launcher: (u) async {
        seen = u;
        return true;
      }), isTrue);
      expect(seen.toString(), 'https://x.test/privacy');
      expect(await LegalLinks.open(Uri.parse('https://x.test'), launcher: (u) async => false), isFalse);
      expect(await LegalLinks.open(Uri.parse('https://x.test'), launcher: (u) async => throw StateError('no browser')), isFalse);
    });
  });

  group('the note on log-in and sign-up', () {
    testWidgets('names both pages and opens each one', (tester) async {
      final opened = <String>[];
      await _show(tester, LegalNote(open: (u) async => (opened..add(u.path)).isNotEmpty));
      expect(find.text('By continuing you agree to our'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('legal_terms')));
      await tester.tap(find.byKey(const ValueKey('legal_privacy')));
      expect(opened, ['/terms', '/privacy']);
    }, variant: ios);

    testWidgets('is on both the log-in and the sign-up screen', (tester) async {
      for (final screen in [const LoginScreen(), const SignUpScreen()]) {
        await _show(tester, screen);
        await tester.scrollUntilVisible(find.byType(LegalNote), 200, scrollable: find.byType(Scrollable).first);
        expect(find.byType(LegalNote), findsOneWidget);
      }
    }, variant: ios);
  });

  group('Settings', () {
    testWidgets('has About with both pages and the Open Food Facts credit', (tester) async {
      final opened = <String>[];
      await _show(tester, SettingsView(profile: null, onOpenLink: (u) async => (opened..add(u.path)).isNotEmpty));
      final privacy = find.byKey(const ValueKey('open_privacy'));
      await tester.scrollUntilVisible(privacy, 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Open Food Facts'), findsOneWidget);
      await tester.tap(privacy);
      await tester.tap(find.byKey(const ValueKey('open_terms')));
      expect(opened, ['/privacy', '/terms']);
    }, variant: ios);
  });
}
