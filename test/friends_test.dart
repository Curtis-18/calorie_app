import 'dart:convert';

import 'package:calorie_app/models/friends.dart';
import 'package:calorie_app/providers/friends_provider.dart';
import 'package:calorie_app/providers/snaps_provider.dart';
import 'package:calorie_app/services/snaps_service.dart';
import 'package:calorie_app/screens/friends_screen.dart';
import 'package:calorie_app/services/friends_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _person(String name, {String? id}) => {
      'friendship_id': id ?? 'f-$name',
      'user_id': 'u-$name',
      'username': name,
      'since': '2026-11-04T10:00:00Z',
    };

/// A tiny in-memory backend for the friends routes.
class _Server {
  _Server({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
  });

  List<String> friends, incoming, outgoing;
  final String me = 'River_Song';
  final calls = <String>[];
  http.Response? Function(http.Request)? onRequest;

  MockClient get client => MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        final custom = onRequest?.call(r);
        if (custom != null) return custom;
        if (r.url.path == '/friends' && r.method == 'GET') {
          return http.Response(
            jsonEncode({
              'friends': friends.map(_person).toList(),
              'incoming': incoming.map(_person).toList(),
              'outgoing': outgoing.map(_person).toList(),
              'limit': 100,
            }),
            200,
          );
        }
        if (r.url.path == '/me') return http.Response(jsonEncode({'user_id': 'me', 'username': me}), 200);
        if (r.url.path.endsWith('/accept')) {
          final name = r.url.pathSegments[2].substring(2);
          incoming = incoming.where((n) => n != name).toList();
          friends = [...friends, name];
          return http.Response('', 204);
        }
        if (r.url.path == '/friends/requests') {
          final name = jsonDecode(r.body)['username'] as String;
          if (name == 'ghost') return http.Response(jsonEncode({'detail': "We couldn't find anyone with that username."}), 404);
          outgoing = [...outgoing, name];
          return http.Response(jsonEncode({'outcome': 'sent', 'username': name}), 200);
        }
        return http.Response('', 204);
      });
}

FriendsService _service(_Server s) => FriendsService(client: s.client, tokenProvider: () => 'token');

FriendsNotifier _notifier(_Server s) => FriendsNotifier(
      service: _service(s),
      currentUserId: () => 'me',
      userIdChanges: const Stream.empty(),
    );

