import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/progress.dart';
import 'package:calorie_app/providers/progress_provider.dart';
import 'package:calorie_app/services/progress_service.dart';
import 'package:calorie_app/services/user_cache.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/game/celebrations.dart';
import 'package:calorie_app/widgets/game/header_chips.dart';
import 'package:calorie_app/widgets/game/progress_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _json({
  String date = '2026-11-02',
  int streak = 4,
  String tier = 'ember',
  int freezes = 1,
  bool loggedToday = true,
  int level = 3,
  int xp = 420,
  bool perfect = false,
  Set<String> unlocked = const {'first_bite'},
}) =>
    {
      'date': date,
      'streak': {
        'current': streak,
        'best': 9,
        'tier': tier,
        'freezes': freezes,
        'max_freezes': 2,
        'logged_today': loggedToday,
        'frozen_days': <String>[],
      },
      'level': {'level': level, 'xp': xp, 'level_xp': 300, 'next_level_xp': 600},
      'today': {'xp': 72, 'perfect_day': perfect, 'calories': 1900, 'target_low': 1800, 'target_high': 2200},
      'achievements': [
        for (final (id, goal) in [('first_bite', 1), ('snapshot', 1), ('protein_pro', 5), ('on_fire', 7)])
          {
            'id': id,
            'title': id,
            'description': 'desc $id',
            'unlocked': unlocked.contains(id),
            'unlocked_on': unlocked.contains(id) ? '2026-10-30' : null,
            'progress': unlocked.contains(id) ? goal : 2,
            'goal': goal,
          },
      ],
    };

ProgressData _data({
  bool perfect = false,
  int level = 3,
  Set<String> unlocked = const {'first_bite'},
  String date = '2026-11-02',
}) =>
    ProgressData.fromJson(_json(perfect: perfect, level: level, unlocked: unlocked, date: date));

