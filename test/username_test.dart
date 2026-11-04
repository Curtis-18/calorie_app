import 'dart:convert';

import 'package:calorie_app/models/username_rules.dart';
import 'package:calorie_app/screens/username_screen.dart';
import 'package:calorie_app/services/username_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

UsernameService _service(MockClient client) =>
    UsernameService(client: client, tokenProvider: () => 'token');

Future<String> _messageFor(Future<void> Function() call) async {
  try {
    await call();
  } on UsernameException catch (e) {
    return e.message;
  }
  fail('expected a UsernameException');
}

void main() {
  group('rules (same as the backend)', () {
    test('good names', () {
      for (final n in ['sam', 'Sam_99', 'a1b', 'x' * 20, '  sam  ', 'river_song']) {
        expect(validateUsername(n), isNull, reason: n);
      }
    });

    test('bad names say why', () {
      for (final n in ['', 'ab', 'x' * 21, '1sam', '_sam', 'sam_', 'sa__m', 'sa m', 'sam!', 'sämi', 'Admin', 'NUSTREAK']) {
        expect(validateUsername(n), isNotNull, reason: n);
      }
      expect(validateUsername('1sam'), 'Usernames must start with a letter.');
    });
  });

  group('service', () {
    test('check reads availability and the reason', () async {
      final client = MockClient((r) async {
        expect(r.url.path, '/username/check');
        expect(r.url.queryParameters['name'], 'sam');
        return http.Response(jsonEncode({'available': false, 'reason': 'That username is taken.'}), 200);
      });
      final result = await _service(client).check(' sam ');
      expect(result.available, isFalse);
      expect(result.reason, 'That username is taken.');
    });

    test('choose returns the saved name', () async {
      final client = MockClient((r) async {
        expect(jsonDecode(r.body), {'username': 'sam'});
        return http.Response(jsonEncode({'username': 'sam'}), 200);
      });
      expect(await _service(client).choose('sam'), 'sam');
    });

    test('409 is "taken"; 422 and 429 pass the server\'s words through', () async {
      Future<String> failWith(int status, [String detail = '']) => _messageFor(
            () => _service(MockClient((_) async => http.Response(jsonEncode({'detail': detail}), status))).choose('sam'),
          );
      expect(await failWith(409), UsernameService.taken);
      expect(await failWith(422, 'Usernames need at least 3 characters.'), 'Usernames need at least 3 characters.');
      expect(await failWith(429, 'You can change your username again on 05 Dec 2026.'),
          'You can change your username again on 05 Dec 2026.');
      expect(await failWith(500), contains("Couldn't save"));
    });

    test('offline and signed out are readable', () async {
      final offline = MockClient((_) async => throw http.ClientException('x'));
      expect(await _messageFor(() => _service(offline).check('sam')), contains("Couldn't reach"));
      final signedOut = UsernameService(client: offline, tokenProvider: () => null);
      expect(await _messageFor(() => signedOut.check('sam')), contains('signed out'));
    });
  });

  group('screen', () {
    Future<List<String>> pump(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final done = <String>[];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: UsernameScreen(service: _service(client), onDone: done.add),
      ));
      await tester.pump();
      return done;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(CupertinoTextField), text);
      await tester.pump(const Duration(milliseconds: 500)); // past the debounce
      await tester.pump(const Duration(milliseconds: 100));
    }

    MockClient server({bool free = true}) => MockClient((r) async {
          if (r.url.path == '/username/check') {
            return http.Response(
              jsonEncode(free ? {'available': true} : {'available': false, 'reason': 'That username is taken.'}),
              200,
            );
          }
          return http.Response(jsonEncode({'username': jsonDecode(r.body)['username']}), 200);
        });


    testWidgets('a free name enables Continue and saves', (tester) async {
      final done = await pump(tester, server());
      await type(tester, 'river_song');
      expect(find.text("It's yours if you want it"), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, ['river_song']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a taken name says so and cannot be saved', (tester) async {
      final done = await pump(tester, server(free: false));
      await type(tester, 'river_song');
      expect(find.text('That username is taken.'), findsOneWidget);

      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a bad name is explained locally, without asking the server', (tester) async {
      var asked = false;
      final done = await pump(tester, MockClient((_) async {
        asked = true;
        return http.Response('{}', 200);
      }));
      await type(tester, 'a_');
      await type(tester, 'abc_');
      expect(find.text("Underscores can't be doubled or go at the end."), findsOneWidget);
      expect(asked, isFalse);
      expect(done, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('characters that are not allowed cannot be typed', (tester) async {
      await pump(tester, server());
      await type(tester, 'sa m!-é');
      final field = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
      expect(field.controller!.text, 'sam');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
