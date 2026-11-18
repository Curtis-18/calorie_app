import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/models/week_budget.dart';
import 'package:calorie_app/providers/budget_provider.dart';
import 'package:calorie_app/providers/notification_prefs_provider.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/services/budget_service.dart';
import 'package:calorie_app/services/notification_prefs_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/week_budget_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> weekJson({String mode = 'weekly', int allowance = 1900, int bank = -600, Map<String, dynamic>? nudge}) => {
      'mode': mode,
      'nudges': nudge != null,
      'week_start': '2026-11-16',
      'daily_target': 2000,
      'floor': 1500,
      'allowance_today': allowance,
      'bank': bank,
      'explanation': 'A recent day had a bit extra, so the plan for today is a little lower.',
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'date': '2026-11-${16 + i}',
            'base': 2000,
            'eaten': i == 0 ? 2600 : null,
            'state': i == 0 ? 'past_logged' : i == 1 ? 'today' : 'future',
            'allowance': i == 1 ? allowance : 2000,
          },
      ],
      'nudge': nudge,
    };

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class FakeBudgetService extends BudgetService {
  FakeBudgetService({this.week_, this.prefs_ = const BudgetPrefs(), this.saveError});

  WeekBudgetData? week_;
  BudgetPrefs? prefs_;
  String? saveError;
  final saved = <Map<String, Object?>>[];

  @override
  Future<WeekBudgetData?> week() async => week_;
  @override
  Future<BudgetPrefs?> prefs() async => prefs_;
  @override
  Future<String?> save(Map<String, Object?> changes) async {
    saved.add(changes);
    return saveError;
  }
}