void main() {
  group('model', () {
    test('parses everything and derives level progress', () {
      final p = _data();
      expect(p.streak.current, 4);
      expect(p.streak.tier, FlameTier.ember);
      expect(p.streak.atRisk, isFalse);
      expect(p.level.xpIntoLevel, 120);
      expect(p.level.xpForLevel, 300);
      expect(p.level.fraction, closeTo(0.4, 1e-9));
      expect(p.unlockedCount, 1);
      expect(p.achievements[2].fraction, closeTo(0.4, 1e-9));
    });

    test('unknown tier falls back to spark; tiers know what comes next', () {
      expect(FlameTier.fromApi('mystery'), FlameTier.spark);
      expect(FlameTier.ember.next, FlameTier.flame);
      expect(FlameTier.inferno.next, isNull);
    });

    test('a streak not yet logged today is at risk', () {
      final p = ProgressData.fromJson(_json(loggedToday: false));
      expect(p.streak.atRisk, isTrue);
    });
  });

  group('celebrations', () {
    test('first run sets a baseline instead of replaying old badges', () {
      final (events, ledger) = diffCelebrations(_data(perfect: true, unlocked: {'first_bite', 'snapshot'}), null);
      expect(events, isEmpty);
      expect(ledger.achievements, {'first_bite', 'snapshot'});
      expect(ledger.perfectDay, '2026-11-02');
    });

    test('new badge, level up and perfect day each celebrate once, in order', () {
      final (_, seen) = diffCelebrations(_data(), null);
      final next = _data(perfect: true, level: 4, unlocked: {'first_bite', 'snapshot'});

      final (events, ledger) = diffCelebrations(next, seen);
      expect(events.map((e) => e.runtimeType), [
        PerfectDayCelebration,
        AchievementCelebration,
        LevelUpCelebration,
      ]);
      expect((events[1] as AchievementCelebration).achievement.id, 'snapshot');
      expect((events[2] as LevelUpCelebration).level, 4);

      final (again, _) = diffCelebrations(next, ledger);
      expect(again, isEmpty, reason: 'no repeats on the next refresh');
    });

    test('dropping out of range and back the same day does not re-celebrate', () {
      final (_, seen) = diffCelebrations(_data(), null);
      final (_, afterPerfect) = diffCelebrations(_data(perfect: true), seen);
      final (_, afterDrop) = diffCelebrations(_data(perfect: false), afterPerfect);
      final (events, _) = diffCelebrations(_data(perfect: true), afterDrop);
      expect(events, isEmpty);

      final (tomorrow, _) = diffCelebrations(_data(perfect: true, date: '2026-11-03'), afterDrop);
      expect(tomorrow.single, isA<PerfectDayCelebration>());
    });

    test('ledger survives a JSON round trip', () {
      final (_, ledger) = diffCelebrations(_data(perfect: true, unlocked: {'first_bite', 'snapshot'}), null);
      final back = CelebrationLedger.fromJson(jsonDecode(jsonEncode(ledger.toJson())) as Map<String, dynamic>);
      expect(back.achievements, ledger.achievements);
      expect(back.level, ledger.level);
      expect(back.perfectDay, ledger.perfectDay);
    });
  });

  group('service', () {
    test("sends the device's date and parses the response", () async {
      late http.Request seen;
      final service = ProgressService(
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode(_json()), 200);
        }),
        tokenProvider: () => 'token',
        now: () => DateTime(2026, 11, 3, 0, 30),
      );
      final p = await service.fetch();
      expect(seen.url.path, '/progress');
      expect(seen.url.queryParameters['date'], '2026-11-03');
      expect(seen.headers['Authorization'], 'Bearer token');
      expect(p?.streak.current, 4);
    });

    test('failures return null rather than breaking the dashboard', () async {
      final down = ProgressService(
        client: MockClient((_) async => http.Response('', 502)),
        tokenProvider: () => 'token',
      );
      expect(await down.fetch(), isNull);
      final signedOut = ProgressService(
        client: MockClient((_) async => fail('must not call the API')),
        tokenProvider: () => null,
      );
      expect(await signedOut.fetch(), isNull);
    });
  });

  group('provider', () {
    late StreamController<String?> auth;

    setUp(() {
      UserCache.resetForTest();
      SharedPreferences.setMockInitialValues({});
      auth = StreamController<String?>.broadcast();
    });
    tearDown(() => auth.close());

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    test('emits celebrations only for what is new since the last refresh', () async {
      var current = _data();
      final n = ProgressNotifier(
        fetch: () async => current,
        currentUserId: () => 'user-a',
        userIdChanges: auth.stream,
        debounce: const Duration(milliseconds: 5),
      );
      final events = <Celebration>[];
      n.celebrations.listen(events.add);
      await settle();
      expect(n.state?.level.level, 3);
      expect(events, isEmpty, reason: 'first load is the baseline');

      current = _data(level: 4, unlocked: {'first_bite', 'snapshot'});
      n.refreshSoon();
      n.refreshSoon(); // coalesced
      await settle();
      expect(events.map((e) => e.runtimeType), [AchievementCelebration, LevelUpCelebration]);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProgressNotifier.ledgerKey('user-a')), contains('snapshot'));
      n.dispose();
    });

    test('clears on sign-out and keeps ledgers per user', () async {
      final n = ProgressNotifier(
        fetch: () async => _data(),
        currentUserId: () => 'user-a',
        userIdChanges: auth.stream,
      );
      await settle();
      expect(n.state, isNotNull);

      auth.add(null);
      await settle();
      expect(n.state, isNull);

      auth.add('user-b');
      await settle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ProgressNotifier.ledgerKey('user-a')), isTrue);
      expect(prefs.containsKey(ProgressNotifier.ledgerKey('user-b')), isTrue);
      n.dispose();
    });
  });

  group('widgets', () {
    Widget host(Widget child) => CupertinoApp(
          theme: AppTheme.cupertino,
          home: CupertinoPageScaffold(child: Center(child: child)),
        );

    testWidgets('flame pill shows days and freezes, and invites a first streak', (tester) async {
      await tester.pumpWidget(host(FlameStreakPill(streak: _data().streak)));
      expect(find.text('4 days'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.snow), findsOneWidget);

      final none = ProgressData.fromJson(_json(streak: 0, tier: 'spark', freezes: 0, loggedToday: false));
      await tester.pumpWidget(host(FlameStreakPill(streak: none.streak)));
      expect(find.text('Start a streak'), findsOneWidget);
    });

    testWidgets('level badge shows the level', (tester) async {
      await tester.pumpWidget(host(LevelBadge(level: _data().level)));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('streak, level and badges render together', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = _data();
      await tester.pumpWidget(host(SingleChildScrollView(
        child: Column(children: [
          StreakHeroCard(streak: p.streak),
          LevelCard(level: p.level, todayXp: p.today.xp),
          BadgeGrid(achievements: p.achievements),
        ]),
      )));
      await tester.pumpAndSettle();
      expect(find.text('4-day streak'), findsOneWidget);
      expect(find.text('3 more days to Flame'), findsOneWidget);
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('120 / 300 XP to level 4'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget); // protein_pro progress
    });

    testWidgets('badge celebration card shows and dismisses', (tester) async {
      final badge = _data(unlocked: {'snapshot'}).achievements[1];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('go'),
            onPressed: () => showCelebrationCard(context, AchievementCelebration(badge)),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('BADGE UNLOCKED'), findsOneWidget);
      expect(find.text('desc snapshot'), findsOneWidget);
      await tester.tap(find.text('Nice!'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('BADGE UNLOCKED'), findsNothing);
    });
  });
}
