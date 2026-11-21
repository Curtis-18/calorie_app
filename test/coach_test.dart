import 'dart:convert';

import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/messages.dart';
import 'package:calorie_app/providers/messages_provider.dart';
import 'package:calorie_app/screens/coach_screen.dart';
import 'package:calorie_app/screens/conversations_screen.dart';
import 'package:calorie_app/services/coach_service.dart';
import 'package:calorie_app/services/language_client.dart';
import 'package:calorie_app/services/messages_service.dart';
import 'package:calorie_app/services/voice_note.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _turn(String id, String role, String body, {int minutesAgo = 5}) => {
      'id': id,
      'role': role,
      'body': body,
      'created_at': DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String(),
    };

/// A pretend coach backend that records what it is asked.
class _Server {
  _Server({List<Map<String, dynamic>>? thread}) : thread = thread ?? [];

  List<Map<String, dynamic>> thread;
  int askStatus = 200;
  int failTimes = 0;
  Duration delay = Duration.zero;
  String reply = 'Your lentil stew fits well tonight.';
  List<Object> suggestions = [];
  List<Object> workouts = [];
  bool hasMore = false;
  List<Map<String, dynamic>> older = [];
  final asked = <Map<String, dynamic>>[];
  final queries = <Map<String, String>>[];
  final headers = <Map<String, String>>[];
  int cleared = 0;

  MockClient get client => MockClient((r) async {
        headers.add(r.headers);
        if (r.url.path != '/coach/messages') return http.Response('', 404);
        if (r.method == 'GET') {
          queries.add(r.url.queryParameters);
          if (r.url.queryParameters.containsKey('before')) return _json({'messages': older, 'has_more': false});
          return _json({'messages': thread, 'has_more': hasMore});
        }
        if (r.method == 'DELETE') {
          cleared++;
          thread = [];
          return http.Response('', 204);
        }
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        asked.add({...body, 'date': r.url.queryParameters['date']});
        if (delay > Duration.zero) await Future<void>.delayed(delay);
        if (failTimes > 0) {
          failTimes--;
          return _json({'detail': "The coach isn't available right now. Please try again in a moment."}, 503);
        }
        if (askStatus != 200) return _json({'detail': 'x'}, askStatus);
        final answer = _turn('c-${asked.length}', 'coach', reply, minutesAgo: 0);
        thread = [...thread, _turn(body['id'] as String, 'user', body['text'] as String, minutesAgo: 0), answer];
        return _json({
          ...answer,
          if (suggestions.isNotEmpty) 'suggestions': suggestions,
          if (workouts.isNotEmpty) 'workouts': workouts,
        });
      });
}

CoachService _service(_Server s) =>
    CoachService(client: languageClient(s.client), tokenProvider: () => 't', now: () => DateTime(2026, 11, 20, 9));

class _Voice implements VoiceRecognizer {
  _Voice({this.ok = true});
  final bool ok;
  void Function(String, bool)? sink;
  @override
  Future<bool> available() async => ok;
  @override
  Future<void> listen(void Function(String text, bool done) onText) async => sink = onText;
  @override
  Future<void> stop() async {}
}

