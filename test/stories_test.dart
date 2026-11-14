import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/models/friends.dart';
import 'package:calorie_app/models/snaps.dart';
import 'package:calorie_app/models/stories.dart';
import 'package:calorie_app/providers/friends_provider.dart';
import 'package:calorie_app/providers/snaps_provider.dart';
import 'package:calorie_app/screens/friends_screen.dart';
import 'package:calorie_app/screens/snap_compose_screen.dart';
import 'package:calorie_app/screens/story_viewer_screen.dart';
import 'package:calorie_app/services/avatar_service.dart';
import 'package:calorie_app/services/friends_service.dart';
import 'package:calorie_app/services/snaps_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/profile_photo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// A 1x1 transparent PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _person(String name, {int streak = 0, String? avatar}) => {
      'friendship_id': 'f-$name',
      'user_id': 'u-$name',
      'username': name,
      'avatar_url': avatar,
      'since': '2026-11-01T10:00:00Z',
      'streak': streak,
      'sent_today': false,
      'they_sent_today': false,
    };

Map<String, dynamic> _story(String id, {bool viewed = false, String? caption}) => {
      'story_id': id,
      'caption': caption,
      'created_at': '2026-11-14T10:00:00Z',
      'expires_at': '2026-11-15T10:00:00Z',
      'image_url': null,
      'viewed': viewed,
      'reaction': null,
    };

/// A pretend backend: friends, /me and stories, recording what it is asked.
class _Server {
  _Server({this.friends = const [], this.groups = const [], this.storiesStatus = 200});

  final List<Map<String, dynamic>> friends;
  List<Map<String, dynamic>> mine = const [];
  final List<Map<String, dynamic>> groups;
  final int storiesStatus;
  final calls = <String>[];
  final bodies = <String, Map<String, dynamic>>{};

  MockClient get client => MockClient((r) async {
        final call = '${r.method} ${r.url.path}';
        calls.add(call);
        if (r.body.isNotEmpty) bodies[call] = jsonDecode(r.body) as Map<String, dynamic>;
        if (r.url.path == '/friends') {
          return _json({'friends': friends, 'incoming': [], 'outgoing': [], 'limit': 100});
        }
        if (r.url.path == '/me') return _json({'user_id': 'me', 'username': 'river', 'avatar_url': null});
        if (r.url.path == '/snaps/inbox') return _json([]);
        if (call == 'GET /stories') {
          return storiesStatus == 200 ? _json({'mine': mine, 'friends': groups}) : _json({'detail': 'no'}, storiesStatus);
        }
        if (call == 'POST /stories') {
          mine = [..._mineAfterPost];
          return _json({'story_id': bodies[call]!['id'], 'expires_at': '2026-11-15T10:00:00Z'});
        }
        if (call == 'POST /me/avatar') return _json({'avatar_url': 'https://x/new.jpg'});
        if (call == 'POST /snaps') {
          return _json({
            'snap_id': 's',
            'expires_at': '2026-11-15T10:00:00Z',
            'recipients': [
              for (final id in bodies[call]!['recipient_ids'] as List)
                {'user_id': id, 'username': (id as String).substring(2), 'streak': 0, 'completed_today': false},
            ],
          });
        }
        return http.Response('', 204);
      });

  List<Map<String, dynamic>> get _mineAfterPost => [
        ...mine,
        {..._story('new')..remove('viewed')..remove('reaction'), 'viewers': []},
      ];
}

SnapsService _snaps(_Server s) => SnapsService(client: s.client, tokenProvider: () => 't');

List<Override> _overrides(_Server s) => [
      friendsProvider.overrideWith((ref) => FriendsNotifier(
            service: FriendsService(client: s.client, tokenProvider: () => 't'),
            currentUserId: () => 'me',
            userIdChanges: const Stream.empty(),
          )),
      snapInboxProvider.overrideWith((ref) => SnapInboxNotifier(
            service: _snaps(s),
            currentUserId: () => 'me',
            userIdChanges: const Stream.empty(),
          )),
    ];

