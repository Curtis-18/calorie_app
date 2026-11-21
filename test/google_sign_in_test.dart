import 'dart:async';

import 'package:calorie_app/screens/login_screen.dart';
import 'package:calorie_app/screens/signup_screen.dart';
import 'package:calorie_app/services/google_auth.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/google_sign_in_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CupertinoApp(theme: AppTheme.cupertino, home: CupertinoPageScaffold(child: SafeArea(child: child))));
  await tester.pump();
}

void main() {
  group('where Google sign-in is offered', () {
    test('on the web and on Android, yes', () {
      expect(googleSignInAvailable(web: true, platform: TargetPlatform.iOS), isTrue, reason: 'Safari is the website, not the App Store app');
      expect(googleSignInAvailable(web: true, platform: TargetPlatform.android), isTrue);
      expect(googleSignInAvailable(web: false, platform: TargetPlatform.android), isTrue);
    });

    test('in an iPhone app, not until Sign in with Apple exists (App Store rule 4.8)', () {
      expect(googleSignInAvailable(web: false, platform: TargetPlatform.iOS), isFalse);
      expect(googleSignInAvailable(web: false, platform: TargetPlatform.macOS), isFalse);
    });

    test('a phone comes back by the deep link, the website by itself', () {
      expect(googleRedirectUrl(web: true, origin: 'https://nustreak.vercel.app'), 'https://nustreak.vercel.app');
      expect(googleRedirectUrl(web: false, origin: ''), googleNativeRedirect);
      expect(googleNativeRedirect, 'nustreak://login-callback');
    });
  });

  group('the button', () {
    testWidgets('is not there where Google sign-in is not offered', (tester) async {
      await _show(tester, const GoogleSignInButton(available: false, signedIn: Stream.empty()));
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('or'), findsNothing);
    }, variant: ios);

    testWidgets('says "or" and "Continue with Google", and starts the flow once per tap', (tester) async {
      var started = 0;
      await _show(tester, GoogleSignInButton(available: true, signedIn: const Stream.empty(), start: () async => started++));
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('google_sign_in')));
      await tester.pump();
      expect(started, 1);
    }, variant: ios);

    testWidgets('is disabled while the flow is starting, so a double tap cannot start two', (tester) async {
      var started = 0;
      final gate = Completer<void>();
      await _show(tester, GoogleSignInButton(available: true, signedIn: const Stream.empty(), start: () {
        started++;
        return gate.future;
      }));
      await tester.tap(find.byKey(const ValueKey('google_sign_in')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('google_sign_in')), warnIfMissed: false);
      await tester.pump();
      expect(started, 1);
      gate.complete();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('google_sign_in')));
      await tester.pump();
      expect(started, 2, reason: 'usable again once it came back');
    }, variant: ios);

    testWidgets("Supabase's refusal is shown in its own words", (tester) async {
      await _show(tester, GoogleSignInButton(
        available: true,
        signedIn: const Stream.empty(),
        start: () async => throw const AuthException('Unsupported provider: provider is not enabled'),
      ));
      await tester.tap(find.byKey(const ValueKey('google_sign_in')));
      await tester.pump();
      expect(find.text('Unsupported provider: provider is not enabled'), findsOneWidget);
    }, variant: ios);

    testWidgets('no connection says so plainly, and a new tap clears the message', (tester) async {
      var fail = true;
      await _show(tester, GoogleSignInButton(
        available: true,
        signedIn: const Stream.empty(),
        start: () async {
          if (fail) throw Exception('socket');
        },
      ));
      await tester.tap(find.byKey(const ValueKey('google_sign_in')));
      await tester.pump();
      expect(find.byKey(const ValueKey('google_error')), findsOneWidget);
      expect(find.textContaining("Couldn't open Google sign-in"), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('google_sign_in')));
      await tester.pump();
      expect(find.byKey(const ValueKey('google_error')), findsNothing);
    }, variant: ios);

    testWidgets('when the session arrives, the pushed log-in and sign-up screens close', (tester) async {
      final signedIn = StreamController<bool>.broadcast();
      addTearDown(signedIn.close);
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: const CupertinoPageScaffold(child: Center(child: Text('the app'))),
      ));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(CupertinoPageRoute<void>(
        builder: (_) => CupertinoPageScaffold(child: GoogleSignInButton(available: true, signedIn: signedIn.stream, start: () async {})),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      signedIn.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('the app'), findsOneWidget);
    }, variant: ios);

    testWidgets('a signed-out event does not close anything', (tester) async {
      final signedIn = StreamController<bool>.broadcast();
      addTearDown(signedIn.close);
      await _show(tester, GoogleSignInButton(available: true, signedIn: signedIn.stream, start: () async {}));
      signedIn.add(false);
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
    }, variant: ios);
  });

  group('the screens', () {
    testWidgets('the iPhone build of log-in and sign-up has no Google button yet and still works', (tester) async {
      for (final screen in [const LoginScreen(), const SignUpScreen()]) {
        await _show(tester, screen);
        expect(find.text('Continue with Google'), findsNothing);
        expect(find.text('or'), findsNothing);
        expect(find.byType(GoogleSignInButton), findsOneWidget, reason: 'it is placed, and hides itself');
      }
    }, variant: ios);
  });
}
