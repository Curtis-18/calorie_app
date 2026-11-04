import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/portion.dart';
import 'package:calorie_app/providers/user_provider.dart';
import 'package:calorie_app/screens/photo_review_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGrams', () {
    test('accepts plain, decimal, comma-decimal and "g" suffixed amounts', () {
      expect(parseGrams('150'), 150);
      expect(parseGrams(' 12.5 '), 12.5);
      expect(parseGrams('12,5'), 12.5, reason: 'comma decimals were silently ignored');
      expect(parseGrams('150 g'), 150);
      expect(parseGrams('150g'), 150);
    });

    test('rejects empty, zero, negative and absurd amounts instead of guessing', () {
      for (final bad in ['', '   ', 'abc', '0', '-50', '5001', '1e9', 'NaN']) {
        expect(parseGrams(bad), isNull, reason: bad);
      }
      expect(parseGrams('5000'), 5000);
    });
  });

  test('caloriesFor scales per-100 g values and rounds to the nearest kcal', () {
    expect(caloriesFor(130, 150), 195);
    expect(caloriesFor(54.9, 182), 100); // 99.9
    expect(caloriesFor(null, 100), 0);
    expect(caloriesFor(0, 330), 0); // diet soda
  });

  group('ProfileSaveException', () {
    test('shows the server message for a refused profile', () {
      final e = ProfileSaveException.fromResponse(
        422,
        '{"detail":"You need to be 18 or older to get calorie targets."}',
      );
      expect(e.message, 'You need to be 18 or older to get calorie targets.');
      expect('$e', e.message);
    });

    test('anything else is a generic, readable message', () {
      expect(ProfileSaveException.fromResponse(500, 'boom').message, contains("couldn't save"));
      expect(
        ProfileSaveException.fromResponse(422, '{"detail":[{"loc":["body"]}]}').message,
        contains("couldn't save"),
      );
    });
  });

  group('photo review', () {
    Future<List<FoodEntry>?> review(WidgetTester tester, List<DetectedFood> items) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<FoodEntry>? result;
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () async {
              result = await Navigator.push<List<FoodEntry>>(
                context,
                CupertinoPageRoute(builder: (_) => PhotoReviewScreen(items: items, mealType: MealType.lunch)),
              );
            },
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    DetectedFood food(String name, {double? kcal, bool matched = true}) => DetectedFood(
          name: name,
          estimatedGrams: 150,
          caloriesPer100g: kcal,
          proteinPer100g: matched ? 2.7 : null,
          carbsPer100g: matched ? 28 : null,
          fatPer100g: matched ? 0.3 : null,
          matched: matched,
        );

    testWidgets('unmatched foods are never saved as 0 kcal', (tester) async {
      await review(tester, [food('rice', kcal: 130), food('rice', kcal: 130), food('mystery sauce', matched: false)]);

      expect(find.text('No match · Find'), findsOneWidget);
      expect(find.textContaining("won't be saved"), findsOneWidget);
      expect(find.text('Add 2 items'), findsOneWidget, reason: 'the unmatched item is not counted');
    });

    testWidgets('saved entries are the matched ones, with unique ids', (tester) async {
      List<FoodEntry>? result;
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () async {
              result = await Navigator.push<List<FoodEntry>>(
                context,
                CupertinoPageRoute(
                  builder: (_) => PhotoReviewScreen(
                    items: [food('rice', kcal: 130), food('rice', kcal: 130), food('mystery', matched: false)],
                    mealType: MealType.lunch,
                  ),
                ),
              );
            },
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Edit the first portion with a comma decimal.
      await tester.enterText(find.byType(CupertinoTextField).at(1), '200,5'); // row 1: name, then grams
      await tester.pump();
      expect(find.text('~261 kcal'), findsOneWidget); // 130 x 2.005

      await tester.tap(find.text('Add 2 items'));
      await tester.pumpAndSettle();

      expect(result, hasLength(2));
      expect(result!.map((e) => e.calories), [261, 195]);
      expect(result!.every((e) => e.calories > 0), isTrue);
      expect(result!.map((e) => e.id).toSet(), hasLength(2), reason: 'same-name items need distinct ids');
    });

    testWidgets('nothing to save when no food matched', (tester) async {
      await review(tester, [food('mystery', matched: false)]);
      expect(find.text('Add 0 items'), findsOneWidget);
    });
  });
}