Future<void> settle(WidgetTester tester, [int ticks = 12]) async {
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('friends order', () {
    test('the longest streaks come first, then names', () {
      final data = FriendsData.fromJson({
        'friends': [_person('aaron'), _person('zoe', streak: 9), _person('Mia', streak: 2), _person('bo', streak: 2)],
      });
      expect([for (final p in data.friends) p.username], ['zoe', 'bo', 'Mia', 'aaron']);
    });

    test('pictures are read for friends and for me', () {
      final data = FriendsData.fromJson(
        {'friends': [_person('sam', avatar: 'https://x/sam.jpg')]},
        myAvatarUrl: 'https://x/me.jpg',
      );
      expect(data.friends.single.avatarUrl, 'https://x/sam.jpg');
      expect(data.myAvatarUrl, 'https://x/me.jpg');
    });
  });

  group('story feed', () {
    test('parses mine with viewers and friends with what is unseen', () {
      final feed = StoryFeed.fromJson({
        'mine': [
          {
            ..._story('m1'),
            'viewers': [
              {'user_id': 'u-sam', 'username': 'sam', 'avatar_url': null, 'reaction': '🔥'},
            ],
          },
        ],
        'friends': [
          {
            'user_id': 'u-sam',
            'username': 'sam',
            'avatar_url': 'https://x/sam.jpg',
            'streak': 4,
            'all_seen': false,
            'stories': [_story('a', viewed: true), _story('b'), _story('c')],
          },
          {'user_id': 'u-empty', 'username': 'empty', 'stories': []},
        ],
      });
      expect(feed.mine.single.viewers.single.reaction, '🔥');
      final sam = feed.friends.single; // someone with nothing to show is dropped
      expect((sam.streak, sam.allSeen, sam.firstUnseen, sam.avatarUrl), (4, false, 1, 'https://x/sam.jpg'));
    });

    test('a story everyone has seen starts from the beginning', () {
      final g = FriendStories.fromJson({
        'user_id': 'u',
        'username': 'sam',
        'stories': [_story('a', viewed: true), _story('b', viewed: true)],
      });
      expect((g.allSeen, g.firstUnseen), (true, 0));
    });
  });

  group('service', () {
    test('posting a story sends the photo and caption, with no recipients', () async {
      final server = _Server();
      await _snaps(server).postStory(id: 'abc', image: Uint8List.fromList(_png), caption: ' lunch ');
      final body = server.bodies['POST /stories']!;
      expect(body['id'], 'abc');
      expect(body['caption'], 'lunch');
      expect(base64Decode(body['image'] as String), _png);
      expect(body.containsKey('recipient_ids'), isFalse);
    });

    test('a refused story surfaces the server message', () async {
      final service = SnapsService(
        client: MockClient((_) async => _json({'detail': 'Your story is full for now.'}, 429)),
        tokenProvider: () => 't',
      );
      expect(
        () => service.postStory(id: 'a', image: Uint8List.fromList(_png)),
        throwsA(isA<SnapsException>().having((e) => e.message, 'message', 'Your story is full for now.')),
      );
    });

    test('view, react, report and delete hit the story routes', () async {
      final server = _Server();
      final service = _snaps(server);
      await service.markStoryViewed('s1');
      await service.reactToStory('s1', '🔥');
      await service.reportStory('s1');
      await service.deleteStory('s1');
      expect(server.calls, ['POST /stories/s1/view', 'POST /stories/s1/react', 'POST /stories/s1/report', 'DELETE /stories/s1']);
      expect(server.bodies['POST /stories/s1/react'], {'emoji': '🔥'});
    });

    test('a profile photo is uploaded and removed', () async {
      final server = _Server();
      final service = AvatarService(client: server.client, tokenProvider: () => 't');
      final failing = AvatarService(
        client: MockClient((_) async => _json({'detail': 'That photo is too large.'}, 413)),
        tokenProvider: () => 't',
      );
      await expectLater(
        failing.upload(Uint8List.fromList(_png)),
        throwsA(isA<AvatarException>().having((e) => e.message, 'message', 'That photo is too large.')),
      );
      await service.remove();
      expect(server.calls, ['DELETE /me/avatar']);
    });

    test('a photo is cropped to a 512 square JPEG', () async {
      final wide = Uint8List.fromList(img.encodePng(img.Image(width: 900, height: 600)));
      final out = img.decodeJpg(await prepareAvatar(wide))!;
      expect((out.width, out.height), (avatarSize, avatarSize));
      expect(() => prepareAvatar(Uint8List.fromList([1, 2, 3])), throwsA(anything));
    });
  });

  group('stories provider', () {
    test('viewing and reacting update the feed straight away', () async {
      final server = _Server(groups: [
        {'user_id': 'u-sam', 'username': 'sam', 'stories': [_story('a'), _story('b')]},
      ]);
      final notifier = StoriesNotifier(
        service: _snaps(server),
        currentUserId: () => 'me',
        userIdChanges: const Stream.empty(),
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await notifier.markViewed('a');
      await notifier.react('b', '😋');
      final sam = notifier.state.value!.friends.single;
      expect([for (final s in sam.stories) (s.viewed, s.reaction)], [(true, null), (true, '😋')]);
      expect(sam.allSeen, isTrue);
    });

    test('a server without stories is an error, not a crash', () async {
      final notifier = StoriesNotifier(
        service: _snaps(_Server(storiesStatus: 404)),
        currentUserId: () => 'me',
        userIdChanges: const Stream.empty(),
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.state.hasError, isTrue);
    });
  });

  group('friends screen', () {
    Future<void> open(WidgetTester tester, _Server server, {Future<XFile?> Function()? pick}) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(server),
        child: CupertinoApp(theme: AppTheme.cupertino, home: FriendsScreen(pickPhoto: pick)),
      ));
      await settle(tester);
    }

    testWidgets('the tray shows my story and friends who posted', (tester) async {
      await open(
        tester,
        _Server(friends: [_person('sam'), _person('bea')], groups: [
          {'user_id': 'u-sam', 'username': 'sam', 'stories': [_story('a')]},
        ]),
      );
      expect(find.text('Your story'), findsOneWidget);
      expect(find.byKey(const ValueKey('story_u-sam')), findsOneWidget);
      expect(find.byKey(const ValueKey('story_u-bea')), findsNothing);
    }, variant: ios);

    testWidgets('a friend with a streak shows a flame on their bubble, burning only when kept today', (tester) async {
      await open(
        tester,
        _Server(friends: [
          {..._person('sam', streak: 9), 'sent_today': true, 'they_sent_today': true},
          _person('bea', streak: 4),
          _person('cy'),
        ], groups: [
          {'user_id': 'u-sam', 'username': 'sam', 'streak': 9, 'stories': [_story('a')]},
          {'user_id': 'u-bea', 'username': 'bea', 'streak': 4, 'stories': [_story('b')]},
          {'user_id': 'u-cy', 'username': 'cy', 'stories': [_story('c')]},
        ]),
      );
      Finder badge(String id) =>
          find.descendant(of: find.byKey(ValueKey('story_$id')), matching: find.byKey(const ValueKey('streak_badge')));
      expect(badge('u-sam'), findsOneWidget);
      expect(find.descendant(of: badge('u-sam'), matching: find.text('9')), findsOneWidget);
      // Inside a tappable bubble the labels merge with the name, so look for
      // the badges' own labels.
      Finder labelled(String id, String text) => find.descendant(
            of: find.byKey(ValueKey('story_$id')),
            matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == text),
          );
      expect(labelled('u-sam', '9 day streak'), findsOneWidget);
      expect(labelled('u-bea', '4 day streak, not kept yet today'), findsOneWidget);
      expect(badge('u-bea'), findsOneWidget);
      expect(badge('u-cy'), findsNothing, reason: 'no streak, no flame');
    }, variant: ios);

    testWidgets('no tray when the server has no stories', (tester) async {
      await open(tester, _Server(friends: [_person('sam')], storiesStatus: 404));
      expect(find.text('Your story'), findsNothing);
      expect(find.text('@sam'), findsOneWidget);
    }, variant: ios);

    testWidgets('an empty story opens the camera and posts to the story only', (tester) async {
      final server = _Server(friends: [_person('sam')]);
      final file = XFile.fromData(Uint8List.fromList(_png), name: 'a.png');
      await open(tester, server, pick: () async => file);

      await tester.tap(find.byKey(const ValueKey('my_story')));
      await settle(tester);
      expect(find.text('Add to your story'), findsOneWidget); // already ticked

      await tester.tap(find.text('Add to your story'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(server.calls, contains('POST /stories'));
      expect(server.calls, isNot(contains('POST /snaps')));
      expect(find.text('Added to your story.'), findsOneWidget);
    }, variant: ios);

    testWidgets("tapping a friend's bubble plays their story and marks it seen", (tester) async {
      final server = _Server(friends: [_person('sam')], groups: [
        {'user_id': 'u-sam', 'username': 'sam', 'stories': [_story('a', caption: 'pasta')]},
      ]);
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('story_u-sam')));
      await settle(tester, 6);
      expect(find.text('pasta'), findsOneWidget);
      expect(server.calls, contains('POST /stories/a/view'));
      await tester.tap(find.byKey(const ValueKey('story_close')));
      await settle(tester);
      expect(find.text('pasta'), findsNothing);
    }, variant: ios);
  });

  group('compose', () {
    Future<_Server> open(WidgetTester tester, {bool toStory = false}) async {
      _phone(tester);
      final server = _Server(friends: [_person('sam')]);
      ComposeResult? result;
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(server),
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: Builder(
            builder: (context) => CupertinoButton(
              child: const Text('go'),
              onPressed: () async {
                result = await Navigator.of(context).push<ComposeResult>(CupertinoPageRoute(
                  builder: (_) => SnapComposeScreen(image: Uint8List.fromList(_png), service: _snaps(server), toStory: toStory),
                ));
                server.calls.add('done: ${result == null ? 'nothing' : shareSummary(result!)}');
              },
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await settle(tester);
      return server;
    }

    testWidgets('story and a friend together make one share', (tester) async {
      final server = await open(tester);
      expect(find.text('Pick who gets it'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('story_choice')));
      await tester.tap(find.text('@sam'));
      await settle(tester, 4);
      await tester.tap(find.text('Share to story and 1 friend'));
      await settle(tester);
      expect(server.calls.where((c) => c.startsWith('POST')), ['POST /stories', 'POST /snaps']);
      expect(server.calls.last, 'done: Sent to @sam and added to your story.');
    }, variant: ios);

    test('the summary says where the photo went', () {
      const sam = SendOutcome(userId: 'u', username: 'sam', streak: 0, completedToday: false);
      expect(shareSummary(const ComposeResult(addedToStory: true)), 'Added to your story.');
      expect(shareSummary(const ComposeResult(outcomes: [sam])), 'Sent to @sam.');
      expect(shareSummary(const ComposeResult(outcomes: [sam, sam])), 'Sent to 2 friends.');
    });
  });

  group('viewer', () {
    StoryItem item(String id, {List<StoryViewer> viewers = const []}) => StoryItem(
          id: id,
          imageUrl: null,
          caption: 'photo $id',
          createdAt: DateTime(2026, 11, 14, 10),
          viewers: viewers,
        );

    Future<_Server> open(WidgetTester tester, List<StoryReel> reels) async {
      _phone(tester);
      final server = _Server();
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(server),
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: Builder(
            builder: (context) => CupertinoButton(
              child: const Text('go'),
              onPressed: () async {
                final r = await Navigator.of(context)
                    .push<String>(CupertinoPageRoute(builder: (_) => StoryViewerScreen(reels: reels)));
                server.calls.add('closed: $r');
              },
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await settle(tester, 6);
      return server;
    }

    final sam = StoryReel(username: 'sam', items: [item('a'), item('b')]);
    final bea = StoryReel(username: 'bea', items: [item('c')]);

    testWidgets('photos play on their own, person after person, then it closes', (tester) async {
      final server = await open(tester, [sam, bea]);
      expect(find.text('photo a'), findsOneWidget);
      await tester.pump(StoryViewerScreen.perStory);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('photo b'), findsOneWidget);
      await tester.pump(StoryViewerScreen.perStory);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('photo c'), findsOneWidget);
      expect(find.text('@bea'), findsOneWidget);
      await tester.pump(StoryViewerScreen.perStory);
      await settle(tester);
      expect(find.text('photo c'), findsNothing);
      expect(server.calls.where((c) => c.endsWith('/view')).length, 3);
    }, variant: ios);

    testWidgets('tap right to skip on, left to go back', (tester) async {
      await open(tester, [sam, bea]);
      await tester.tapAt(const Offset(300, 400));
      await settle(tester, 3);
      expect(find.text('photo b'), findsOneWidget);
      await tester.tapAt(const Offset(40, 400));
      await settle(tester, 3);
      expect(find.text('photo a'), findsOneWidget);
    }, variant: ios);

    testWidgets('holding pauses the countdown', (tester) async {
      await open(tester, [sam]);
      final hold = await tester.startGesture(const Offset(200, 400));
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('photo a'), findsOneWidget);
      await hold.up();
      await settle(tester, 3);
      expect(find.text('photo a'), findsOneWidget); // released: carries on from where it was
    }, variant: ios);

    testWidgets('reacting and reporting go to the server', (tester) async {
      final server = await open(tester, [sam]);
      await tester.tap(find.text('🔥'));
      await settle(tester, 3);
      expect(server.bodies['POST /stories/a/react'], {'emoji': '🔥'});
      await tester.tap(find.byKey(const ValueKey('story_menu')));
      await settle(tester, 6);
      await tester.tap(find.text('Report this story'));
      await settle(tester, 6);
      expect(server.calls, contains('POST /stories/a/report'));
      expect(find.text('Thanks for telling us'), findsOneWidget);
    }, variant: ios);

    testWidgets('my own story shows who saw it, can add more, and has no reactions', (tester) async {
      final mine = StoryReel(username: 'river', isMine: true, items: [
        item('m', viewers: const [StoryViewer(userId: 'u-sam', username: 'sam', reaction: '😋')]),
      ]);
      final server = await open(tester, [mine]);
      expect(find.text('Your story'), findsOneWidget);
      expect(find.text('🔥'), findsNothing);
      expect(server.calls.where((c) => c.endsWith('/view')), isEmpty);

      await tester.tap(find.byKey(const ValueKey('story_seen_by')));
      await settle(tester, 6);
      expect(find.text('@sam'), findsOneWidget);
      expect(find.text('😋'), findsOneWidget);
      await tester.tapAt(const Offset(200, 40)); // close the sheet
      await settle(tester, 6);

      await tester.tap(find.byKey(const ValueKey('story_add')));
      await settle(tester);
      expect(server.calls.last, 'closed: add');
    }, variant: ios);

    testWidgets('deleting my only photo closes the viewer', (tester) async {
      final server = await open(tester, [StoryReel(username: 'river', isMine: true, items: [item('m')])]);
      await tester.tap(find.byKey(const ValueKey('story_menu')));
      await settle(tester, 6);
      await tester.tap(find.text('Delete this photo'));
      await settle(tester);
      expect(server.calls, contains('DELETE /stories/m'));
      expect(server.calls.last, 'closed: null');
    }, variant: ios);
  });

  group('profile photo', () {
    Future<_Server> open(WidgetTester tester, {String? imageUrl, List<String>? events}) async {
      _phone(tester);
      final server = _Server();
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Center(
          child: ProfilePhotoButton(
            username: 'river',
            imageUrl: imageUrl,
            service: AvatarService(client: server.client, tokenProvider: () => 't'),
            pick: (source) async {
              events?.add('pick ${source.name}');
              return XFile.fromData(Uint8List.fromList(_png), name: 'a.png');
            },
            prepare: (bytes) async => bytes,
            onChanged: () => events?.add('changed'),
          ),
        ),
      ));
      await tester.tap(find.byType(ProfilePhotoButton));
      await settle(tester, 6);
      return server;
    }

    testWidgets('choosing from the library uploads it and tells the page', (tester) async {
      final events = <String>[];
      final server = await open(tester, events: events);
      expect(find.text('Remove photo'), findsNothing); // nothing to remove yet
      await tester.tap(find.text('Choose from library'));
      await settle(tester);
      expect(events, ['pick gallery', 'changed']);
      expect(base64Decode(server.bodies['POST /me/avatar']!['image'] as String), _png);
    }, variant: ios);

    testWidgets('a photo can be removed', (tester) async {
      final events = <String>[];
      final server = await open(tester, imageUrl: 'https://x/me.jpg', events: events);
      await tester.tap(find.text('Remove photo'));
      await settle(tester);
      expect(server.calls, ['DELETE /me/avatar']);
      expect(events, ['changed']);
    }, variant: ios);
  });
}
