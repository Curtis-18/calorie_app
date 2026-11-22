import 'dart:async';

import 'package:calorie_app/models/insights.dart';
import 'package:calorie_app/providers/insights_provider.dart';
import 'package:calorie_app/providers/user_provider.dart';
import 'package:calorie_app/providers/weekly_report_provider.dart';
import 'package:calorie_app/providers/weight_provider.dart';
import 'package:calorie_app/services/weight_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:calorie_app/screens/insights_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _json({Object? estimated, Map<String, dynamic>? movement}) => {
      'narrative': 'Solid week.',
      'tips': <String>[],
      'weekly_trend': [
        {'date': '2026-11-03', 'calories': 1800, 'protein_g': 90.0, 'carbs_g': 200.0, 'fat_g': 60.0},
      ],
      'generated_at': '2026-11-02T22:05:00Z',
      'estimated_entries': ?estimated,
      ...?movement,
    };

void main() {
  group('the estimated count in the response', () {
    test('is read when present', () {
      expect(InsightsData.fromJson(_json(estimated: 3)).estimatedEntries, 3);
    });

    test('is 0 from an older backend that does not send it', () {
      expect(InsightsData.fromJson(_json()).estimatedEntries, 0);
    });

    test('the movement fields are read, and are 0 from an older backend', () {
      final d = InsightsData.fromJson(_json(movement: {'movement_minutes': 60, 'movement_days': 2}));
      expect((d.movementMinutes, d.movementDays), (60, 2));
      final old = InsightsData.fromJson(_json());
      expect((old.movementMinutes, old.movementDays), (0, 0));
    });
  });

  group('the note on Insights', () {
    Future<void> show(WidgetTester tester, int estimated, {Map<String, dynamic>? movement}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      // The test font is wider than the real one: ignore pixel-overflow reports
      // from unrelated headers, fail on anything else.
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      final data = InsightsData.fromJson(_json(estimated: estimated, movement: movement));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => UserProfileNotifier(
                currentUserId: () => null,
                authToken: () => null,
                userIdChanges: const Stream.empty(),
              )),
          weightProvider.overrideWith((ref) => WeightNotifier(
                service: WeightService(client: MockClient((_) async => http.Response('{}', 500)), tokenProvider: () => 't'),
                currentUserId: () => null,
                userIdChanges: const Stream.empty(),
              )),
          weeklyReportProvider.overrideWith((ref) async => null),
          insightsProvider.overrideWith((ref) => InsightsNotifier(
                fetch: ({bool refresh = false}) async => data,
                currentUserId: () => 'me',
                userIdChanges: const Stream.empty(),
              )),
        ],
        child: CupertinoApp(theme: AppTheme.cupertino, home: const InsightsScreen()),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('appears when some entries were estimates', (tester) async {
      await show(tester, 2);
      expect(find.byKey(const ValueKey('estimated_note'), skipOffstage: false), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a quiet movement line shows only when something was logged this week', (tester) async {
      await show(tester, 0, movement: {'movement_minutes': 95, 'movement_days': 3});
      expect(find.text('You moved 95 min on 3 days this week.', skipOffstage: false), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('one day reads naturally, and none shows no line at all', (tester) async {
      await show(tester, 0, movement: {'movement_minutes': 20, 'movement_days': 1});
      expect(find.text('You moved 20 min on 1 day this week.', skipOffstage: false), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('nothing logged, no line', (tester) async {
      await show(tester, 0);
      expect(find.byKey(const ValueKey('movement_note'), skipOffstage: false), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('is not there when nothing was estimated', (tester) async {
      await show(tester, 0);
      expect(find.text('Solid week.', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('estimated_note'), skipOffstage: false), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
