import 'dart:async';

import 'package:calorie_app/screens/forgot_password_screen.dart';
import 'package:calorie_app/screens/reset_password_screen.dart';
import 'package:calorie_app/services/password_recovery.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget home) => CupertinoApp(theme: AppTheme.cupertino, home: home);

void main() {
  group('validation', () {
    test('email', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('  '), isNotNull);
      expect(validateEmail('nope'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail(' me@example.com '), isNull);
    });

    test('new password: length and match', () {
      expect(validateNewPassword('12345', '12345'), contains('at least'));
      expect(validateNewPassword('123456', '1234567'), contains('match'));
      expect(validateNewPassword('123456', '123456'), isNull);
    });

    test('server errors become plain words', () {
      expect(friendlyAuthError(const AuthException('Email rate limit exceeded', code: 'over_email_send_rate_limit')),
          contains('Too many'));
      expect(friendlyAuthError(const AuthException('New password should be different from the old password.', code: 'same_password')),
          contains('haven\'t used'));
      expect(friendlyAuthError(const AuthException('Auth session missing!')), contains('expired'));
      expect(friendlyAuthError(const AuthException('Password should be at least 8 characters.', code: 'weak_password')),
          'Password should be at least 8 characters.');
      expect(friendlyAuthError(Exception('socket')), contains('connection'));
    });
  });

  group('PasswordRecovery', () {
    setUp(PasswordRecovery.resetForTest);
    tearDown(PasswordRecovery.resetForTest);

    test('a recovery event marks it pending, sign-out or clear ends it', () async {
      final events = StreamController<AuthState>();
      PasswordRecovery.start(events.stream);

      events.add(const AuthState(AuthChangeEvent.signedIn, null));
      await pumpEventQueue();
      expect(PasswordRecovery.pending.value, isFalse);

      events.add(const AuthState(AuthChangeEvent.passwordRecovery, null));
      await pumpEventQueue();
      expect(PasswordRecovery.pending.value, isTrue);

      // Token refreshes while choosing a password must not cancel it.
      events.add(const AuthState(AuthChangeEvent.tokenRefreshed, null));
      await pumpEventQueue();
      expect(PasswordRecovery.pending.value, isTrue);

      events.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      expect(PasswordRecovery.pending.value, isFalse);

      events.add(const AuthState(AuthChangeEvent.passwordRecovery, null));
      await pumpEventQueue();
      PasswordRecovery.clear();
      expect(PasswordRecovery.pending.value, isFalse);
      await events.close();
    });

    test('a replayed recovery event (the link was handled at start-up) is seen', () async {
      // The real auth stream replays its latest event to a new listener.
      final events = Stream<AuthState>.value(const AuthState(AuthChangeEvent.passwordRecovery, null));
      PasswordRecovery.start(events);
      await pumpEventQueue();
      expect(PasswordRecovery.pending.value, isTrue);
    });
  });

  group('forgot password screen', () {
    testWidgets('sends the link and shows the same confirmation either way', (tester) async {
      final sent = <(String, String?)>[];
      final actions = PasswordActions(sendLink: (e, r) async => sent.add((e, r)), setPassword: (_) async {});
      await tester.pumpWidget(_app(ForgotPasswordScreen(actions: actions)));
      await _settle(tester);

      await tester.enterText(find.byType(EditableText), ' me@example.com ');
      await tester.tap(find.text('Send reset link'));
      await _settle(tester);

      expect(sent, [('me@example.com', null)]);
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('If me@example.com has an account'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a bad email is explained and nothing is sent', (tester) async {
      var calls = 0;
      final actions = PasswordActions(sendLink: (e, r) async => calls++, setPassword: (_) async {});
      await tester.pumpWidget(_app(ForgotPasswordScreen(actions: actions)));
      await _settle(tester);

      await tester.enterText(find.byType(EditableText), 'nope');
      await tester.tap(find.text('Send reset link'));
      await _settle(tester);

      expect(calls, 0);
      expect(find.textContaining('doesn\'t look like an email'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a failure is shown in plain words and can be retried', (tester) async {
      final actions = PasswordActions(
        sendLink: (e, r) async => throw const AuthException('Email rate limit exceeded', code: 'over_email_send_rate_limit'),
        setPassword: (_) async {},
      );
      await tester.pumpWidget(_app(ForgotPasswordScreen(initialEmail: 'me@example.com', actions: actions)));
      await _settle(tester);

      await tester.tap(find.text('Send reset link'));
      await _settle(tester);

      expect(find.textContaining('Too many tries'), findsOneWidget);
      expect(find.text('Check your email'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('reset password screen', () {
    Future<(List<String>, List<String>)> pump(WidgetTester tester, {Object? failWith}) async {
      final saved = <String>[];
      final events = <String>[];
      final actions = PasswordActions(
        sendLink: (e, r) async {},
        setPassword: (p) async {
          if (failWith != null) throw failWith;
          saved.add(p);
        },
      );
      await tester.pumpWidget(_app(ResetPasswordScreen(
        actions: actions,
        onDone: () => events.add('done'),
        onCancel: () => events.add('cancel'),
      )));
      await _settle(tester);
      return (saved, events);
    }

    testWidgets('saves a matching password and finishes', (tester) async {
      final (saved, events) = await pump(tester);
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'new-secret');
      await tester.enterText(fields.at(1), 'new-secret');
      await tester.tap(find.text('Save password'));
      await _settle(tester);

      expect(saved, ['new-secret']);
      expect(events, ['done']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a mismatch or short password is stopped before the server', (tester) async {
      final (saved, events) = await pump(tester);
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'new-secret');
      await tester.enterText(fields.at(1), 'other-secret');
      await tester.tap(find.text('Save password'));
      await _settle(tester);
      expect(find.textContaining('don\'t match'), findsOneWidget);

      await tester.enterText(fields.at(0), 'abc');
      await tester.enterText(fields.at(1), 'abc');
      await tester.tap(find.text('Save password'));
      await _settle(tester);
      expect(find.textContaining('at least'), findsWidgets);

      expect(saved, isEmpty);
      expect(events, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('an expired link says so and does not finish', (tester) async {
      final (saved, events) = await pump(tester, failWith: const AuthException('Auth session missing!'));
      final fields = find.byType(EditableText);
      await tester.enterText(fields.at(0), 'new-secret');
      await tester.enterText(fields.at(1), 'new-secret');
      await tester.tap(find.text('Save password'));
      await _settle(tester);

      expect(find.textContaining('expired'), findsOneWidget);
      expect(saved, isEmpty);
      expect(events, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Cancel is reported', (tester) async {
      final (_, events) = await pump(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(events, ['cancel']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
