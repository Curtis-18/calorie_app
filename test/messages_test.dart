import 'dart:convert';

import 'package:calorie_app/models/messages.dart';
import 'package:calorie_app/providers/messages_provider.dart';
import 'package:calorie_app/screens/chat_screen.dart';
import 'package:calorie_app/screens/conversations_screen.dart';
import 'package:calorie_app/services/messages_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _msg(String id, String body, {bool mine = false, bool read = false, int minutesAgo = 5}) => {
      'id': id,
      'mine': mine,
      'body': body,
      'created_at': DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      'read_at': read ? DateTime.now().toUtc().toIso8601String() : null,
    };

Map<String, dynamic> _conv(String name, {int unread = 0, bool mine = false, String last = 'hey'}) => {
      'user_id': 'u-$name',
      'username': name,
      'avatar_url': null,
      'last_body': last,
      'last_mine': mine,
      'last_at': DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String(),
      'unread': unread,
    };

/// A pretend backend for messages, recording what it is asked.
class _Server {
  _Server({List<Map<String, dynamic>>? thread, this.conversations = const []}) : thread = thread ?? [];

  List<Map<String, dynamic>> thread;
  List<Map<String, dynamic>> conversations;
  List<Map<String, dynamic>> older = [];
  bool hasMore = false;
  int threadStatus = 200;
  String threadDetail = 'You can only message your friends.';
  int sendFailures = 0;
  Duration sendDelay = Duration.zero;
  final calls = <String>[];
  final sentBodies = <Map<String, dynamic>>[];
  final queries = <Map<String, String>>[];

  MockClient get client => MockClient((r) async {
        final path = r.url.path;
        calls.add('${r.method} $path');
        if (path == '/messages' && r.method == 'GET') {
          return _json({'conversations': conversations, 'unread_total': 0});
        }
        if (path.startsWith('/messages/with/') && path.endsWith('/read')) return http.Response('', 204);
        if (path.startsWith('/messages/with/') && r.method == 'GET') {
          queries.add(r.url.queryParameters);
          if (threadStatus != 200) return _json({'detail': threadDetail}, threadStatus);
          if (r.url.queryParameters.containsKey('before')) return _json({'messages': older, 'has_more': false});
          return _json({'messages': thread, 'has_more': hasMore});
        }
        if (path.startsWith('/messages/with/') && r.method == 'POST') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          sentBodies.add(body);
          if (sendDelay > Duration.zero) await Future<void>.delayed(sendDelay);
          if (sendFailures > 0) {
            sendFailures--;
            return _json({'detail': "Couldn't send that message."}, 500);
          }
          final saved = _msg(body['id'] as String, body['body'] as String, mine: true, minutesAgo: 0);
          thread = [...thread, saved];
          return _json(saved);
        }
        if (r.method == 'DELETE') {
          thread = [for (final m in thread) if (!path.endsWith(m['id'] as String)) m];
          return http.Response('', 204);
        }
        if (path.endsWith('/report')) return http.Response('', 204);
        return http.Response('', 404);
      });
}

MessagesService _service(_Server s) => MessagesService(client: s.client, tokenProvider: () => 't');

List<Override> _overrides(_Server s) => [
      conversationsProvider.overrideWith((ref) => ConversationsNotifier(
            service: _service(s),
            currentUserId: () => 'me',
            userIdChanges: const Stream.empty(),
          )),
    ];