Future<void> _settle(WidgetTester tester, [int steps = 8]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _walk() => {
      'id': 'walk_15',
      'name': '15-minute walk',
      'duration': '15 minutes',
      'focus': 'Walking',
      'summary': 'A steady walk. Take a hill or stairs if you like.',
      'sections': [
        {
          'title': 'Warm-up',
          'repeat': null,
          'steps': [
            {'name': 'Easy walk', 'cue': 'Walk slowly and let your shoulders loosen.', 'amount': '3 minutes'},
          ],
        },
        {
          'title': 'Main moves',
          'repeat': 'Repeat the main moves 3 times, resting a little between.',
          'steps': [
            {'name': 'Brisk walk', 'cue': 'Walk at a pace where you can still talk.', 'amount': '10 minutes'},
          ],
        },
      ],
      'safety': 'Stop if anything hurts or you feel dizzy.',
    };

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('service', () {
    test('a question goes with its id, the device date and the app language; the answer is the coach\'s', () async {
      final server = _Server();
      AppStrings.active = 'es';
      final reply = await _service(server).ask(id: 'm-1', text: 'what should I eat?');
      expect(server.asked.single, {'id': 'm-1', 'text': 'what should I eat?', 'date': '2026-11-20'});
      expect(server.headers.single['Accept-Language'], 'es');
      expect(reply.mine, isFalse);
      expect(reply.body, 'Your lentil stew fits well tonight.');
    });

    test('suggestions are read from the answer; malformed ones and an old backend are ignored', () async {
      final server = _Server()
        ..suggestions = [
          {'recipe_id': 'r-1', 'title': 'Lentil stew', 'calories': 420},
          {'title': 'no id'},
          {'recipe_id': 'r-3', 'title': ''},
          'junk',
        ];
      final reply = await _service(server).ask(id: 'm-1', text: 'dinner?');
      expect(reply.suggestions.map((s) => (s.recipeId, s.title, s.calories)), [('r-1', 'Lentil stew', 420)]);
      server.suggestions = [];
      expect((await _service(server).ask(id: 'm-2', text: 'again')).suggestions, isEmpty);
    });

    test('a routine is read from the answer; broken ones and an old backend are ignored', () async {
      final server = _Server()
        ..workouts = [
          _walk(),
          {'id': 'x', 'name': 'No sections', 'sections': []},
          {'name': 'No id', 'sections': []},
          'junk',
        ];
      final w = (await _service(server).ask(id: 'm-1', text: 'move?')).workouts;
      expect(w.map((x) => x.id), ['walk_15']);
      expect(w.single.sections.map((s) => s.title), ['Warm-up', 'Main moves']);
      expect(w.single.sections[0].repeat, isNull);
      expect(w.single.sections[1].repeat, startsWith('Repeat the main moves 3 times'));
      expect(w.single.sections[1].steps.single.amount, '10 minutes');
      server.workouts = [];
      expect((await _service(server).ask(id: 'm-2', text: 'again')).workouts, isEmpty);
    });

    test('the thread is read oldest first, in pages, and can be cleared', () async {
      final server = _Server(thread: [_turn('a', 'user', 'hi'), _turn('b', 'coach', 'hello')])..hasMore = true;
      final svc = _service(server);
      final page = await svc.thread();
      expect(page.messages.map((m) => m.mine), [true, false]);
      expect(page.hasMore, isTrue);
      await svc.thread(before: DateTime.utc(2026, 11, 1, 10));
      expect(server.queries.last['before'], '2026-11-01T10:00:00.000Z');
      await svc.clear();
      expect(server.cleared, 1);
    });

    test('problems are said in the app\'s language, not the server\'s English', () async {
      AppStrings.active = 'es';
      final server = _Server();
      for (final status in [429, 503, 404]) {
        server.askStatus = status;
        await expectLater(
          _service(server).ask(id: 'x', text: 'hi'),
          throwsA(isA<MessagesException>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.message, 'message', isNot(anyOf(contains('Please'), contains('Give it'), contains('Finish'))))),
        );
      }
    });

    test('signed out and an unreachable server each say so', () async {
      await expectLater(
        CoachService(client: MockClient((_) async => _json({})), tokenProvider: () => null).thread(),
        throwsA(isA<MessagesException>().having((e) => e.message, 'm', contains('signed out'))),
      );
      await expectLater(
        CoachService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't').ask(id: 'a', text: 'b'),
        throwsA(isA<MessagesException>().having((e) => e.message, 'm', contains('reach the server'))),
      );
    });
  });

  group('the coach screen', () {
    Future<void> open(WidgetTester tester, _Server server,
        {VoiceRecognizer? voice, Future<void> Function(BuildContext, String)? openRecipe}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CoachScreen(service: _service(server), recognizer: voice ?? _Voice(ok: false), openRecipe: openRecipe),
      ));
      await _settle(tester);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('coach_input')), text);
      await tester.pump();
    }

    testWidgets('an empty thread greets, offers three questions and says what the coach is', (tester) async {
      await open(tester, _Server());
      expect(find.text('Your coach'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('coach_idea_$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('coach_disclaimer')), findsOneWidget);
      expect(find.textContaining('not medical advice'), findsOneWidget);
      expect(find.textContaining('Google Gemini'), findsOneWidget);
    }, variant: ios);

    testWidgets('tapping an idea asks it, shows a typing sign while waiting, then the answer', (tester) async {
      final server = _Server()..delay = const Duration(milliseconds: 400);
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('coach_idea_0')));
      await tester.pump();
      expect(find.text('What should I eat for dinner?'), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_typing')), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_send')), findsOneWidget);
      await _settle(tester);
      expect(find.byKey(const ValueKey('coach_typing')), findsNothing);
      expect(find.text('Your lentil stew fits well tonight.'), findsOneWidget);
      expect(server.asked.single['text'], 'What should I eat for dinner?');
      expect((server.asked.single['id'] as String).length, 36);
    }, variant: ios);

    testWidgets('a recipe the coach names shows as a card that opens that recipe; a reload has no cards', (tester) async {
      final server = _Server()
        ..suggestions = [
          {'recipe_id': 'r-1', 'title': 'Lentil stew', 'calories': 420, 'protein_g': 25, 'carbs_g': 50, 'fat_g': 9},
          {'recipe_id': 'r-2', 'title': 'Egg pie', 'calories': 350, 'protein_g': 20, 'carbs_g': 10, 'fat_g': 15},
        ];
      final opened = <String>[];
      await open(tester, server, openRecipe: (_, id) async => opened.add(id));
      await tester.tap(find.byKey(const ValueKey('coach_idea_0')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('coach_recipe_r-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_recipe_r-2')), findsOneWidget);
      expect(find.text('420 kcal per serving · tap to open'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coach_recipe_r-2')));
      await tester.pump();
      expect(opened, ['r-2']);

      // The thread read back from the server carries the words only.
      server.suggestions = [];
      await tester.pumpWidget(const SizedBox());
      await open(tester, server);
      expect(find.text('Your lentil stew fits well tonight.'), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_recipe_r-1')), findsNothing);
    }, variant: ios);

    testWidgets('a routine the coach names is a card that opens the moves and the safety line; a reload has none', (tester) async {
      final server = _Server()..workouts = [_walk()];
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('coach_idea_0')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('coach_workout_walk_15')), findsOneWidget);
      expect(find.text('15-minute walk'), findsOneWidget);
      expect(find.text('15 minutes · Walking'), findsOneWidget);
      expect(find.byKey(const ValueKey('workout_name')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('coach_workout_walk_15')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('workout_name')), findsOneWidget);
      for (final text in ['Warm-up', 'Main moves', 'Easy walk', '3 minutes', 'Brisk walk', 'Walk at a pace where you can still talk.']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byKey(const ValueKey('workout_repeat')), findsOneWidget); // only the main section repeats
      expect(find.text('Stop if anything hurts or you feel dizzy.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workout_done')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('workout_name')), findsNothing);

      server.workouts = [];
      await tester.pumpWidget(const SizedBox());
      await open(tester, server);
      expect(find.byKey(const ValueKey('coach_workout_walk_15')), findsNothing);
    }, variant: ios);

    testWidgets('an answer with no named recipe has no cards', (tester) async {
      final server = _Server();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('coach_idea_0')));
      await _settle(tester);
      expect(find.textContaining('tap to open'), findsNothing);
    }, variant: ios);

    testWidgets('typing a message sends it trimmed and clears the box; blank cannot be sent', (tester) async {
      final server = _Server(thread: [_turn('a', 'coach', 'Welcome back')]);
      await open(tester, server);
      await type(tester, '   ');
      await tester.tap(find.byKey(const ValueKey('coach_send')));
      await _settle(tester, 3);
      expect(server.asked, isEmpty);
      await type(tester, '  how is my week?  ');
      await tester.tap(find.byKey(const ValueKey('coach_send')));
      await _settle(tester);
      expect(server.asked.single['text'], 'how is my week?');
      expect(tester.widget<CupertinoTextField>(find.byKey(const ValueKey('coach_input'))).controller!.text, isEmpty);
    }, variant: ios);

    testWidgets('a failure says so and tapping it asks again with the same id', (tester) async {
      final server = _Server(thread: [_turn('a', 'coach', 'Welcome back')])..failTimes = 1;
      await open(tester, server);
      await type(tester, 'any ideas?');
      await tester.tap(find.byKey(const ValueKey('coach_send')));
      await _settle(tester);
      expect(find.textContaining('Tap to try again'), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_typing')), findsNothing);
      await tester.tap(find.text('any ideas?'));
      await _settle(tester);
      expect(find.textContaining('Tap to try again'), findsNothing);
      expect(find.text('Your lentil stew fits well tonight.'), findsOneWidget);
      expect(server.asked.length, 2);
      expect(server.asked[0]['id'], server.asked[1]['id']);
    }, variant: ios);

    testWidgets('earlier messages load on request', (tester) async {
      final server = _Server(thread: [_turn('b', 'coach', 'newer')])
        ..hasMore = true
        ..older = [_turn('a', 'user', 'older question', minutesAgo: 90)];
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('coach_earlier')));
      await _settle(tester);
      expect(find.text('older question'), findsOneWidget);
      expect(find.byKey(const ValueKey('coach_earlier')), findsNothing);
    }, variant: ios);

    testWidgets('clear conversation asks first, then empties the thread', (tester) async {
      final server = _Server(thread: [_turn('a', 'user', 'hi'), _turn('b', 'coach', 'hello there')]);
      await open(tester, server);
      expect(find.text('hello there'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coach_menu')));
      await _settle(tester, 3);
      await tester.tap(find.byKey(const ValueKey('coach_clear')));
      await _settle(tester, 3);
      expect(find.text('Clear this conversation?'), findsOneWidget);
      expect(server.cleared, 0);
      await tester.tap(find.text('Clear'));
      await _settle(tester);
      expect(server.cleared, 1);
      expect(find.text('hello there'), findsNothing);
      expect(find.text('Your coach'), findsOneWidget);
    }, variant: ios);

    testWidgets('the mic is hidden where speech does not work', (tester) async {
      await open(tester, _Server(), voice: _Voice(ok: false));
      expect(find.byKey(const ValueKey('coach_mic')), findsNothing);
    }, variant: ios);

    testWidgets('the spoken words fill the box without sending', (tester) async {
      final voice = _Voice();
      final server = _Server();
      await open(tester, server, voice: voice);
      await tester.tap(find.byKey(const ValueKey('coach_mic')));
      await tester.pump();
      voice.sink!('what is a good snack', true);
      await tester.pump();
      expect(tester.widget<CupertinoTextField>(find.byKey(const ValueKey('coach_input'))).controller!.text, 'what is a good snack');
      expect(server.asked, isEmpty);
    }, variant: ios);

    testWidgets('it reads in the chosen language', (tester) async {
      AppStrings.active = 'es';
      await open(tester, _Server());
      expect(find.text('Tu entrenador'), findsOneWidget);
      expect(find.text('Your coach'), findsNothing);
    }, variant: ios);
  });

  group('the Coach row in Messages', () {
    Future<void> open(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) => ConversationsNotifier(
                service: MessagesService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(theme: AppTheme.cupertino, home: const ConversationsScreen()),
      ));
      await _settle(tester);
    }

    Map<String, dynamic> conv(String name) => {
          'user_id': 'u-$name', 'username': name, 'avatar_url': null, 'last_body': 'hey', 'last_mine': false,
          'last_at': DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String(), 'unread': 1,
        };

    testWidgets('is pinned above the friends, and has no unread count', (tester) async {
      await open(tester, MockClient((r) async => _json({'conversations': [conv('bea'), conv('sam')], 'unread_total': 2})));
      final coachY = tester.getTopLeft(find.byKey(const ValueKey('conversation_coach'))).dy;
      expect(coachY, lessThan(tester.getTopLeft(find.byKey(const ValueKey('conversation_u-bea'))).dy));
      expect(find.text('Coach'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread_coach')), findsNothing);
    }, variant: ios);

    testWidgets('is there with no conversations at all, above the invitation to message a friend', (tester) async {
      await open(tester, MockClient((r) async => _json({'conversations': [], 'unread_total': 0})));
      expect(find.byKey(const ValueKey('conversation_coach')), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
    }, variant: ios);

    testWidgets('opens the coach', (tester) async {
      coachServiceFactory = () => _service(_Server());
      addTearDown(() => coachServiceFactory = CoachService.new);
      await open(tester, MockClient((r) async => _json({'conversations': [], 'unread_total': 0})));
      await tester.tap(find.byKey(const ValueKey('conversation_coach')));
      await _settle(tester, 12);
      expect(find.byKey(const ValueKey('coach_input')), findsOneWidget);
    }, variant: ios);
  });

  test('a turn from the coach is not mine; the person\'s own turn is', () {
    expect(ChatMessage.fromCoachJson(_turn('a', 'user', 'hi')).mine, isTrue);
    expect(ChatMessage.fromCoachJson(_turn('b', 'coach', 'hello')).mine, isFalse);
  });
}
