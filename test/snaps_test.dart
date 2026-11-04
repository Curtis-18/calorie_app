import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/providers/friends_provider.dart';
import 'package:calorie_app/providers/snaps_provider.dart';
import 'package:calorie_app/screens/friends_screen.dart';
import 'package:calorie_app/screens/snap_compose_screen.dart';
import 'package:calorie_app/services/friends_service.dart';
import 'package:calorie_app/services/snaps_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

// A 1x1 transparent PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Map<String, dynamic> _inbox(String id, String from, {bool viewed = false}) => {
      'snap_id': id,
      'sender_id': 'u-$from',
      'sender_username': from,
      'caption': 'lunch',
      'created_at': '2026-11-04T10:00:00Z',
      'expires_at': '2026-11-05T10:00:00Z',
      'viewed': viewed,
      'reaction': null,
      'image_url': null,
    };

SnapsService _service(MockClient client) => SnapsService(client: client, tokenProvider: () => 't');

void main() {
  group('service', () {
    test('snap ids are valid v4 uuids and differ', () {
      final a = newSnapId(), b = newSnapId();
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a, isNot(b));
    });

    test('send posts the photo, caption, recipients and device date, and reads streaks', () async {
      late Map<String, dynamic> body;
      final results = await _service(MockClient((r) async {
        expect(r.url.path, '/snaps');
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'snap_id': 's1',
            'expires_at': '2026-11-05T10:00:00Z',
            'recipients': [
              {'user_id': 'u-sam', 'username': 'sam', 'streak': 3, 'completed_today': true},
            ],
          }),
          200,
        );
      })).send(id: 's1', image: Uint8List.fromList(_png), recipientIds: ['u-sam'], caption: '  yum  ');
      expect(body['id'], 's1');
      expect(base64Decode(body['image'] as String), _png);
      expect(body['caption'], 'yum');
      expect(body['recipient_ids'], ['u-sam']);
      expect(body['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(results.single.streak, 3);
      expect(results.single.completedToday, isTrue);
    });

    test('a blank caption is left out and a server reason is surfaced', () async {
      late Map<String, dynamic> body;
      await _service(MockClient((r) async {
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'recipients': []}), 200);
      })).send(id: 's', image: Uint8List(1), recipientIds: ['x'], caption: '   ');
      expect(body.containsKey('caption'), isFalse);

      await expectLater(
        _service(MockClient((_) async => http.Response(jsonEncode({'detail': 'Snaps are not available right now.'}), 503)))
            .send(id: 's', image: Uint8List(1), recipientIds: ['x']),
        throwsA(isA<SnapsException>().having((e) => e.message, 'message', 'Snaps are not available right now.')),
      );
    });

    test('inbox and sent parse', () async {
      final inbox = await _service(MockClient((_) async => http.Response(jsonEncode([_inbox('a', 'sam')]), 200))).inbox();
      expect(inbox.single.senderUsername, 'sam');
      expect(inbox.single.viewed, isFalse);

      final sent = await _service(MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode([
              {
                'snap_id': 'a',
                'caption': null,
                'created_at': '2026-11-04T10:00:00Z',
                'expires_at': '2026-11-05T10:00:00Z',
                'image_url': null,
                'recipients': [
                  {'user_id': 'u1', 'username': 'sam', 'viewed': true, 'reaction': '🔥'}
                ],
              }
            ])),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ))).sent();
      expect(sent.single.recipients.single.reaction, '🔥');
    });

    test('react, view and report hit the right routes', () async {
      final calls = <String>[];
      final s = _service(MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        return http.Response('', 204);
      }));
      await s.markViewed('a');
      await s.react('a', '🔥');
      await s.report('a');
      await s.delete('a');
      expect(calls, ['POST /snaps/a/view', 'POST /snaps/a/react', 'POST /snaps/a/report', 'DELETE /snaps/a']);
    });

    test('friends load asks for streaks with the device date and reads them', () async {
      Uri? friendsUri;
      final data = await FriendsService(
        tokenProvider: () => 't',
        client: MockClient((r) async {
          if (r.url.path == '/friends') {
            friendsUri = r.url;
            return http.Response(
              jsonEncode({
                'friends': [
                  {
                    'friendship_id': 'f',
                    'user_id': 'u',
                    'username': 'sam',
                    'since': '2026-11-01T00:00:00Z',
                    'streak': 4,
                    'sent_today': true,
                    'they_sent_today': false,
                  }
                ],
                'incoming': [],
                'outgoing': [],
                'limit': 100,
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'username': 'me'}), 200);
        }),
      ).load();
      expect(friendsUri!.queryParameters['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(data.friends.single.streak, 4);
      expect(data.friends.single.sentToday, isTrue);
      expect(data.friends.single.theySentToday, isFalse);
    });
  });

  group('inbox provider', () {
    test('marking viewed updates at once and tolerates a failing server', () async {
      final notifier = SnapInboxNotifier(
        service: _service(MockClient((r) async {
          if (r.url.path == '/snaps/inbox') return http.Response(jsonEncode([_inbox('a', 'sam')]), 200);
          return http.Response('boom', 500);
        })),
        currentUserId: () => 'me',
        userIdChanges: const Stream.empty(),
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final snap = notifier.state.value!.single;
      await notifier.markViewed(snap);
      expect(notifier.state.value!.single.viewed, isTrue);
    });
  });

  group('screens', () {
    final friendsJson = {
      'friends': [
        {
          'friendship_id': 'f-sam',
          'user_id': 'u-sam',
          'username': 'sam',
          'since': '2026-11-01T00:00:00Z',
          'streak': 5,
          'sent_today': false,
          'they_sent_today': true,
        },
        {'friendship_id': 'f-bea', 'user_id': 'u-bea', 'username': 'bea', 'since': '2026-11-01T00:00:00Z'},
      ],
      'incoming': [],
      'outgoing': [],
      'limit': 100,
    };

    MockClient backend({List<Map<String, dynamic>> inbox = const [], List<String>? sends}) => MockClient((r) async {
          if (r.url.path == '/friends') return http.Response(jsonEncode(friendsJson), 200);
          if (r.url.path == '/me') return http.Response(jsonEncode({'username': 'river'}), 200);
          if (r.url.path == '/snaps/inbox') return http.Response(jsonEncode(inbox), 200);
          if (r.url.path == '/snaps' && r.method == 'POST') {
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            sends?.add((body['recipient_ids'] as List).join(','));
            return http.Response(
              jsonEncode({
                'snap_id': body['id'],
                'expires_at': '2026-11-05T10:00:00Z',
                'recipients': [
                  for (final id in body['recipient_ids'] as List)
                    {'user_id': id, 'username': (id as String).substring(2), 'streak': 6, 'completed_today': false},
                ],
              }),
              200,
            );
          }
          return http.Response('', 204);
        });

    Future<void> open(WidgetTester tester, MockClient client, {Future<XFile?> Function()? pick}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          friendsProvider.overrideWith((ref) => FriendsNotifier(
                service: FriendsService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
          snapInboxProvider.overrideWith((ref) => SnapInboxNotifier(
                service: SnapsService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(theme: AppTheme.cupertino, home: FriendsScreen(pickPhoto: pick)),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('friend rows show the streak and who owes a snap; unseen snaps show up', (tester) async {
      await open(tester, backend(inbox: [_inbox('a', 'sam')]));
      expect(find.text('Snap your food'), findsOneWidget);
      expect(find.text('SNAPS FROM FRIENDS'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // streak badge
      expect(find.text('sent you a snap today. Send one back!'), findsOneWidget);
      expect(find.text('Snap'), findsNWidgets(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('taking a photo, picking a friend and sending reports the result', (tester) async {
      final sends = <String>[];
      final file = XFile.fromData(Uint8List.fromList(_png), name: 'a.png');
      await open(tester, backend(sends: sends), pick: () async => file);

      await tester.tap(find.text('Snap').first);
      await settle(tester);
      // Compose screen, with the tapped friend already ticked.
      expect(find.text('Send a snap'), findsOneWidget);
      expect(find.text('Send to 1 friend'), findsOneWidget);

      await tester.tap(find.text('@bea'));
      await settle(tester);
      expect(find.text('Send to 2 friends'), findsOneWidget);

      await tester.tap(find.text('Send to 2 friends'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(sends.single, 'u-sam,u-bea');
      expect(find.text('Sent to 2 friends.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('cancelling the camera sends nothing', (tester) async {
      final sends = <String>[];
      await open(tester, backend(sends: sends), pick: () async => null);
      await tester.tap(find.text('Snap your food'));
      await settle(tester);
      expect(find.text('Send a snap'), findsNothing);
      expect(sends, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('send is disabled until a friend is picked', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          friendsProvider.overrideWith((ref) => FriendsNotifier(
                service: FriendsService(client: backend(), tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: SnapComposeScreen(image: Uint8List.fromList(_png)),
        ),
      ));
      await settle(tester);
      expect(find.text('Pick who gets it'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
