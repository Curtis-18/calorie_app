import 'package:calorie_app/models/body_input.dart';
import 'package:calorie_app/models/profile_copy.dart';
import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/onboarding/plan_ready_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plain-language copy', () {
    test('every answer has a human title and a one-line explanation', () {
      for (final a in ActivityLevel.values) {
        expect(a.title, isNotEmpty);
        expect(a.blurb, endsWith('.'));
        expect(a.title, isNot(contains('_')));
        expect(a.title, isNot(equals(a.name)), reason: 'not the raw enum name');
      }
      for (final g in Goal.values) {
        expect(g.title, isNot(equals(g.name)));
        expect(g.blurb, isNotEmpty);
      }
      expect(Gender.female.title, 'Female');
    });

    test('the confusing words are gone', () {
      final all = [
        for (final a in ActivityLevel.values) '${a.title} ${a.blurb}',
        for (final g in Goal.values) '${g.title} ${g.blurb}',
      ].join(' ').toLowerCase();
      for (final jargon in ['sedentary', 'maintain', 'bmr', 'tdee', 'deficit', 'surplus']) {
        expect(all, isNot(contains(jargon)));
      }
    });
  });

  group('height', () {
    test('cm: plausible values, comma decimals, nothing else', () {
      expect(parseHeightCm(HeightUnit.cm, '172'), 172);
      expect(parseHeightCm(HeightUnit.cm, ' 172,5 '), 172.5);
      for (final bad in ['', 'abc', '99', '251', '-170', 'NaN', 'Infinity']) {
        expect(parseHeightCm(HeightUnit.cm, bad), isNull, reason: bad);
      }
    });

    test('ft and in: inches optional, but 12 or more is not inches', () {
      expect(parseHeightCm(HeightUnit.ftIn, '5', inches: '9'), closeTo(175.26, 0.01));
      expect(parseHeightCm(HeightUnit.ftIn, '6'), closeTo(182.88, 0.01));
      expect(parseHeightCm(HeightUnit.ftIn, '5', inches: '11,5'), closeTo(181.61, 0.01));
      expect(parseHeightCm(HeightUnit.ftIn, '5', inches: '12'), isNull);
      expect(parseHeightCm(HeightUnit.ftIn, '5', inches: '-1'), isNull);
      expect(parseHeightCm(HeightUnit.ftIn, '2'), isNull);
      expect(parseHeightCm(HeightUnit.ftIn, '9'), isNull);
    });

    test('whatever passes here is accepted by the server (3 to 8 whole feet)', () {
      for (var cm = minHeightCm; cm <= maxHeightCm; cm += 0.5) {
        final (feet, _) = feetAndInches(cm);
        expect(feet, inInclusiveRange(3, 8), reason: '$cm cm');
      }
    });

    test('cm to feet and inches rounds sensibly and never shows 12 in', () {
      expect(feetAndInches(175.26), (5, 9.0));
      expect(feetAndInches(182.88), (6, 0.0));
      expect(feetAndInches(182.85), (6, 0.0), reason: '11.99 in rolls up to the next foot');
    });

    test('default units by country', () {
      expect(usesImperialUnits('US'), isTrue);
      expect(usesImperialUnits('us'), isTrue);
      expect(usesImperialUnits('KE'), isFalse);
      expect(usesImperialUnits('GB'), isFalse);
      expect(usesImperialUnits(null), isFalse);
    });
  });

  group('plan ready', () {
    final profile = UserProfile(
      weightKg: 70,
      heightCm: 175,
      dateOfBirth: DateTime(1995, 5, 5),
      gender: Gender.male,
      activityLevel: ActivityLevel.light,
      goal: Goal.lose,
      calorieTarget: 2065,
      proteinTargetG: 140,
      carbsTargetG: 230,
      fatTargetG: 65,
    );

    Future<void> pump(WidgetTester tester, {String? notice, VoidCallback? onDone}) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        CupertinoApp(
          theme: AppTheme.cupertino,
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: PlanReady(profile: profile, maintenanceNotice: notice, onDone: onDone ?? () {}),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the calories and macros in plain words', (tester) async {
      await pump(tester);
      expect(find.text('Your plan is ready'), findsOneWidget);
      expect(find.text('2,065'), findsOneWidget);
      expect(find.text('calories a day'), findsOneWidget);
      expect(find.text('140g'), findsOneWidget);
      expect(find.text('230g'), findsOneWidget);
      expect(find.text('65g'), findsOneWidget);
      expect(find.textContaining('starting estimate'), findsOneWidget);
      expect(find.textContaining('steady at'), findsNothing);
    });

    testWidgets('explains a weight-loss goal that landed on staying the same', (tester) async {
      var done = 0;
      await pump(tester, notice: 'your plan keeps you steady at 1500 calories', onDone: () => done++);
      expect(find.textContaining('steady at 1500 calories'), findsOneWidget);
      await tester.tap(find.text("Let's go"));
      expect(done, 1);
    });
  });
}