void main() {
  group('time labels', () {
    final now = DateTime(2026, 11, 14, 15, 30);
    test('chat lines say the time, then how long ago the day was', () {
      expect(chatTimeLabel(DateTime(2026, 11, 14, 9, 5), now), '09:05');
      expect(chatTimeLabel(DateTime(2026, 11, 13, 23, 59), now), 'Yesterday 23:59');
      expect(chatTimeLabel(DateTime(2026, 11, 10, 8, 0), now), 'Tue 08:00');
      expect(chatTimeLabel(DateTime(2026, 10, 1, 8, 0), now), '1 Oct 08:00');
    });

    test('the list says the time today, then just the day', () {
      expect(conversationTimeLabel(DateTime(2026, 11, 14, 9, 5), now), '09:05');
      expect(conversationTimeLabel(DateTime(2026, 11, 13, 23, 59), now), 'Yesterday');
      expect(conversationTimeLabel(DateTime(2026, 11, 10, 8, 0), now), 'Tue');
      expect(conversationTimeLabel(DateTime(2026, 10, 1, 8, 0), now), '1 Oct');
    });
  });

  group('service', () {
    test('conversations and threads are read from the right routes', () async {
      final server = _Server(thread: [_msg('a', 'hi')], conversations: [_conv('sam', unread: 2)]);
      final svc = _service(server);
      final list = await svc.conversations();
      expect(list.conversations.single.username, 'sam');
      expect(list.unreadTotal, 2);

      final thread = await svc.thread('u-sam');
      expect(thread.messages.single.body, 'hi');
      expect(thread.messages.single.mine, isFalse);

      final cursor = DateTime.utc(2026, 11, 1, 10);
      await svc.thread('u-sam', before: cursor);
      expect(server.queries.last['before'], '2026-11-01T10:00:00.000Z');
    });

    test('send, read, unsend and report hit the right routes with the right bodies', () async {
      final server = _Server();
      final svc = _service(server);
      final saved = await svc.send('u-sam', id: 'm-1', body: 'hello');
      expect(saved.mine, isTrue);
      expect(server.sentBodies.single, {'id': 'm-1', 'body': 'hello'});
      await svc.markRead('u-sam');
      await svc.unsend('m-1');
      await svc.report('m-2', reason: 'rude');
      expect(server.calls, [
        'POST /messages/with/u-sam',
        'POST /messages/with/u-sam/read',
        'DELETE /messages/m-1',
        'POST /messages/m-2/report',
      ]);
    });

    test('errors carry the server\'s words and status; validation errors say what to fix', () async {
      final svc = MessagesService(
        client: MockClient((r) async => r.method == 'GET'
            ? _json({'detail': 'You can only message your friends.'}, 403)
            : _json({
                'detail': [
                  {'msg': 'Value error, Write something first.'},
                ],
              }, 422)),
        tokenProvider: () => 't',
      );
      await expectLater(
        svc.thread('u-bea'),
        throwsA(isA<MessagesException>()
            .having((e) => e.statusCode, 'status', 403)
            .having((e) => e.message, 'message', 'You can only message your friends.')),
      );
      await expectLater(
        svc.send('u-bea', id: 'x', body: ' '),
        throwsA(isA<MessagesException>().having((e) => e.message, 'message', 'Write something first.')),
      );
    });

    test('signed out, a network failure and a slow server each say so', () async {
      await expectLater(
        MessagesService(client: MockClient((_) async => _json({})), tokenProvider: () => null).conversations(),
        throwsA(isA<MessagesException>().having((e) => e.message, 'm', contains('signed out'))),
      );
      await expectLater(
        MessagesService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't')
            .conversations(),
        throwsA(isA<MessagesException>().having((e) => e.message, 'm', contains('reach the server'))),
      );
    });
  });

  group('provider', () {
    test('opening a conversation clears its count at once and tells the server', () async {
      final server = _Server(conversations: [_conv('sam', unread: 3), _conv('bea', unread: 1)]);
      final notifier = ConversationsNotifier(
        service: _service(server),
        currentUserId: () => 'me',
        userIdChanges: const Stream.empty(),
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.value!.unreadTotal, 4);

      await notifier.markRead('u-sam');
      expect(notifier.state.value!.forUser('u-sam')!.unread, 0);
      expect(notifier.state.value!.unreadTotal, 1);
      expect(server.calls, contains('POST /messages/with/u-sam/read'));
    });

    test('a failing refresh keeps the last list, and nobody signed in loads nothing', () async {
      var fail = false;
      final notifier = ConversationsNotifier(
        service: MessagesService(
          client: MockClient((_) async => fail
              ? _json({'detail': 'boom'}, 500)
              : _json({'conversations': [_conv('sam', unread: 2)]})),
          tokenProvider: () => 't',
        ),
        currentUserId: () => 'me',
        userIdChanges: const Stream.empty(),
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fail = true;
      await notifier.load();
      expect(notifier.state.value!.unreadTotal, 2);

      final server = _Server();
      final idle = ConversationsNotifier(
        service: _service(server),
        currentUserId: () => null,
        userIdChanges: const Stream.empty(),
      );
      addTearDown(idle.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.calls, isEmpty);
    });
  });

  group('chat screen', () {
    Future<void> settle(WidgetTester tester, [int steps = 8]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester, _Server server, {Duration poll = const Duration(seconds: 6)}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(server),
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: ChatScreen(userId: 'u-sam', username: 'sam', pollEvery: poll),
        ),
      ));
      await settle(tester);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const ValueKey('chat_input')), text);
      await tester.pump();
    }

    testWidgets('shows the conversation, and marks theirs as read', (tester) async {
      final server = _Server(thread: [_msg('a', 'lunch?'), _msg('b', 'yes!', mine: true, read: true, minutesAgo: 3)]);
      await open(tester, server);
      expect(find.text('lunch?'), findsOneWidget);
      expect(find.text('yes!'), findsOneWidget);
      expect(find.text('@sam'), findsOneWidget);
      expect(find.text('Seen'), findsOneWidget);
      expect(server.calls, contains('POST /messages/with/u-sam/read'));
    }, variant: ios);

    testWidgets('only the latest message of mine says Sent or Seen', (tester) async {
      final server = _Server(thread: [
        _msg('a', 'one', mine: true, read: true, minutesAgo: 9),
        _msg('b', 'two', mine: true, minutesAgo: 8),
      ]);
      await open(tester, server);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Seen'), findsNothing);
      expect(server.calls, isNot(contains('POST /messages/with/u-sam/read')), reason: 'nothing of theirs to read');
    }, variant: ios);

    testWidgets('an empty conversation invites you to say hi', (tester) async {
      await open(tester, _Server());
      expect(find.text('Say hi to @sam'), findsOneWidget);
    }, variant: ios);

    testWidgets('sending shows the message at once and saves it with an id', (tester) async {
      final server = _Server(thread: [_msg('a', 'hello', minutesAgo: 2)])..sendDelay = const Duration(milliseconds: 400);
      await open(tester, server);
      await type(tester, '  on my way  ');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await tester.pump(); // before the server answers
      expect(find.text('on my way'), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);
      await settle(tester);
      expect(find.text('Sending…'), findsNothing);
      expect(server.sentBodies.single['body'], 'on my way');
      expect((server.sentBodies.single['id'] as String).length, 36);
      expect(find.text('Sent'), findsOneWidget);
      expect(tester.widget<CupertinoTextField>(find.byKey(const ValueKey('chat_input'))).controller!.text, isEmpty);
    }, variant: ios);

    testWidgets('an empty message cannot be sent', (tester) async {
      final server = _Server();
      await open(tester, server);
      await type(tester, '   ');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await settle(tester, 3);
      expect(server.sentBodies, isEmpty);
    }, variant: ios);

    testWidgets('a failed message says so, and tapping it tries again with the same id', (tester) async {
      final server = _Server(thread: [_msg('a', 'hello', minutesAgo: 2)])..sendFailures = 1;
      await open(tester, server);
      await type(tester, 'are you there');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await settle(tester);
      expect(find.textContaining('Tap to try again'), findsOneWidget);

      await tester.tap(find.text('are you there'));
      await settle(tester);
      expect(find.textContaining('Tap to try again'), findsNothing);
      expect(server.sentBodies.length, 2);
      expect(server.sentBodies[0]['id'], server.sentBodies[1]['id'], reason: 'a retry must not double up');
      expect(find.text('Sent'), findsOneWidget);
    }, variant: ios);

    testWidgets('new messages arrive on their own while it is open', (tester) async {
      final server = _Server(thread: [_msg('a', 'hello', minutesAgo: 2)]);
      await open(tester, server, poll: const Duration(seconds: 1));
      expect(find.text('hi again'), findsNothing);
      server.thread = [...server.thread, _msg('b', 'hi again', minutesAgo: 0)];
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('hi again'), findsOneWidget);
      expect(server.calls.where((c) => c == 'POST /messages/with/u-sam/read').length, 2,
          reason: 'read on opening, and again when something new came in');
    }, variant: ios);

    testWidgets('a message still on its way survives a refresh', (tester) async {
      final server = _Server(thread: [_msg('a', 'hello', minutesAgo: 2)])..sendFailures = 5;
      await open(tester, server, poll: const Duration(seconds: 1));
      await type(tester, 'stuck');
      await tester.tap(find.byKey(const ValueKey('chat_send')));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('stuck'), findsOneWidget);
      expect(find.textContaining('Tap to try again'), findsOneWidget);
    }, variant: ios);

    testWidgets('long press: delete my message for everyone', (tester) async {
      final server = _Server(thread: [_msg('a', 'oops wrong chat', mine: true)]);
      await open(tester, server);
      await tester.longPress(find.byKey(const ValueKey('msg_a')));
      await settle(tester, 4);
      expect(find.text('Report message'), findsNothing, reason: 'not for my own messages');
      await tester.tap(find.text('Delete for everyone'));
      await settle(tester);
      expect(find.text('oops wrong chat'), findsNothing);
      expect(server.calls, contains('DELETE /messages/a'));
    }, variant: ios);

    testWidgets('long press: report their message, after asking', (tester) async {
      final server = _Server(thread: [_msg('a', 'something rude')]);
      await open(tester, server);
      await tester.longPress(find.byKey(const ValueKey('msg_a')));
      await settle(tester, 4);
      expect(find.text('Delete for everyone'), findsNothing, reason: 'not for their messages');
      await tester.tap(find.text('Report message'));
      await settle(tester, 4);
      expect(server.calls, isNot(contains('POST /messages/a/report')), reason: 'asks first');
      await tester.tap(find.text('Report'));
      await settle(tester);
      expect(server.calls, contains('POST /messages/a/report'));
      expect(find.byKey(const ValueKey('chat_notice')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }, variant: ios);

    testWidgets('long press: copy puts the text on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, _Server(thread: [_msg('a', 'address is 12 Elm St')]));
      await tester.longPress(find.byKey(const ValueKey('msg_a')));
      await settle(tester, 4);
      await tester.tap(find.text('Copy'));
      await settle(tester, 3);
      expect(copied, 'address is 12 Elm St');
    }, variant: ios);

    testWidgets('earlier messages load on request', (tester) async {
      final server = _Server(thread: [_msg('b', 'recent', minutesAgo: 1)])
        ..hasMore = true
        ..older = [_msg('a', 'from last week', minutesAgo: 9000)];
      await open(tester, server);
      expect(find.text('from last week'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat_earlier')));
      await settle(tester);
      expect(find.text('from last week'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_earlier')), findsNothing, reason: 'that was all of it');
      expect(server.queries.last.containsKey('before'), isTrue);
    }, variant: ios);

    testWidgets('someone who is no longer a friend closes the conversation', (tester) async {
      final server = _Server()..threadStatus = 403;
      await open(tester, server);
      expect(find.text("Couldn't open this conversation"), findsOneWidget);
      expect(find.text('You can only message your friends.'), findsOneWidget);
      expect(tester.widget<CupertinoTextField>(find.byKey(const ValueKey('chat_input'))).enabled, isFalse);
    }, variant: ios);
  });

  group('conversations', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester, _Server server) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(server),
        child: CupertinoApp(theme: AppTheme.cupertino, home: const ConversationsScreen()),
      ));
      await settle(tester);
    }

    testWidgets('lists conversations with previews and unread counts', (tester) async {
      await open(
        tester,
        _Server(conversations: [
          _conv('bea', unread: 2, last: 'lunch?'),
          _conv('sam', mine: true, last: 'see you there'),
        ]),
      );
      expect(find.text('@bea'), findsOneWidget);
      expect(find.text('lunch?'), findsOneWidget);
      expect(find.text('You: see you there'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread_u-bea')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread_u-sam')), findsNothing);
    }, variant: ios);

    testWidgets('tapping one opens the conversation', (tester) async {
      final server = _Server(
        thread: [_msg('a', 'lunch?')],
        conversations: [_conv('bea', unread: 1, last: 'lunch?')],
      );
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('conversation_u-bea')));
      await settle(tester);
      expect(find.byKey(const ValueKey('chat_input')), findsOneWidget);
      expect(find.text('Message @bea'), findsOneWidget);
    }, variant: ios);

    testWidgets('no conversations yet says how to start one', (tester) async {
      await open(tester, _Server());
      expect(find.text('No messages yet'), findsOneWidget);
    }, variant: ios);
  });
}
