import 'dart:convert';

import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/providers/display_prefs_provider.dart';
import 'package:calorie_app/providers/notification_prefs_provider.dart';
import 'package:calorie_app/providers/shell_provider.dart';
import 'package:calorie_app/screens/dashboard_screen.dart';
import 'package:calorie_app/screens/main_shell.dart';
import 'package:calorie_app/screens/notification_settings_screen.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/services/notification_prefs_service.dart';
import 'package:calorie_app/services/tour_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/dashboard_header.dart';
import 'package:calorie_app/widgets/log_food_sheet.dart';
import 'package:calorie_app/widgets/page_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('today header', () {
    testWidgets('shows the day with arrows and no profile, bell or log-out buttons', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CupertinoPageScaffold(
          child: Column(children: [
            DashboardHeader(
              streakDays: 3,
              dateLabel: 'Yesterday',
              canGoNext: true,
              onPreviousDay: () => taps.add('previous'),
              onNextDay: () => taps.add('next'),
            ),
          ]),
        ),
      ));
      expect(find.byType(PageHeader), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_crop_circle), findsNothing);
      expect(find.byIcon(CupertinoIcons.bell), findsNothing);
      expect(find.byIcon(CupertinoIcons.square_arrow_right), findsNothing);

      await tester.tap(find.byKey(const ValueKey('day_previous')));
      await tester.tap(find.byKey(const ValueKey('day_next')));
      await settle(tester);
      expect(taps, ['previous', 'next']);
    });

    testWidgets('on today there is no next day to go to', (tester) async {
      var next = 0;
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CupertinoPageScaffold(
          child: Column(children: [
            DashboardHeader(streakDays: 0, dateLabel: 'Today', onNextDay: () => next++),
          ]),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('day_next')), warnIfMissed: false);
      await settle(tester);
      expect(next, 0);
    });
  });

  group('log food sheet', () {
    test('the meal follows the time of day', () {
      expect(mealForHour(7), MealType.breakfast);
      expect(mealForHour(12), MealType.lunch);
      expect(mealForHour(16), MealType.snack);
      expect(mealForHour(19), MealType.dinner);
      expect(mealForHour(23), MealType.snack);
      expect(mealForHour(2), MealType.snack);
    });

    Future<List<LogFoodChoice?>> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final results = <LogFoodChoice?>[];
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('open'),
                onPressed: () async => results.add(await showLogFoodSheet(context, initialMeal: MealType.lunch)),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
      return results;
    }

    testWidgets('one sheet picks the meal and the way to log', (tester) async {
      final results = await open(tester);
      expect(find.text('Log food'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meal_dinner')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('log_search')));
      await settle(tester);
      expect(results, [(meal: MealType.dinner, method: LogMethod.search)]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('taking a photo keeps the preselected meal', (tester) async {
      final results = await open(tester);
      await tester.tap(find.byKey(const ValueKey('log_photo')));
      await settle(tester);
      expect(results, [(meal: MealType.lunch, method: LogMethod.photo)]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('settings', () {
    Future<ProviderContainer> pump(WidgetTester tester, {Map<String, Object> saved = const {}}) async {
      SharedPreferences.setMockInitialValues(saved);
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'friend_snaps': true,
            'reactions': true,
            'streak_reminders': true,
            'milestones': true,
            'meal_nudge_hour': null,
            'quiet_start': 22,
            'quiet_end': 8,
            'utc_offset_minutes': 0,
            'paused_until': null,
            'daily_cap': 3,
          }),
          200));
      final container = ProviderContainer(overrides: [
        notificationPrefsProvider.overrideWith(
          (ref) => NotificationPrefsNotifier(NotificationPrefsService(client: client, tokenProvider: () => 't')),
        ),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(theme: AppTheme.cupertino, home: const SettingsView(profile: null)),
      ));
      await settle(tester);
      return container;
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await settle(tester);
      await tester.tap(target);
      await settle(tester);
    }

    testWidgets('the Today toggles are remembered on the device', (tester) async {
      final container = await pump(tester);
      expect(container.read(displayPrefsProvider).showNutrients, isTrue);

      final toggle = find.descendant(
        of: find.byKey(const ValueKey('toggle_nutrients')),
        matching: find.byType(CupertinoSwitch),
      );
      await tester.ensureVisible(toggle);
      await settle(tester);
      await tester.tap(toggle);
      await settle(tester);

      expect(container.read(displayPrefsProvider).showNutrients, isFalse);
      expect(container.read(displayPrefsProvider).showMacros, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DisplayPrefsNotifier.nutrientsKey), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('saved toggles are read back', (tester) async {
      final container = await pump(tester, saved: {DisplayPrefsNotifier.macrosKey: false});
      expect(container.read(displayPrefsProvider).showMacros, isFalse);
      expect(container.read(displayPrefsProvider).showNutrients, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('notifications open from settings', (tester) async {
      await pump(tester);
      await tapKey(tester, 'open_notifications');
      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('replaying the tutorial forgets it was seen and sends you to Today', (tester) async {
      final container = await pump(tester, saved: {'tour_seen_dashboard': true});
      container.read(shellTabProvider.notifier).state = ShellTab.profile;
      final before = container.read(tourReplayProvider);

      await tapKey(tester, 'replay_tour');

      expect(await TourService.hasSeen(TourService.dashboard), isFalse);
      expect(container.read(shellTabProvider), ShellTab.today);
      expect(container.read(tourReplayProvider), before + 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  test('the tutorial follows the layout: ring, the + button, then Insights, Friends and Profile', () {
    final ring = GlobalKey();
    final add = GlobalKey();
    final steps = dashboardTourSteps(ringKey: ring, addButtonKey: add);
    expect(steps.map((s) => s.targetKey), [
      ring,
      add,
      MainShell.insightsTabKey,
      MainShell.friendsTabKey,
      MainShell.profileTabKey,
    ]);
    expect(steps[1].body, contains('photo'));
    expect(steps.last.body, contains('Settings'));
  });
}
