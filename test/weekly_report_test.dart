import 'dart:convert';

import 'package:calorie_app/models/weekly_report.dart';
import 'package:calorie_app/services/report_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/weekly_report_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> json({int days = 5, int? protein = 3, bool enough = true, int needed = 0, List<Map<String, String>> patterns = const []}) => {
      'days_logged': days,
      'protein_goal_days': protein,
      'message': 'You logged $days of the last 7 days.',
      'enough_data': enough,
      'days_needed': needed,
      'patterns': patterns,
    };

void main() {
  test('the report is read, and junk is null', () {
    final r = WeeklyReport.fromJson(json(patterns: [{'id': 'weekend_higher', 'text': 'Weekends run higher.', 'tip': 'Try weekend flex.'}]))!;
    expect([r.daysLogged, r.proteinGoalDays, r.enoughData], [5, 3, true]);
    expect(r.patterns.single.id, 'weekend_higher');
    expect(WeeklyReport.fromJson('x'), isNull);
    expect(WeeklyReport.fromJson({'message': 'x'}), isNull);
    expect(WeeklyReport.fromJson(json(protein: null))!.proteinGoalDays, isNull);
  });

  group('service', () {
    test('asks on the device date and never throws', () async {
      final seen = <Uri>[];
      final svc = ReportService(
        client: MockClient((r) async {
          seen.add(r.url);
          return http.Response(jsonEncode(json()), 200);
        }),
        tokenProvider: () => 't',
        now: () => DateTime(2026, 11, 18, 8),
      );
      expect((await svc.weekly())!.daysLogged, 5);
      expect(seen.single.queryParameters['date'], '2026-11-18');

      expect(await ReportService(client: MockClient((_) async => http.Response('x', 500)), tokenProvider: () => 't').weekly(), isNull);
      expect(await ReportService(client: MockClient((_) async => throw http.ClientException('x')), tokenProvider: () => 't').weekly(), isNull);
      expect(await ReportService(tokenProvider: () => null).weekly(), isNull);
    });
  });

  group('card', () {
    Future<void> show(WidgetTester tester, WeeklyReport r) async {
      tester.view.physicalSize = const Size(750, 1500);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CupertinoPageScaffold(child: SafeArea(child: WeeklyReportCard(report: r))),
      ));
    }

    testWidgets('shows the days, the protein days and a pattern with its tip', (tester) async {
      await show(tester, WeeklyReport.fromJson(json(patterns: [{'id': 'weekend_higher', 'text': 'Weekends run higher.', 'tip': 'Try weekend flex.'}]))!);
      expect(find.text('5 of 7'), findsOneWidget);
      expect(find.text('days at your protein goal'), findsOneWidget);
      expect(find.text('Weekends run higher.'), findsOneWidget);
      expect(find.text('Try weekend flex.'), findsOneWidget);
      expect(find.byKey(const ValueKey('patterns_waiting')), findsNothing);
    });

    testWidgets('says patterns are coming when there is not enough history', (tester) async {
      await show(tester, WeeklyReport.fromJson(json(enough: false, needed: 9))!);
      expect(find.textContaining('around 9 more logged days'), findsOneWidget);
    });

    testWidgets('one protein day is singular, and no plan means no protein stat', (tester) async {
      await show(tester, WeeklyReport.fromJson(json(protein: 1))!);
      expect(find.text('day at your protein goal'), findsOneWidget);
      await show(tester, WeeklyReport.fromJson(json(protein: null))!);
      await tester.pump();
      expect(find.textContaining('protein goal'), findsNothing);
    });
  });
}
