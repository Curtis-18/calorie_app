import 'dart:convert';

import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/screens/profile_screen.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/screens/username_screen.dart';
import 'package:calorie_app/services/account_service.dart';
import 'package:calorie_app/services/username_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/delete_account.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

AccountService _service(MockClient client) =>
    AccountService(client: client, tokenProvider: () => 'token', currentUserId: () => 'user-a');

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('service', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'user_profile:user-a': '{}',
          'food_log:user-a:2026-11-14': ['{}'],
          'progress_seen:user-a': '{}',
          'user_profile:user-b': '{}',
          'food_log:user-b:2026-11-14': ['{}'],
          'appearance_mode': 'dark',
        }));

    test('asks the server to delete, then forgets only this person on the device', () async {
      final seen = <String>[];
      await _service(MockClient((r) async {
        seen.add('${r.method} ${r.url.path} ${r.headers['Authorization']}');
        return http.Response('', 204);
      })).deleteAccount();

      expect(seen, ['DELETE /me Bearer token']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'user_profile:user-b', 'food_log:user-b:2026-11-14', 'appearance_mode'});
    });

    test('a server failure deletes nothing on the device and gives the reason', () async {
      final service = _service(MockClient(
        (_) async => http.Response(jsonEncode({'detail': "Couldn't delete your account just now. Please try again."}), 502),
      ));
      await expectLater(
        service.deleteAccount(),
        throwsA(isA<AccountException>().having((e) => e.message, 'message', contains('try again'))),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('user_profile:user-a'), isTrue);
    });

    test('offline and timeouts are explained', () async {
      await expectLater(
        _service(MockClient((_) async => throw http.ClientException('offline'))).deleteAccount(),
        throwsA(isA<AccountException>().having((e) => e.message, 'message', contains("Couldn't reach the server"))),
      );
    });

    test('a 401 on a retry means it already went through', () async {
      await _service(MockClient((_) async => http.Response('{"detail":"user_not_found"}', 401))).deleteAccount();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('user_profile:user-a'), isFalse);
    });
  });

  group('the delete flow', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<({List<String> calls, List<bool> results})> open(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      final results = <bool>[];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('go'),
                onPressed: () async => results.add(await confirmAndDeleteAccount(
                  context,
                  service: _service(client),
                  signOut: () async => calls.add('signOut'),
                  signedOutScreen: (_) => const Center(child: Text('signed out screen')),
                )),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await settle(tester);
      return (calls: calls, results: results);
    }

    testWidgets('nothing happens without a confirmation', (tester) async {
      var asked = false;
      final r = await open(tester, MockClient((_) async {
        asked = true;
        return http.Response('', 204);
      }));
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining("can't be undone"), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await settle(tester);
      expect(asked, isFalse);
      expect(r.results, [false]);
      expect(r.calls, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('confirming deletes, signs out and lands on the sign-in screen', (tester) async {
      final r = await open(tester, MockClient((_) async => http.Response('', 204)));
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(r.results, [true]);
      expect(r.calls, ['signOut']);
      expect(find.text('signed out screen'), findsOneWidget);
      expect(find.text('go'), findsNothing); // every earlier screen is gone
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a failure says so and leaves them signed in', (tester) async {
      final r = await open(tester, MockClient((_) async => http.Response('{"detail":"Please try again."}', 502)));
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text("Couldn't delete your account"), findsOneWidget);
      expect(find.text('Please try again.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(r.results, [false]);
      expect(r.calls, isEmpty);
      expect(find.text('go'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('settings and profile', () {
    final profile = UserProfile(
      weightKg: 70, heightCm: 175, dateOfBirth: DateTime(1990, 1, 1), gender: Gender.male,
      activityLevel: ActivityLevel.moderate, goal: Goal.maintain, calorieTarget: 2400, bmi: 22.9,
      proteinTargetG: 112, fatTargetG: 80, carbsTargetG: 308,
    );

    Future<List<String>> open(WidgetTester tester, {UserProfile? profile, String? username}) async {
      SharedPreferences.setMockInitialValues({});
      // A small phone: everything must still be reachable by scrolling.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final events = <String>[];
      await tester.pumpWidget(ProviderScope(child: CupertinoApp(
        theme: AppTheme.cupertino,
        home: SettingsView(
          profile: profile,
          username: username,
          onUsernameChanged: () => events.add('username changed'),
          onBlockedPeople: () => events.add('blocked'),
          onLogOut: (_) async => events.add('log out'),
          onDeleteAccount: (_) async => events.add('delete'),
        ),
      )));
      await settle(tester);
      return events;
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await settle(tester);
      await tester.tap(target);
      await settle(tester);
    }

    testWidgets('delete account can be reached on a small phone', (tester) async {
      final events = await open(tester, profile: profile, username: 'river');
      await tapKey(tester, 'delete_account');
      expect(events, ['delete']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('someone who never finished onboarding can still delete their account', (tester) async {
      final events = await open(tester);
      expect(find.text('Set up profile'), findsOneWidget);
      await tapKey(tester, 'delete_account');
      expect(events, ['delete']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the username row is hidden until the name is known', (tester) async {
      await open(tester, profile: profile);
      expect(find.byKey(const ValueKey('change_username')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await open(tester, profile: profile, username: 'river');
      expect(find.byKey(const ValueKey('change_username')), findsOneWidget);
      expect(find.text('@river'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('log out and blocked people live in settings', (tester) async {
      final events = await open(tester, profile: profile, username: 'river');
      await tapKey(tester, 'blocked_people');
      await tapKey(tester, 'log_out');
      expect(events, ['blocked', 'log out']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the profile tab shows the plan; height reads in metres', (tester) async {
      var opened = 0;
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: ProfileView(
          profile: profile,
          username: 'river',
          photoButton: const SizedBox(width: 60, height: 60),
          onOpenSettings: () => opened++,
        ),
      ));
      expect(find.text('@river'), findsOneWidget);
      expect(find.text('2400'), findsOneWidget);
      expect(find.text('112g'), findsOneWidget);
      expect(find.text('1.75 m'), findsOneWidget); // was shown as "0.2 m"
      expect(find.text('70 kg'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open_settings')));
      await settle(tester);
      expect(opened, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the profile tab offers setup to someone who never finished onboarding', (tester) async {
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: ProfileView(profile: null, onOpenSettings: () {}),
      ));
      expect(find.text('Set up profile'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_settings')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('changing a username', () {
    Future<List<String>> pump(WidgetTester tester, MockClient client) async {
      final done = <String>[];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: UsernameScreen(
          current: 'river',
          service: UsernameService(client: client, tokenProvider: () => 't'),
          onDone: done.add,
        ),
      ));
      return done;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(CupertinoTextField), text);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('says what the name is now and saves the new one', (tester) async {
      final done = await pump(tester, MockClient((r) async {
        if (r.url.path == '/username/check') return http.Response('{"available":true,"reason":null}', 200);
        return http.Response(jsonEncode({'username': jsonDecode(r.body)['username']}), 200);
      }));
      expect(find.text('Change your username'), findsOneWidget);
      expect(find.textContaining("You're @river now"), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);

      await type(tester, 'river_song');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, ['river_song']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('inside the 30 days the server\'s date is shown and nothing is saved', (tester) async {
      final done = await pump(tester, MockClient((r) async {
        if (r.url.path == '/username/check') return http.Response('{"available":true,"reason":null}', 200);
        return http.Response('{"detail":"You can change your username again on 04 Dec 2026."}', 429);
      }));
      await type(tester, 'river_song');
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('You can change your username again on 04 Dec 2026.'), findsOneWidget);
      expect(done, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
