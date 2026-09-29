import 'package:calorie_app/models/insights.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/theme/tracker_colors.dart';
import 'package:calorie_app/widgets/app_button.dart';
import 'package:calorie_app/widgets/app_card.dart';
import 'package:calorie_app/widgets/calorie_ring.dart';
import 'package:calorie_app/widgets/macro_breakdown.dart';
import 'package:calorie_app/widgets/pressable.dart';
import 'package:calorie_app/widgets/save_toast.dart';
import 'package:calorie_app/widgets/weekly_trend_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => CupertinoApp(
      theme: AppTheme.cupertino,
      home: CupertinoPageScaffold(child: Center(child: child)),
    );

void main() {
  testWidgets('AppButton fires onPressed and blocks taps when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(label: 'Save', onPressed: () => taps++)));

    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.pumpWidget(host(const AppButton(label: 'Save')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('Pressable scales on press and reports the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(Pressable(haptics: false, onTap: () => taps++, child: const Text('Tap me'))),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tap me')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('AppPill and SectionHeader render their content', (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPill(label: '12 day streak', color: TrackerColors.accentEnd),
            SectionHeader(label: 'Macros'),
          ],
        ),
      ),
    );

    expect(find.text('12 day streak'), findsOneWidget);
    expect(find.text('MACROS'), findsOneWidget);
  });

  testWidgets('CalorieRing shows remaining calories and consumed total', (tester) async {
    await tester.pumpWidget(
      host(const Padding(
        padding: EdgeInsets.all(24),
        child: CalorieRing(consumed: 1200, target: 2000),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('800'), findsOneWidget);
    expect(find.text('1200 / 2000 eaten'), findsOneWidget);
    expect(find.text('KCAL LEFT'), findsOneWidget);
  });

  testWidgets('CalorieRing never renders a negative remainder when over target', (tester) async {
    await tester.pumpWidget(
      host(const Padding(
        padding: EdgeInsets.all(24),
        child: CalorieRing(consumed: 2400, target: 2000),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('-400'), findsNothing);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2400 / 2000 eaten'), findsOneWidget);
  });

  testWidgets('MacroBreakdownCard renders each macro label and remaining value', (tester) async {
    await tester.pumpWidget(
      host(const Padding(
        padding: EdgeInsets.all(24),
        child: MacroBreakdownCard(
          protein: 90,
          proteinTarget: 150,
          carbs: 120,
          carbsTarget: 200,
          fat: 40,
          fatTarget: 60,
        ),
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('Fat'), findsOneWidget);
    expect(find.text('60g left today'), findsOneWidget);
    expect(find.text('80g left today'), findsOneWidget);
    expect(find.text('20g left today'), findsOneWidget);
  });

  testWidgets('WeeklyTrendChart paints one bar per day', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      host(
        Padding(
          padding: const EdgeInsets.all(24),
          child: WeeklyTrendChart(
            target: 2000,
            data: List.generate(
              7,
              (i) => DayTrend(
                date: now.subtract(Duration(days: 6 - i)),
                calories: 1800 + i * 60,
                proteinG: 90,
                carbsG: 200,
                fatG: 60,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('SaveToast walks from unsaved to saving to saved', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      host(SaveToast(state: SaveToastState.initial, onSave: () => saved++)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, 1);

    await tester.pumpWidget(host(const SaveToast(state: SaveToastState.loading)));
    await tester.pump();
    expect(find.text('Saving\u2026'), findsOneWidget);

    await tester.pumpWidget(host(const SaveToast(state: SaveToastState.success)));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
  });
}