void main() {
  group('models', () {
    test('the week answer is read', () {
      final w = WeekBudgetData.fromJson(weekJson(nudge: {'kind': 'spread', 'over_by': 400, 'days': 4, 'per_day': 100, 'message': 'hi'}))!;
      expect(w.weekly, isTrue);
      expect(w.allowanceToday, 1900);
      expect(w.days.map((d) => d.state).take(3), [BudgetDayState.pastLogged, BudgetDayState.today, BudgetDayState.future]);
      expect(w.nudge!.canSpread, isTrue);
      expect(w.nudge!.perDay, 100);
    });
    test('a damaged answer is null, not a crash', () {
      expect(WeekBudgetData.fromJson({'mode': 'weekly'}), isNull);
      expect(BudgetNudge.fromJson('x'), isNull);
      expect(BudgetNudge.fromJson({'kind': 'spread', 'message': ''}), isNull);
    });
    test('prefs and the weekend flex weights', () {
      final p = BudgetPrefs.fromJson({'mode': 'weekly', 'nudges': true, 'week_start_day': 6, 'weights': [1, 1, 1, 1, 1, 1, 1]});
      expect([p.weekly, p.nudges, p.weekStartDay, p.weekendFlex], [true, true, 6, true]);
      expect(BudgetPrefs.fromJson({}).weekendFlex, isFalse);
      for (final start in [0, 6]) {
        final w = weekendFlexWeights(start);
        expect(w.fold<double>(0, (a, b) => a + b), closeTo(7, 0.01));
        // Saturday and Sunday are the bigger days wherever the week starts.
        for (var i = 0; i < 7; i++) {
          expect(w[i], ((start + i) % 7) >= 5 ? 1.15 : 0.94);
        }
      }
    });
  });

  group('service', () {
    BudgetService svc(http.Response Function(http.Request) reply, [List<http.Request>? seen]) => BudgetService(
          client: MockClient((r) async {
            seen?.add(r);
            return reply(r);
          }),
          tokenProvider: () => 't',
          now: () => DateTime(2026, 11, 17, 9),
        );

    test('asks for the week on the device date', () async {
      final seen = <http.Request>[];
      final w = await svc((_) => http.Response(jsonEncode(weekJson()), 200), seen).week();
      expect(w!.allowanceToday, 1900);
      expect(seen.single.url.queryParameters['date'], '2026-11-17');
    });
    test('reads never throw', () async {
      expect(await svc((_) => http.Response('x', 500)).week(), isNull);
      expect(await svc((_) => http.Response('x', 404)).prefs(), isNull);
      expect(await BudgetService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't').week(), isNull);
      expect(await BudgetService(tokenProvider: () => null).week(), isNull);
    });
    test('a save says why it failed', () async {
      expect(await svc((_) => http.Response('{}', 200)).save({'mode': 'weekly'}), isNull);
      expect(await svc((_) => http.Response(jsonEncode({'detail': 'Keep every day within 15% of normal.'}), 422)).save({}), contains('15%'));
      expect(await svc((_) => http.Response('x', 500)).save({}), contains("Couldn't save"));
      expect(await BudgetService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't').save({}), contains("Couldn't reach"));
    });
  });

  group('provider', () {
    late StreamController<String?> auth;
    setUp(() => auth = StreamController<String?>.broadcast());
    tearDown(() => auth.close());

    BudgetNotifier build(FakeBudgetService s) {
      final n = BudgetNotifier(service: s, currentUserId: () => 'u', userIdChanges: auth.stream);
      addTearDown(n.dispose);
      return n;
    }

    Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 30));

    test('weekly only applies when it is on and the server answered', () async {
      final service = FakeBudgetService(week_: WeekBudgetData.fromJson(weekJson()), prefs_: const BudgetPrefs(weekly: true));
      final n = build(service);
      await wait();
      expect(n.state.weekly, isTrue);

      final off = build(FakeBudgetService(week_: WeekBudgetData.fromJson(weekJson(mode: 'daily')), prefs_: const BudgetPrefs()));
      await wait();
      expect(off.state.weekly, isFalse);

      final noAnswer = build(FakeBudgetService(week_: null, prefs_: const BudgetPrefs(weekly: true)));
      await wait();
      expect(noAnswer.state.weekly, isFalse); // never a broken ring
    });

    test('a failed refresh keeps the last good answer', () async {
      final service = FakeBudgetService(week_: WeekBudgetData.fromJson(weekJson()), prefs_: const BudgetPrefs(weekly: true));
      final n = build(service);
      await wait();
      service.week_ = null;
      await n.refresh();
      expect(n.state.week!.allowanceToday, 1900);
    });

    test('spread turns weekly on; not now declines this week only', () async {
      final service = FakeBudgetService(week_: WeekBudgetData.fromJson(weekJson()), prefs_: const BudgetPrefs());
      final n = build(service);
      await wait();
      await n.spread();
      await n.dismissNudge();
      expect(service.saved, [
        {'mode': 'weekly'},
        {'dismiss_week': '2026-11-16'},
      ]);
    });

    test('a failed save returns its message and changes nothing', () async {
      final service = FakeBudgetService(saveError: 'nope');
      final n = build(service);
      await wait();
      expect(await n.update({'mode': 'weekly'}), 'nope');
    });

    test('another person signing in starts clean', () async {
      final n = build(FakeBudgetService(week_: WeekBudgetData.fromJson(weekJson()), prefs_: const BudgetPrefs(weekly: true)));
      await wait();
      auth.add(null);
      await wait();
      expect(n.state.week, isNull);
    });
  });

  group('widgets', () {
    Widget host(Widget child) => CupertinoApp(theme: AppTheme.cupertino, home: CupertinoPageScaffold(child: SafeArea(child: child)));

    testWidgets('the strip shows today’s plan and opens the whole week', (tester) async {
      tester.view.physicalSize = const Size(750, 1500);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(WeekStrip(week: WeekBudgetData.fromJson(weekJson())!)));
      expect(find.text("Today's plan: 1,900 kcal"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('week_strip')));
      await settle(tester);
      expect(find.byKey(const ValueKey('week_sheet')), findsOneWidget);
      expect(find.textContaining('a little lower'), findsOneWidget);
      expect(find.text('2,600 of 2,000'), findsOneWidget); // a bigger day is shown plainly
      expect(find.text('Not logged'), findsNothing);
    });

    testWidgets('the nudge card has two buttons when it can help, one when it cannot', (tester) async {
      var spread = 0, dismissed = 0;
      await tester.pumpWidget(host(BudgetNudgeCard(
        nudge: const BudgetNudge(canSpread: true, message: "You're about 400 over today.", perDay: 100, days: 4),
        onSpread: () => spread++,
        onDismiss: () => dismissed++,
      )));
      await tester.tap(find.byKey(const ValueKey('nudge_spread')));
      await tester.tap(find.byKey(const ValueKey('nudge_dismiss')));
      expect([spread, dismissed], [1, 1]);
      expect(find.text('Not now'), findsOneWidget);

      await tester.pumpWidget(host(BudgetNudgeCard(
        nudge: const BudgetNudge(canSpread: false, message: 'Today was a bigger one, and that is fine.'),
        onSpread: () {},
        onDismiss: () {},
      )));
      await tester.pump();
      expect(find.byKey(const ValueKey('nudge_spread')), findsNothing);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('settings', () {
    Future<FakeBudgetService> open(WidgetTester tester, {BudgetPrefs prefs = const BudgetPrefs(), String? saveError}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(750, 3000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final service = FakeBudgetService(week_: WeekBudgetData.fromJson(weekJson()), prefs_: prefs, saveError: saveError);
      final notifications = MockClient((_) async => http.Response('{}', 200));
      final container = ProviderContainer(overrides: [
        budgetProvider.overrideWith((ref) => BudgetNotifier(service: service, currentUserId: () => 'u', userIdChanges: const Stream.empty())),
        notificationPrefsProvider.overrideWith(
          (ref) => NotificationPrefsNotifier(NotificationPrefsService(client: notifications, tokenProvider: () => 't')),
        ),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(theme: AppTheme.cupertino, home: const SettingsView(profile: null)),
      ));
      await settle(tester);
      return service;
    }

    Future<void> flip(WidgetTester tester, String key) async {
      final toggle = find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(CupertinoSwitch));
      await tester.ensureVisible(toggle);
      await settle(tester);
      await tester.tap(toggle);
      await settle(tester);
    }

    testWidgets('the flexible target is off until chosen', (tester) async {
      final service = await open(tester);
      await flip(tester, 'toggle_weekly_budget');
      expect(service.saved.single, {'mode': 'weekly'});
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('weekend flex sends seven weights and turns weekly on', (tester) async {
      final service = await open(tester);
      await flip(tester, 'toggle_weekend_flex');
      final sent = service.saved.single;
      expect(sent['mode'], 'weekly');
      expect((sent['weights'] as List).length, 7);
      expect(sent['weights'], weekendFlexWeights(0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('gentle nudges are their own switch', (tester) async {
      final service = await open(tester);
      await flip(tester, 'toggle_budget_nudges');
      expect(service.saved.single, {'nudges': true});
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a refused change explains itself', (tester) async {
      await open(tester, saveError: 'Keep every day within 15% of normal.');
      await flip(tester, 'toggle_weekend_flex');
      expect(find.textContaining('within 15%'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