void main() {
  group('service', () {
    test('load reads the lists and my username', () async {
      final data = await _service(_Server(friends: ['Sam'], incoming: ['Bea'], outgoing: ['Cy'])).load();
      expect(data.friends.single.username, 'Sam');
      expect(data.incoming.single.friendshipId, 'f-Bea');
      expect(data.outgoing.single.username, 'Cy');
      expect(data.myUsername, 'River_Song');
      expect(data.limit, 100);
    });

    test('sendRequest returns the outcome; errors carry the server\'s words', () async {
      final server = _Server();
      final ok = await _service(server).sendRequest(' Sam ');
      expect(ok.outcome, RequestOutcome.sent);

      expect(
        () => _service(server).sendRequest('ghost'),
        throwsA(isA<FriendsException>().having((e) => e.message, 'message', "We couldn't find anyone with that username.")),
      );
    });

    test('accepting an already-gone request says so instead of a generic failure', () async {
      final server = _Server()..onRequest = (_) => http.Response(jsonEncode({'detail': "That request isn't there any more."}), 404);
      expect(
        () => _service(server).accept('f-x'),
        throwsA(isA<FriendsException>().having((e) => e.message, 'message', "That request isn't there any more.")),
      );
    });

    test('offline and signed out are readable', () async {
      final offline = MockClient((_) async => throw http.ClientException('x'));
      expect(() => FriendsService(client: offline, tokenProvider: () => 't').load(),
          throwsA(isA<FriendsException>().having((e) => e.message, 'm', contains("Couldn't reach"))));
      expect(() => FriendsService(client: offline, tokenProvider: () => null).load(),
          throwsA(isA<FriendsException>().having((e) => e.message, 'm', contains('signed out'))));
    });

    test('blocks and unblock', () async {
      final server = _Server()
        ..onRequest = (r) => r.url.path == '/blocks' ? http.Response(jsonEncode([_person('Troll', id: 'x')..remove('friendship_id')]), 200) : http.Response('', 204);
      final list = await _service(server).blocks();
      expect(list.single.username, 'Troll');
      expect(list.single.friendshipId, isNull);
      await _service(server).unblock('u-Troll');
      expect(server.calls.last, 'DELETE /blocks/u-Troll');
    });
  });

  group('provider', () {
    test('loads for the signed-in user and refreshes after an action', () async {
      final server = _Server(incoming: ['Bea']);
      final notifier = _notifier(server);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state.value!.incoming.single.username, 'Bea');

      await notifier.accept(notifier.state.value!.incoming.single);
      expect(notifier.state.value!.incoming, isEmpty);
      expect(notifier.state.value!.friends.single.username, 'Bea');
    });

    test('a failed action still refreshes, and rethrows for the screen', () async {
      final server = _Server(friends: ['Sam']);
      final notifier = _notifier(server);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      server.friends = []; // they unfriended us meanwhile
      server.onRequest = (r) => r.method == 'DELETE' ? http.Response(jsonEncode({'detail': 'They aren\'t on your list.'}), 404) : null;
      await expectLater(notifier.remove(notifier.state.value!.friends.single), throwsA(isA<FriendsException>()));
      expect(notifier.state.value!.friends, isEmpty);
    });

    test('nothing loads while signed out, and a new user starts clean', () async {
      final server = _Server(friends: ['Sam']);
      final ids = Stream<String?>.fromIterable([]);
      final signedOut = FriendsNotifier(service: _service(server), currentUserId: () => null, userIdChanges: ids);
      addTearDown(signedOut.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.calls, isEmpty);
      expect(signedOut.state.isLoading, isTrue);
    });

    test('the tab badge counts incoming requests only', () async {
      final server = _Server(friends: ['Sam'], incoming: ['Bea', 'Cy'], outgoing: ['Dee']);
      final notifier = _notifier(server);
      final container = ProviderContainer(overrides: [friendsProvider.overrideWith((ref) => notifier)]);
      addTearDown(container.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(pendingRequestCountProvider), 2);
    });
  });

  group('screen', () {
    Future<_Server> open(WidgetTester tester, _Server server) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final notifier = _notifier(server);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          friendsProvider.overrideWith((ref) => notifier),
          snapInboxProvider.overrideWith((ref) => SnapInboxNotifier(
                service: SnapsService(client: MockClient((_) async => http.Response('[]', 200)), tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(theme: AppTheme.cupertino, home: const FriendsScreen()),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return server;
    }

    testWidgets('shows my username, requests and friends', (tester) async {
      await open(tester, _Server(friends: ['Sam'], incoming: ['Bea'], outgoing: ['Cy']));
      expect(find.text('@River_Song'), findsOneWidget);
      expect(find.text('@Bea'), findsOneWidget);
      expect(find.text('wants to be your friend'), findsOneWidget);
      expect(find.text('@Cy'), findsOneWidget);
      expect(find.text('request sent'), findsOneWidget);
      expect(find.text('@Sam'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('accepting moves a request into friends', (tester) async {
      await open(tester, _Server(incoming: ['Bea']));
      await tester.tap(find.text('Accept'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('wants to be your friend'), findsNothing);
      expect(find.text('@Bea'), findsOneWidget);
      expect(find.textContaining('friends since'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('adding a friend shows a confirmation; a missing user shows the reason', (tester) async {
      final server = await open(tester, _Server());
      await tester.enterText(find.byType(CupertinoTextField), '@Sam_1');
      await tester.tap(find.text('Add'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Request sent to @Sam_1.'), findsOneWidget);
      expect(server.calls, contains('POST /friends/requests'));

      await tester.enterText(find.byType(CupertinoTextField), 'ghost');
      await tester.tap(find.text('Add'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text("We couldn't find anyone with that username."), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a malformed name is caught without asking the server', (tester) async {
      final server = await open(tester, _Server());
      final before = server.calls.length;
      await tester.enterText(find.byType(CupertinoTextField), '1bad');
      await tester.tap(find.text('Add'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('must start with a letter'), findsOneWidget);
      expect(server.calls.length, before);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('an empty list invites the user to add someone', (tester) async {
      await open(tester, _Server());
      expect(find.text('No friends yet'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a failing server shows a retry, not a blank screen', (tester) async {
      final server = _Server()..onRequest = (r) => r.url.path == '/friends' ? http.Response('boom', 500) : null;
      await open(tester, server);
      expect(find.text("Couldn't load your friends"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
