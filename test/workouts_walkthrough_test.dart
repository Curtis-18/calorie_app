import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/providers/shell_provider.dart';
import 'package:calorie_app/providers/workouts_provider.dart';
import 'package:calorie_app/screens/workouts_screen.dart';
import 'package:calorie_app/screens/workouts_walkthrough.dart';
import 'package:calorie_app/services/tour_service.dart';
import 'package:calorie_app/services/workouts_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void ignoreOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

ProviderContainer container() {
  final service = WorkoutsService(client: MockClient((_) async => http.Response('no', 500)), tokenProvider: () => 't');
  final c = ProviderContainer(overrides: [
    workoutsServiceProvider.overrideWithValue(service),
    moveProvider.overrideWith((ref) => MoveNotifier(service: service, currentUserId: () => null, userIdChanges: const Stream.empty())),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget app(ProviderContainer c, Widget home) =>
    UncontrolledProviderScope(container: c, child: CupertinoApp(theme: AppTheme.cupertino, home: home));

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the pages', () {
    test('are playful but never about burning, earning or making up for food, and never a target', () {
      final words = [for (final p in walkthroughPages()) '${p.title} ${p.body}'].join(' ').toLowerCase();
      for (final banned in ['burn', 'earn', 'cheat', 'punish', 'make up for', 'detox', 'guilt', 'lose weight', 'must do']) {
        expect(words.contains(banned), isFalse, reason: banned);
      }
      expect(walkthroughPages().length, inInclusiveRange(5, 8));
      expect(walkthroughPages().where((p) => p.showPlate).length, 1);
    });

    test('every page reads in every language the app offers', () {
      final english = [for (final p in walkthroughPages()) ...[p.title, p.body]];
      for (final lang in ['es', 'fr', 'de', 'pt', 'it']) {
        for (final text in [...english, 'Let’s move!']) {
          expect(translationTables[lang]!.containsKey(text), isTrue, reason: '$lang: $text');
        }
        AppStrings.active = lang;
        expect(walkthroughPages().first.title, isNot(english.first), reason: lang);
      }
    });
  });

  group('the walkthrough', () {
    testWidgets('Next moves through every page and the last button closes it', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(builder: (context) => CupertinoButton(child: const Text('open'), onPressed: () => showWorkoutsWalkthrough(context))),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
      final total = walkthroughPages().length;
      expect(find.text('Hey, welcome to Workouts!'), findsOneWidget);
      for (var i = 1; i < total; i++) {
        await tester.tap(find.byKey(const ValueKey('walkthrough_next')));
        await settle(tester, 8);
      }
      expect(find.text('Weeks, not days'), findsOneWidget);
      expect(find.text('Let’s move!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('walkthrough_next')));
      await settle(tester, 10);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsNothing);
    });

    testWidgets('the move plate page shows the four kinds of movement', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(const CupertinoApp(home: WorkoutsWalkthrough()));
      await tester.tap(find.byKey(const ValueKey('walkthrough_next')));
      await settle(tester, 8);
      for (final e in ['💪', '🏃', '🧘', '💃']) {
        expect(find.text(e), findsOneWidget);
      }
    });

    testWidgets('Skip closes it from the first page, and is hidden on the last', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(builder: (context) => CupertinoButton(child: const Text('open'), onPressed: () => showWorkoutsWalkthrough(context))),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('walkthrough_skip')));
      await settle(tester, 10);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsNothing);
    });

    testWidgets('swiping works too', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(const CupertinoApp(home: WorkoutsWalkthrough()));
      await tester.drag(find.byKey(const ValueKey('walkthrough_pages')), const Offset(-600, 0));
      await settle(tester, 8);
      expect(find.text('Fill your move plate'), findsOneWidget);
    });
  });

  group('when it appears', () {
    testWidgets('the first time the Workouts tab is opened, once only', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = container();
      await tester.pumpWidget(app(c, const WorkoutsScreen()));
      await settle(tester);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsNothing); // another tab is showing

      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await settle(tester, 15);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsOneWidget);
      expect(await TourService.hasSeen(TourService.workouts), isTrue);

      await tester.tap(find.byKey(const ValueKey('walkthrough_skip')));
      await settle(tester, 12);
      c.read(shellTabProvider.notifier).state = ShellTab.today;
      await settle(tester);
      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await settle(tester, 15);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsNothing);
    });

    testWidgets('someone who has seen it is not shown it again', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({'tour_seen_workouts_walkthrough': true});
      final c = container();
      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await tester.pumpWidget(app(c, const WorkoutsScreen()));
      await settle(tester, 15);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsNothing);
    });

    testWidgets('already on the tab when it is built: shown once', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({});
      final c = container();
      c.read(shellTabProvider.notifier).state = ShellTab.workouts;
      await tester.pumpWidget(app(c, const WorkoutsScreen()));
      await settle(tester, 15);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsOneWidget);
    });

    testWidgets('the question-mark button shows it again whenever you like', (tester) async {
      ignoreOverflow();
      SharedPreferences.setMockInitialValues({'tour_seen_workouts_walkthrough': true});
      await tester.pumpWidget(app(container(), const WorkoutsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('workouts_help')));
      await settle(tester, 10);
      expect(find.byKey(const ValueKey('walkthrough_pages')), findsOneWidget);
    });
  });
}
