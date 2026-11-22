import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/insights.dart';
import 'package:calorie_app/providers/insights_provider.dart';
import 'package:calorie_app/providers/shell_provider.dart';
import 'package:calorie_app/providers/user_provider.dart';
import 'package:calorie_app/providers/weekly_report_provider.dart';
import 'package:calorie_app/providers/weight_provider.dart';
import 'package:calorie_app/screens/insights_screen.dart';
import 'package:calorie_app/screens/main_shell.dart';
import 'package:calorie_app/services/weight_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/insights_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> json({Object? tips}) => {
      'narrative': 'Solid week.',
      'tips': ?tips,
      'weekly_trend': [
        {'date': '2026-11-03', 'calories': 1800, 'protein_g': 90.0, 'carbs_g': 200.0, 'fat_g': 60.0},
      ],
      'generated_at': '2026-11-02T22:05:00Z',
    };

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the tabs', () {
    test('Workouts is where Insights was, and Insights is not a tab', () {
      expect(ShellTab.values.map((t) => t.name), ['today', 'workouts', 'friends', 'recipes', 'profile']);
      expect(ShellTab.workouts.index, 1);
    });
  });

  group('tips are gone', () {
    test('a server that still sends tips, or none, is read the same', () {
      expect(InsightsData.fromJson(json()).narrative, 'Solid week.');
      expect(InsightsData.fromJson(json(tips: ['a', 'b'])).narrative, 'Solid week.');
      expect(InsightsData.fromJson(json(tips: <String>[])).weeklyTrend.length, 1);
    });
  });

  group('Insights as a page on top', () {
    Future<void> show(WidgetTester tester, {bool pushed = true, Object? tips}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      final data = InsightsData.fromJson(json(tips: tips));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => UserProfileNotifier(currentUserId: () => null, authToken: () => null, userIdChanges: const Stream.empty())),
          weightProvider.overrideWith((ref) => WeightNotifier(
                service: WeightService(client: MockClient((_) async => http.Response('{}', 500)), tokenProvider: () => 't'),
                currentUserId: () => null,
                userIdChanges: const Stream.empty(),
              )),
          weeklyReportProvider.overrideWith((ref) async => null),
          insightsProvider.overrideWith((ref) => InsightsNotifier(fetch: ({bool refresh = false}) async => data, currentUserId: () => 'me', userIdChanges: const Stream.empty())),
        ],
        child: CupertinoApp(
          theme: AppTheme.cupertino,
          home: pushed
              ? Builder(builder: (context) => CupertinoButton(child: const Text('open'), onPressed: () => openInsights(context)))
              : const InsightsScreen(),
        ),
      ));
      if (pushed) await tester.tap(find.text('open'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('shows the narrative and the week, and no Tips even if the server sent some', (tester) async {
      await show(tester, tips: ['Drink water', 'Eat protein']);
      expect(find.text('Solid week.', skipOffstage: false), findsOneWidget);
      expect(find.text('TIPS', skipOffstage: false), findsNothing);
      expect(find.text('Drink water', skipOffstage: false), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('has a back arrow when opened from Today or Profile, and it goes back', (tester) async {
      await show(tester);
      expect(find.byKey(const ValueKey('page_back')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('page_back')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.byType(InsightsScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('has no back arrow when it is the page itself', (tester) async {
      await show(tester, pushed: false);
      expect(find.byKey(const ValueKey('page_back')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('the way in', () {
    testWidgets('the row on Today says Insights and opens it', (tester) async {
      var opened = 0;
      await tester.pumpWidget(CupertinoApp(theme: AppTheme.cupertino, home: CupertinoPageScaffold(child: Center(child: InsightsRow(onTap: () => opened++)))));
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Your week at a glance'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('insights_row')));
      expect(opened, 1);
    });

    test('the tour points at the Workouts tab, not at Insights', () {
      expect(MainShell.workoutsTabKey, isA<GlobalKey>());
      AppStrings.active = 'es';
      expect(tr('Move your way'), isNot('Move your way'));
    });
  });
}
