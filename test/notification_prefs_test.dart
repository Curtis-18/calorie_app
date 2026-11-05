import 'dart:convert';

import 'package:calorie_app/models/notification_prefs.dart';
import 'package:calorie_app/providers/notification_prefs_provider.dart';
import 'package:calorie_app/screens/notification_settings_screen.dart';
import 'package:calorie_app/services/notification_prefs_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _json({
  bool friendSnaps = true,
  bool reactions = true,
  int? nudge,
  int quietStart = 22,
  int quietEnd = 8,
  String? pausedUntil,
}) =>
    {
      'friend_snaps': friendSnaps,
      'reactions': reactions,
      'streak_reminders': true,
      'milestones': true,
      'meal_nudge_hour': nudge,
      'quiet_start': quietStart,
      'quiet_end': quietEnd,
      'utc_offset_minutes': 180,
      'paused_until': pausedUntil,
      'daily_cap': 3,
    };

NotificationPrefsService _service(MockClient client) =>
    NotificationPrefsService(client: client, tokenProvider: () => 'token', utcOffset: () => 180);

void main() {
  group('model', () {
    test('reads the server shape and falls back to the defaults', () {
      final p = NotificationPrefs.fromJson(_json(nudge: 13, pausedUntil: '2099-01-01T00:00:00Z'));
      expect((p.friendSnaps, p.mealNudgeHour, p.quietStart, p.quietEnd, p.dailyCap), (true, 13, 22, 8, 3));
      expect(p.isPausedAt(DateTime(2026, 11, 5)), isTrue);
      expect(NotificationPrefs.fromJson(const {}).friendSnaps, isTrue);
      expect(NotificationPrefs.fromJson(const {}).mealNudgeHour, isNull);
    });

    test('a pause in the past is not a pause', () {
      final p = NotificationPrefs.fromJson(_json(pausedUntil: '2020-01-01T00:00:00Z'));
      expect(p.isPausedAt(DateTime(2026, 11, 5)), isFalse);
      expect(const NotificationPrefs().isPausedAt(DateTime(2026, 11, 5)), isFalse);
    });

    test('copyWith can clear the meal reminder and the pause', () {
      final p = const NotificationPrefs(mealNudgeHour: 13).copyWith(mealNudgeHour: null);
      expect(p.mealNudgeHour, isNull);
      expect(const NotificationPrefs(mealNudgeHour: 13).copyWith(reactions: false).mealNudgeHour, 13);
    });

    test('labels', () {
      expect([0, 8, 12, 13, 22].map(hourLabel), ['12 AM', '8 AM', '12 PM', '1 PM', '10 PM']);
      expect(quietHoursLabel(22, 8), '10 PM to 8 AM');
      expect(quietHoursLabel(5, 5), 'Off');
    });

    test('the app does not claim push is live yet', () => expect(NotificationPrefs.pushLive, isFalse));
  });

  group('service', () {
    test('load reads the prefs', () async {
      late http.Request seen;
      final s = _service(MockClient((r) async {
        seen = r;
        return http.Response(jsonEncode(_json(reactions: false)), 200);
      }));
      final p = await s.load();
      expect(p.reactions, isFalse);
      expect(seen.url.path, '/notifications/prefs');
      expect(seen.headers['Authorization'], 'Bearer token');
    });

    test('update sends only the change plus the phone\'s time zone', () async {
      late Map<String, dynamic> sent;
      final s = _service(MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_json(friendSnaps: false)), 200);
      }));
      final p = await s.update({'friend_snaps': false});
      expect(sent, {'friend_snaps': false, 'utc_offset_minutes': 180});
      expect(p.friendSnaps, isFalse);
    });

    test('failures become readable messages', () async {
      expect(
        () => _service(MockClient((_) async => http.Response('boom', 500))).load(),
        throwsA(isA<NotificationPrefsException>().having((e) => e.message, 'message', contains('load'))),
      );
      expect(
        () => _service(MockClient((_) async => http.Response('{}', 422))).update({'quiet_start': 30}),
        throwsA(isA<NotificationPrefsException>().having((e) => e.message, 'message', contains('save'))),
      );
      expect(
        () => _service(MockClient((_) async => throw http.ClientException('down'))).load(),
        throwsA(isA<NotificationPrefsException>().having((e) => e.message, 'message', contains('reach'))),
      );
      expect(
        () => NotificationPrefsService(client: MockClient((_) async => http.Response('', 200)), tokenProvider: () => null).load(),
        throwsA(isA<NotificationPrefsException>().having((e) => e.message, 'message', contains('signed out'))),
      );
    });
  });

  group('screen', () {
    Future<List<Map<String, dynamic>>> pump(
      WidgetTester tester, {
      NotificationPrefs initial = const NotificationPrefs(),
      bool failSaves = false,
      bool failLoad = false,
    }) async {
      // Tall enough that every row is on screen (the page scrolls on a phone).
      tester.view.physicalSize = const Size(1179, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final saved = <Map<String, dynamic>>[];
      var current = initial;
      final client = MockClient((r) async {
        if (r.method == 'GET') {
          return failLoad ? http.Response('x', 500) : http.Response(jsonEncode(_json(
            friendSnaps: current.friendSnaps, reactions: current.reactions, nudge: current.mealNudgeHour,
            quietStart: current.quietStart, quietEnd: current.quietEnd,
            pausedUntil: current.pausedUntil?.toUtc().toIso8601String())), 200);
        }
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        saved.add(body);
        if (failSaves) return http.Response('x', 500);
        if (body.containsKey('friend_snaps')) current = current.copyWith(friendSnaps: body['friend_snaps'] as bool);
        if (body.containsKey('reactions')) current = current.copyWith(reactions: body['reactions'] as bool);
        if (body.containsKey('meal_nudge_hour')) {
          final h = body['meal_nudge_hour'] as int;
          current = current.copyWith(mealNudgeHour: h < 0 ? null : h);
        }
        if (body.containsKey('pause_days')) {
          final d = body['pause_days'] as int;
          current = current.copyWith(pausedUntil: d == 0 ? null : DateTime.now().add(Duration(days: d)));
        }
        return http.Response(jsonEncode(_json(
          friendSnaps: current.friendSnaps, reactions: current.reactions, nudge: current.mealNudgeHour,
          quietStart: current.quietStart, quietEnd: current.quietEnd,
          pausedUntil: current.pausedUntil?.toUtc().toIso8601String())), 200);
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          notificationPrefsProvider.overrideWith((ref) => NotificationPrefsNotifier(_service(client))),
        ],
        child: CupertinoApp(theme: AppTheme.cupertino, home: const NotificationSettingsScreen()),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return saved;
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('shows the promise and the honest "not live yet" note', (tester) async {
      await pump(tester);
      expect(find.textContaining('At most 3 a day'), findsOneWidget);
      expect(find.textContaining('never about your weight or calories'), findsOneWidget);
      expect(find.byKey(const ValueKey('push_not_live')), findsOneWidget);
      expect(find.text('Friend bites'), findsOneWidget);
      expect(find.byKey(const ValueKey('quiet_summary')), findsOneWidget);
      expect(find.textContaining('between 10 PM and 8 AM'), findsOneWidget);
    }, variant: ios);

    testWidgets('a switch changes at once and is saved', (tester) async {
      final saved = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('switch_reactions')));
      await tester.pump();
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_reactions'))).value, isFalse);
      await settle(tester);
      expect(saved.single['reactions'], false);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_reactions'))).value, isFalse);
    }, variant: ios);

    testWidgets('a failed save rolls the switch back and says so', (tester) async {
      await pump(tester, failSaves: true);
      await tester.tap(find.byKey(const ValueKey('switch_friend_snaps')));
      await settle(tester);
      expect(tester.widget<CupertinoSwitch>(find.byKey(const ValueKey('switch_friend_snaps'))).value, isTrue);
      expect(find.byKey(const ValueKey('save_error')), findsOneWidget);
    }, variant: ios);

    testWidgets('the meal reminder is off until chosen, then shows its time', (tester) async {
      final saved = await pump(tester);
      expect(find.byKey(const ValueKey('row_meal_nudge_time')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('switch_meal_nudge')));
      await settle(tester);
      expect(saved.single['meal_nudge_hour'], 13);
      expect(find.byKey(const ValueKey('row_meal_nudge_time')), findsOneWidget);
      expect(find.text('1 PM'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('switch_meal_nudge')));
      await settle(tester);
      expect(saved.last['meal_nudge_hour'], -1);
      expect(find.byKey(const ValueKey('row_meal_nudge_time')), findsNothing);
    }, variant: ios);

    testWidgets('pausing for a week, then resuming', (tester) async {
      final saved = await pump(tester);
      expect(find.byKey(const ValueKey('resume')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pause')));
      await settle(tester);
      expect(saved.single['pause_days'], 7);
      expect(find.byKey(const ValueKey('resume')), findsOneWidget);
      expect(find.byKey(const ValueKey('paused_note')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('resume')));
      await settle(tester);
      expect(saved.last['pause_days'], 0);
      expect(find.byKey(const ValueKey('pause')), findsOneWidget);
    }, variant: ios);

    testWidgets('a quiet hour can be picked', (tester) async {
      final saved = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('row_quiet_start')));
      await settle(tester);
      expect(find.text('Quiet from'), findsWidgets);
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -80)); // up two rows: 12 AM
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(saved.single['quiet_start'], isNot(22));
      expect(saved.single.containsKey('quiet_start'), isTrue);
    }, variant: ios);

    testWidgets('a load failure offers a retry', (tester) async {
      await pump(tester, failLoad: true);
      expect(find.textContaining("Couldn't load"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    }, variant: ios);
  });
}
