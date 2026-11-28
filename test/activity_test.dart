import 'dart:convert';

import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/activity.dart';
import 'package:calorie_app/models/snaps.dart';
import 'package:calorie_app/providers/activity_provider.dart';
import 'package:calorie_app/providers/shell_provider.dart';
import 'package:calorie_app/providers/snaps_provider.dart';
import 'package:calorie_app/screens/snap_viewer_screen.dart';
import 'package:calorie_app/providers/whats_new_provider.dart';
import 'package:calorie_app/screens/notifications_screen.dart';
import 'package:calorie_app/services/activity_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> line(String id, String kind, {String name = 'sam', String? emoji, bool seen = false, int minutesAgo = 3, String? snapId}) => {
      'id': id,
      'kind': kind,
      'username': name,
      'emoji': emoji,
      'created_at': DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      'seen': seen,
      'snap_id': ?snapId,
    };

/// A bite in the inbox, [hoursLeft] before it expires (relative to now, so
/// the test never depends on today's date).
InboxSnap bite(String id, {String from = 'sam', int hoursLeft = 5}) => InboxSnap(
      id: id,
      senderId: 'u_$from',
      senderUsername: from,
      caption: null,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiresAt: DateTime.now().add(Duration(hours: hoursLeft)),
      viewed: false,
      reaction: null,
      imageUrl: null,
    );

/// An inbox with no network: [onLoad] is what a refresh finds.
class FakeInbox extends SnapInboxNotifier {
  FakeInbox(List<InboxSnap>? snaps, {this.onLoad}) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    if (snaps != null) state = AsyncValue.data(snaps);
  }
  final List<InboxSnap>? onLoad;
  int loads = 0;

  @override
  Future<void> load() async {
    loads++;
    if (onLoad != null) state = AsyncValue.data(onLoad!);
  }

  @override
  Future<void> markViewed(InboxSnap snap) async {}
}

class Server {
  Server(this.items, {this.unread});
  List<Map<String, dynamic>> items;
  int? unread;
  int seenCalls = 0;
  int listCalls = 0;
  bool failList = false;

