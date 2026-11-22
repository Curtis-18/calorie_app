import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/providers/shell_provider.dart';
import 'package:calorie_app/screens/workouts_screen.dart';
import 'package:calorie_app/services/tour_service.dart';
import 'package:calorie_app/widgets/app_tour.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workouts_screen_test.dart' show Server, app, containerFor, ignoreOverflow, settle;

List<TourStep> steps() => workoutsTourSteps(
      weekKey: GlobalKey(),
      plateKey: GlobalKey(),
      feelingsKey: GlobalKey(),
      bitesKey: GlobalKey(),
      libraryKey: GlobalKey(),
      planKey: GlobalKey(),
      logKey: GlobalKey(),
      helpKey: GlobalKey(),
    );

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the steps', () {
    test('go down the page in order, then the two corner buttons', () {
      expect(steps().map((s) => s.title), [
        'Your week, at a glance',
        'Fill your move plate',
        'Pick by how you feel',
        'Tiny bites, big wins',
        'Find your fit',
        'Your calories, your call',
        'Did something else? Count it',
        'Need a recap?',
      ]);
    });

    test('everything inside the page scrolls into view; the corner buttons are round', () {
      final all = steps();
      expect(all.take(6).every((s) => s.scrollIntoView), isTrue);
      expect(all.skip(6).every((s) => s.shape == TourShape.circle), isTrue);
    });

    test('are playful but never about burning, earning or making up for food', () {
      final words = [for (final s in steps()) '${s.title} ${s.body}'].join(' ').toLowerCase();
      for (final banned in ['burn', 'earn', 'cheat', 'punish', 'make up for', 'detox', 'guilt', 'lose weight']) {
        expect(words.contains(banned), isFalse, reason: banned);
      }
    });

    test('read in every language the app offers', () {
      for (final lang in ['es', 'fr', 'de', 'pt', 'it']) {
        for (final s in steps()) {
          expect(translationTables[lang]!.containsKey(s.title), isTrue, reason: '$lang: ${s.title}');
          expect(translationTables[lang]!.containsKey(s.body), isTrue, reason: '$lang: ${s.body}');
        }
      }
    });
  });

  group('on the Workouts tab', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(780, 1500); // a short phone, so the lower sections start below the fold
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    testWidgets('the first time the tab is opened the spotlight tour starts, and finishing it marks it seen', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({});
      phone(tester);
      final c = containerFor(Server());
      await tester.pumpWidget(app(c, const WorkoutsScreen()));
      await settle(tester);
      expect(find.text('Your week, at a glance'), findsNothing); // another tab is showing

      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await settle(tester, 20);
      expect(find.text('Your week, at a glance'), findsOneWidget);
      expect(find.text('1 / 8'), findsOneWidget);

      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      for (var i = 0; i < 7; i++) {
        // On a short phone even the tall week card must leave the buttons reachable.
        expect(tester.getCenter(find.text('Next')).dy, lessThan(screenHeight - 20), reason: 'step ${i + 1}');
        await tester.tap(find.text('Next'));
        await settle(tester, 10);
      }
      expect(tester.getCenter(find.text('Got it')).dy, lessThan(screenHeight));
      expect(find.text('Need a recap?'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await settle(tester, 10);
      expect(find.text('Need a recap?'), findsNothing);
      expect(await TourService.hasSeen(TourService.workouts), isTrue);
    });

    testWidgets('a section below the fold is scrolled to before it is spotlighted', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({});
      phone(tester);
      final c = containerFor(Server());
      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await tester.pumpWidget(app(c, const WorkoutsScreen()));
      await settle(tester, 20);

      // To the "Your calories, your call" step, which sits well below the first screen.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Next'));
        await settle(tester, 12);
      }
      expect(find.text('Your calories, your call'), findsOneWidget);
      final plan = tester.getRect(find.byKey(const ValueKey('plan_choice')));
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(plan.top, greaterThan(100));
      expect(plan.bottom, lessThan(screen.height - 100), reason: 'the card is clear of the tab bar');
    });

    testWidgets('someone who has seen it is not shown it again', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({'tour_seen_workouts_walkthrough': true});
      phone(tester);
      final c = containerFor(Server());
      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await tester.pumpWidget(app(c, const WorkoutsScreen()));
      await settle(tester, 20);
      expect(find.text('Your week, at a glance'), findsNothing);
    });

    testWidgets('the ? button shows it again, and Skip closes it', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({'tour_seen_workouts_walkthrough': true});
      phone(tester);
      await tester.pumpWidget(app(containerFor(Server()), const WorkoutsScreen()));
      await settle(tester, 10);
      await tester.tap(find.byKey(const ValueKey('workouts_help')));
      await settle(tester, 10);
      expect(find.text('Your week, at a glance'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await settle(tester, 10);
      expect(find.text('Your week, at a glance'), findsNothing);
    });

    testWidgets('steps whose parts are missing are skipped, not left pointing at nothing', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({'tour_seen_workouts_walkthrough': true});
      phone(tester);
      final s = Server()..failLibrary = true; // no feelings, bites or library on screen
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester, 10);
      await tester.tap(find.byKey(const ValueKey('workouts_help')));
      await settle(tester, 10);
      expect(find.text('1 / 5'), findsOneWidget); // week, plate, plan, +, ?
    });
  });
}
