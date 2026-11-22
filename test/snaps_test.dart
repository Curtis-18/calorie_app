import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/snaps.dart';
import 'package:calorie_app/screens/snap_viewer_screen.dart';
import 'package:calorie_app/providers/friends_provider.dart';
import 'package:calorie_app/providers/messages_provider.dart';
import 'package:calorie_app/services/messages_service.dart';
import 'package:calorie_app/providers/snaps_provider.dart';
import 'package:calorie_app/screens/friends_screen.dart';
import 'package:calorie_app/screens/snap_compose_screen.dart';
import 'package:calorie_app/services/friends_service.dart';
import 'package:calorie_app/services/snaps_service.dart';
import 'package:calorie_app/services/tour_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  biteTimeTests();
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

    test('a position on the caption is read, and an older server without one means the default spot', () {
      expect(InboxSnap.fromJson({..._inbox('a', 'sam'), 'caption_y': 0.3}).captionY, 0.3);
      expect(InboxSnap.fromJson({..._inbox('a', 'sam'), 'caption_y': 1}).captionY, 1.0);
      expect(InboxSnap.fromJson(_inbox('a', 'sam')).captionY, isNull);
    });

    test('send carries the caption position only with a caption', () async {
      final bodies = <Map<String, dynamic>>[];
      final service = _service(MockClient((r) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'recipients': []}), 200);
      }));
      await service.send(id: 'a', image: Uint8List(1), recipientIds: ['x'], caption: 'yum', captionY: 0.31234567);
      await service.send(id: 'b', image: Uint8List(1), recipientIds: ['x'], caption: '  ', captionY: 0.5);
      await service.send(id: 'c', image: Uint8List(1), recipientIds: ['x'], caption: 'yum');
      expect(bodies[0]['caption_y'], 0.3123);
      expect(bodies[1].containsKey('caption_y'), isFalse);
      expect(bodies[2].containsKey('caption_y'), isFalse);
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
    // The share tip remembers being dismissed; start every test unseen.
    setUp(() => SharedPreferences.setMockInitialValues({}));

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

    // Someone who has never sent a bite: no streak, nothing sent today.
    final newcomerJson = {
      ...friendsJson,
      'friends': [
        {'friendship_id': 'f-sam', 'user_id': 'u-sam', 'username': 'sam', 'since': '2026-11-01T00:00:00Z'},
        {'friendship_id': 'f-bea', 'user_id': 'u-bea', 'username': 'bea', 'since': '2026-11-01T00:00:00Z'},
      ],
    };

    MockClient backend({List<Map<String, dynamic>> inbox = const [], List<String>? sends, bool newcomer = false}) =>
        MockClient((r) async {
          if (r.url.path == '/friends') return http.Response(jsonEncode(newcomer ? newcomerJson : friendsJson), 200);
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

    testWidgets('a friend with an unseen bite gets a "New bite" mark with how long ago; others get none', (tester) async {
      final now = DateTime.now().toUtc();
      final fresh = {
        ..._inbox('a', 'sam'),
        'created_at': now.subtract(const Duration(hours: 2, minutes: 5)).toIso8601String(),
        'expires_at': now.add(const Duration(hours: 22)).toIso8601String(),
      };
      await open(tester, backend(inbox: [fresh]));
      expect(find.text('New bite · 2h ago'), findsOneWidget);
      expect(find.byKey(const ValueKey('new_u-sam')), findsOneWidget);
      expect(find.byKey(const ValueKey('new_u-bea')), findsNothing);
    });

    testWidgets('once the bite has been viewed the mark goes away', (tester) async {
      final now = DateTime.now().toUtc();
      final seen = {
        ..._inbox('a', 'sam', viewed: true),
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'expires_at': now.add(const Duration(hours: 23)).toIso8601String(),
      };
      await open(tester, backend(inbox: [seen]));
      expect(find.byKey(const ValueKey('new_u-sam')), findsNothing);
    });

    testWidgets('friend rows show the streak and who owes a bite; unseen bites show up', (tester) async {
      await open(tester, backend(inbox: [_inbox('a', 'sam')]));
      expect(find.text('Share your meal'), findsNothing, reason: 'they already swap bites, so no tip');
      expect(find.text('BITES FROM FRIENDS'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // streak badge
      expect(find.text('sent you a bite today. Send one back!'), findsOneWidget);
      // Both friends have a Bite button (the second is a scroll away).
      await tester.scrollUntilVisible(find.text('bea'), 120, scrollable: find.byType(Scrollable).first);
      expect(find.text('Bite', skipOffstage: false), findsNWidgets(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('taking a photo, picking a friend and sending reports the result', (tester) async {
      final sends = <String>[];
      final file = XFile.fromData(Uint8List.fromList(_png), name: 'a.png');
      await open(tester, backend(sends: sends), pick: () async => file);

      await tester.tap(find.text('Bite').first);
      await settle(tester);
      // Compose screen, with the tapped friend already ticked.
      expect(find.text('Send a bite'), findsOneWidget);
      expect(find.text('Send to 1 friend'), findsOneWidget);

      // The story row sits above the friends, so the second one is a scroll away.
      await tester.scrollUntilVisible(find.text('bea'), 120, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('bea'));
      await settle(tester);
      expect(find.text('Send to 2 friends'), findsOneWidget);

      await tester.tap(find.text('Send to 2 friends'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(sends.single, 'u-sam,u-bea');
      expect(find.text('Sent to 2 friends.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    Future<void> openViewer(WidgetTester tester, {required List<Map<String, dynamic>> posted, int failWith = 0, double? captionY}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final client = MockClient((r) async {
        if (r.url.path == '/messages/with/u-sam' && r.method == 'POST') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          posted.add({'friend': 'u-sam', ...body});
          if (failWith != 0) return http.Response(jsonEncode({'detail': "You can't message this person."}), failWith);
          return http.Response(
            jsonEncode({'id': body['id'], 'mine': true, 'body': body['body'], 'created_at': '2026-11-22T10:00:00Z'}),
            200,
          );
        }
        if (r.url.path == '/messages/conversations') return http.Response(jsonEncode({'conversations': []}), 200);
        return http.Response(jsonEncode([]), 200);
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) => ConversationsNotifier(
                service: MessagesService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
          snapInboxProvider.overrideWith((ref) => SnapInboxNotifier(
                service: SnapsService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: SnapViewerScreen(snaps: [InboxSnap.fromJson({..._inbox('a', 'sam'), 'caption_y': captionY})]),
        ),
      ));
      await settle(tester);
    }

    testWidgets('a bite caption is a white strip across the photo, at the spot its sender dragged it to', (tester) async {
      await openViewer(tester, posted: <Map<String, dynamic>>[]);
      expect(find.byKey(const ValueKey('caption_band')), findsOneWidget);
      expect(find.text('lunch'), findsOneWidget);
      final band = tester.getRect(find.byKey(const ValueKey('caption_band')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(band.width, screen.width, reason: 'edge to edge, like Snapchat');
      expect(band.center.dy, closeTo(screen.height * 0.62, 1), reason: 'the default spot when none was chosen');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a caption is shown exactly as typed, never translated, even if it matches a word the app translates', (tester) async {
      AppStrings.active = 'es';
      addTearDown(() => AppStrings.active = 'en');
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final client = MockClient((r) async => http.Response(jsonEncode([]), 200));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          conversationsProvider.overrideWith((ref) => ConversationsNotifier(
                service: MessagesService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
          snapInboxProvider.overrideWith((ref) => SnapInboxNotifier(
                service: SnapsService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: SnapViewerScreen(snaps: [InboxSnap.fromJson({..._inbox('a', 'sam'), 'caption': 'Lunch'})]),
        ),
      ));
      await settle(tester);
      // 'Lunch' is a word the app translates ('Almuerzo'); a friend's own words are left alone.
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a bite whose sender placed the caption high shows it high', (tester) async {
      await openViewer(tester, posted: <Map<String, dynamic>>[], captionY: 0.2);
      final band = tester.getRect(find.byKey(const ValueKey('caption_band')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(band.center.dy, closeTo(screen.height * 0.2, 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a quick reply goes to the sender as an ordinary chat message, once', (tester) async {
      final posted = <Map<String, dynamic>>[];
      await openViewer(tester, posted: posted);
      expect(find.text('Looks great'), findsOneWidget);
      expect(find.text('Save me a plate'), findsOneWidget);
      expect(find.text('Drop the recipe'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quick_save_plate')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('quick_save_plate'))); // a second tap does nothing
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(posted.length, 1);
      expect(posted.single['body'], 'Save me a plate');
      expect(posted.single['friend'], 'u-sam');
      expect(posted.single['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a reply the server refuses says so, and can be tried again', (tester) async {
      final posted = <Map<String, dynamic>>[];
      await openViewer(tester, posted: posted, failWith: 403);
      await tester.tap(find.byKey(const ValueKey('quick_drop_recipe')));
      await settle(tester);
      expect(find.text("You can't message this person."), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('quick_drop_recipe')));
      await settle(tester);
      expect(posted.length, 2, reason: 'not stuck as sent after a failure');
      expect(posted[1]['id'], posted[0]['id'], reason: 'a retry reuses the id so it cannot double up');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('"Bite back" in the viewer opens the camera, then the compose screen with the sender ticked', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final sends = <String>[];
      final client = backend(sends: sends, inbox: [_inbox('a', 'sam')]);
      final file = XFile.fromData(Uint8List.fromList(_png), name: 'a.png');
      var cameraOpened = 0;
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
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: SnapViewerScreen(
            snaps: [InboxSnap.fromJson(_inbox('a', 'sam'))],
            pickPhoto: () async {
              cameraOpened++;
              return file;
            },
          ),
        ),
      ));
      await settle(tester);

      expect(find.text('Bite back'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bite_back')));
      await settle(tester);
      expect(cameraOpened, 1);
      expect(find.text('Send a bite'), findsOneWidget);
      expect(find.text('Send to 1 friend'), findsOneWidget, reason: 'the sender is already ticked');

      await tester.tap(find.text('Send to 1 friend'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(sends.single, 'u-sam');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('backing out of the camera after "Bite back" sends nothing', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final sends = <String>[];
      final client = backend(sends: sends, inbox: [_inbox('a', 'sam')]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          snapInboxProvider.overrideWith((ref) => SnapInboxNotifier(
                service: SnapsService(client: client, tokenProvider: () => 't'),
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: SnapViewerScreen(snaps: [InboxSnap.fromJson(_inbox('a', 'sam'))], pickPhoto: () async => null),
        ),
      ));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('bite_back')));
      await settle(tester);
      expect(find.text('Send a bite'), findsNothing);
      expect(find.text('Bite back'), findsOneWidget, reason: 'still on the viewer');
      expect(sends, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('cancelling the camera sends nothing', (tester) async {
      final sends = <String>[];
      await open(tester, backend(sends: sends, newcomer: true), pick: () async => null);
      await tester.tap(find.text('Share your meal'));
      await settle(tester);
      expect(find.text('Send a bite'), findsNothing);
      expect(sends, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a new person sees the share tip once, and dismissing it keeps it away', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(tester, backend(newcomer: true));
      expect(find.byKey(const ValueKey('share_tip')), findsOneWidget);
      expect(find.text('TIP'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dismiss_share_tip')));
      await settle(tester);
      expect(find.byKey(const ValueKey('share_tip')), findsNothing);
      expect(await TourService.hasSeen(TourService.shareTip), isTrue);

      // Back on the tab later (a new screen): still gone.
      await tester.pumpWidget(const SizedBox());
      await open(tester, backend(newcomer: true));
      expect(find.byKey(const ValueKey('share_tip')), findsNothing);
      // Bites stay one tap away on each friend.
      expect(find.text('Bite'), findsNWidgets(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('sharing from the tip hides it afterwards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final file = XFile.fromData(Uint8List.fromList(_png), name: 'a.png');
      await open(tester, backend(newcomer: true), pick: () async => file);
      await tester.tap(find.text('Share your meal'));
      await settle(tester);
      expect(find.text('Send a bite'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('sam'), 120, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('sam'));
      await settle(tester);
      await tester.tap(find.text('Send to 1 friend'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('share_tip')), findsNothing);
      expect(await TourService.hasSeen(TourService.shareTip), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('no tip while there are no friends to share with', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await open(
        tester,
        MockClient((r) async {
          if (r.url.path == '/friends') {
            return http.Response(jsonEncode({'friends': [], 'incoming': [], 'outgoing': [], 'limit': 100}), 200);
          }
          if (r.url.path == '/me') return http.Response(jsonEncode({'username': 'river'}), 200);
          return http.Response('[]', 200);
        }),
      );
      expect(find.byKey(const ValueKey('share_tip')), findsNothing);
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

void biteTimeTests() {
  group('biteSentLabel', () {
    final now = DateTime(2026, 11, 5, 18, 0);
    test('same day shows just the time', () {
      expect(biteSentLabel(DateTime(2026, 11, 5, 15, 42), now: now), '3:42 PM');
    });
    test('midnight and noon use 12', () {
      expect(biteSentLabel(DateTime(2026, 11, 5, 0, 5), now: now), '12:05 AM');
      expect(biteSentLabel(DateTime(2026, 11, 5, 12, 0), now: now), '12:00 PM');
    });
    test('an earlier day says Yesterday', () {
      expect(biteSentLabel(DateTime(2026, 11, 4, 21, 10), now: now), 'Yesterday 9:10 PM');
    });
  });
}