  MockClient get client => MockClient((req) async {
        if (req.method == 'POST' && req.url.path == '/activity/seen') {
          seenCalls++;
          for (final i in items) {
            i['seen'] = true;
          }
          unread = 0;
          return http.Response('', 204);
        }
        listCalls++;
        if (failList) return http.Response('no', 500);
        final n = unread ?? items.where((i) => i['seen'] != true).length;
        return http.Response(jsonEncode({'items': items, 'unread': n}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

ActivityNotifier notifier(Server s, {String? user = 'ann'}) => ActivityNotifier(
      service: ActivityService(client: s.client, tokenProvider: () => 't'),
      currentUserId: () => user,
      userIdChanges: const Stream.empty(),
    );

Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('reading the server', () {
    test('bites and reactions are read; an unknown kind or a broken line is skipped', () {
      final data = ActivityData.fromJson({
        'items': [
          line('1', 'bite'),
          line('2', 'reaction', emoji: '🔥'),
          line('3', 'message'),
          {'id': 4},
          'junk',
        ],
        'unread': 2,
      });
      expect(data.items.map((i) => i.id), ['1', '2']);
      expect(data.items[1].emoji, '🔥');
      expect(data.unread, 2);
    });

    test('a bite line may name its bite; an older server, or an odd value, names none', () {
      expect(ActivityItem.fromJson(line('1', 'bite', snapId: 's1'))!.snapId, 's1');
      expect(ActivityItem.fromJson(line('1', 'bite'))!.snapId, isNull);
      expect(ActivityItem.fromJson({...line('1', 'bite'), 'snap_id': 7})!.snapId, isNull);
      expect(ActivityItem.fromJson({...line('1', 'bite'), 'snap_id': ''})!.snapId, isNull);
      // Opening the list marks lines seen; the copy must keep its bite.
      expect(ActivityItem.fromJson(line('1', 'bite', snapId: 's1'))!.asSeen().snapId, 's1');
    });

    test('a strange unread count is zero', () {
      expect(ActivityData.fromJson({'items': [], 'unread': -4}).unread, 0);
      expect(ActivityData.fromJson({'items': [], 'unread': 'x'}).unread, 0);
      expect(ActivityData.fromJson({}).items, isEmpty);
    });

    test('short times', () {
      final now = DateTime(2026, 11, 25, 12);
      String a(Duration d) => shortAgo(now, now.subtract(d), justNow: 'now');
      expect(a(const Duration(seconds: 20)), 'now');
      expect(a(const Duration(minutes: 5)), '5m');
      expect(a(const Duration(hours: 3)), '3h');
      expect(a(const Duration(days: 2, hours: 4)), '2d');
    });
  });

  group('the provider', () {
    test('loads on sign-in, and is empty when signed out', () async {
      final s = Server([line('1', 'bite')]);
      final n = notifier(s);
      addTearDown(n.dispose);
      await n.load();
      expect(n.state.items.length, 1);
      expect(n.state.unread, 1);

      final out = notifier(Server([line('1', 'bite')]), user: null);
      addTearDown(out.dispose);
      await wait();
      expect(out.state.items, isEmpty);
    });

    test('opening clears the count at once and tells the server', () async {
      final s = Server([line('1', 'bite'), line('2', 'reaction', emoji: '🔥')]);
      final n = notifier(s);
      addTearDown(n.dispose);
      await n.load();
      expect(n.state.unread, 2);
      await n.markSeen();
      expect(n.state.unread, 0);
      expect(n.state.items.every((i) => i.seen), isTrue);
      expect(s.seenCalls, 1);
    });

    test('a failed refresh keeps what is on screen; a failed "seen" does not bring the dot back', () async {
      final s = Server([line('1', 'bite')]);
      final n = notifier(s);
      addTearDown(n.dispose);
      await wait();
      s.failList = true;
      await n.load();
      expect(n.state.items.length, 1);
      final bad = Server([line('1', 'bite')]);
      final m = notifier(bad);
      addTearDown(m.dispose);
      await wait();
      final service = ActivityService(client: MockClient((_) async => http.Response('x', 500)), tokenProvider: () => 't');
      expect(service.markSeen(), throwsStateError);
      await m.markSeen();
      expect(m.state.unread, 0);
    });
  });

  group('the dot on the bell', () {
    ProviderContainer container({bool whatsNew = false, ActivityData data = const ActivityData()}) {
      final c = ProviderContainer(overrides: [
        whatsNewProvider.overrideWith((ref) => WhatsNewNotifier(currentUserId: () => null, userIdChanges: const Stream.empty())..state = whatsNew),
        activityProvider.overrideWith((ref) => ActivityNotifier(currentUserId: () => null, userIdChanges: const Stream.empty())..state = data),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('off with nothing new', () => expect(container().read(bellDotProvider), isFalse));
    test('on for an unread What\'s new', () => expect(container(whatsNew: true).read(bellDotProvider), isTrue));
    test('on for a bite or reaction not yet seen, off once seen', () {
      expect(container(data: const ActivityData(unread: 1)).read(bellDotProvider), isTrue);
      expect(container(data: const ActivityData(unread: 0)).read(bellDotProvider), isFalse);
    });
  });

  group('Notifications screen', () {
    Future<(ProviderContainer, Server)> show(WidgetTester tester, Server s, {bool whatsNewUnread = false, FakeInbox? inbox}) async {
      tester.view.physicalSize = const Size(750, 2600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = ProviderContainer(overrides: [
        whatsNewProvider.overrideWith((ref) => WhatsNewNotifier(currentUserId: () => null, userIdChanges: const Stream.empty())..state = whatsNewUnread),
        activityProvider.overrideWith((ref) => notifier(s)),
        snapInboxProvider.overrideWith((ref) => inbox ?? FakeInbox(const [])),
      ]);
      addTearDown(c.dispose);
      c.read(activityProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: Builder(
            builder: (context) => CupertinoButton(
              child: const Text('open'),
              onPressed: () => Navigator.push(context, CupertinoPageRoute<void>(builder: (_) => const NotificationsScreen())),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return (c, s);
    }

    testWidgets('lists bites and reactions with the person, what they did and a new mark, then clears the dot', (tester) async {
      final s = Server([line('a', 'bite', name: 'sam'), line('b', 'reaction', name: 'bea', emoji: '🔥', minutesAgo: 90), line('c', 'bite', name: 'old', seen: true, minutesAgo: 3000)]);
      final (c, _) = await show(tester, s);
      expect(find.text('sam sent you a bite'), findsOneWidget);
      expect(find.text('bea reacted to your bite'), findsOneWidget);
      expect(find.text('old sent you a bite'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.byKey(const ValueKey('activity_new_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity_new_b')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity_new_c')), findsNothing, reason: 'it was already seen');
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('2d'), findsOneWidget);
      // Opening counted as seeing them.
      expect(s.seenCalls, 1);
      expect(c.read(bellDotProvider), isFalse);
    });

    testWidgets('nothing yet: a plain line saying what will appear', (tester) async {
      await show(tester, Server([]));
      expect(find.byKey(const ValueKey('from_friends_empty')), findsOneWidget);
      expect(find.text('Bites and reactions from friends show up here.'), findsOneWidget);
    });

    testWidgets('messages and friend requests are never listed', (tester) async {
      final s = Server([line('m', 'message'), line('r', 'friend_request'), line('a', 'bite')]);
      await show(tester, s);
      expect(find.byKey(const ValueKey('activity_m')), findsNothing);
      expect(find.byKey(const ValueKey('activity_r')), findsNothing);
      expect(find.byKey(const ValueKey('activity_a')), findsOneWidget);
    });

    testWidgets('tapping a line goes back to the tabs on Friends', (tester) async {
      final (c, _) = await show(tester, Server([line('a', 'bite')]));
      expect(c.read(shellTabProvider), ShellTab.today);
      await tester.tap(find.byKey(const ValueKey('activity_a')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(c.read(shellTabProvider), ShellTab.friends);
      expect(find.byType(NotificationsScreen), findsNothing);
    });

    Future<void> tapLine(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(ValueKey('activity_$id')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('tapping a bite line opens that exact bite while it is still in the inbox', (tester) async {
      final inbox = FakeInbox([bite('s0', from: 'bea'), bite('s1', from: 'sam'), bite('s2', from: 'kim')]);
      final (c, _) = await show(tester, Server([line('a', 'bite', snapId: 's1')]), inbox: inbox);
      await tapLine(tester, 'a');
      final viewer = tester.widget<SnapViewerScreen>(find.byType(SnapViewerScreen));
      expect(viewer.snaps[viewer.startAt].id, 's1');
      expect(c.read(shellTabProvider), ShellTab.today, reason: 'stayed put; Friends was not opened');
      expect(inbox.loads, 0, reason: 'the inbox was already loaded');
    });

    testWidgets('an inbox not loaded yet is loaded first, then the bite opens', (tester) async {
      final inbox = FakeInbox(null, onLoad: [bite('s1')]);
      await show(tester, Server([line('a', 'bite', snapId: 's1')]), inbox: inbox);
      await tapLine(tester, 'a');
      expect(inbox.loads, 1);
      expect(find.byType(SnapViewerScreen), findsOneWidget);
    });

    testWidgets('a bite that has gone, a reaction, or an older server: Friends, as before', (tester) async {
      for (final (item, snaps) in [
        (line('a', 'bite', snapId: 'gone'), [bite('s1')]),
        (line('a', 'bite', snapId: 's1'), [bite('s1', hoursLeft: -1)]),
        (line('a', 'reaction', emoji: '🔥', snapId: 's1'), [bite('s1')]),
        (line('a', 'bite'), [bite('s1')]),
      ]) {
        final (c, _) = await show(tester, Server([item]), inbox: FakeInbox(snaps));
        await tester.tap(find.byKey(const ValueKey('activity_a')));
        await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
        expect(find.byType(SnapViewerScreen), findsNothing, reason: '$item');
        expect(c.read(shellTabProvider), ShellTab.friends, reason: '$item');
        c.dispose();
      }
    });

    testWidgets('What\'s new is still there below', (tester) async {
      await show(tester, Server([line('a', 'bite')]), whatsNewUnread: true);
      expect(find.byKey(const ValueKey('from_friends')), findsOneWidget);
      expect(find.byKey(const ValueKey('new_pill')), findsOneWidget);
    });

    testWidgets('in another language', (tester) async {
      AppStrings.active = 'es';
      await show(tester, Server([line('a', 'bite', name: 'sam')]));
      expect(find.text('sam te envió un bocado'), findsOneWidget);
    });
  });
}
