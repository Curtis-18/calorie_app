import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/food_item.dart';
import 'package:calorie_app/screens/photo_review_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromApiJson reads the matched food; an old backend leaves it null', () {
    final f = DetectedFood.fromApiJson({
      'name': 'rice',
      'estimated_grams': 150,
      'matched': true,
      'matched_description': 'Rice, white, cooked',
      'matched_fdc_id': 7,
      'calories_per_100g': 130,
    });
    expect(f.matchedDescription, 'Rice, white, cooked');
    expect(f.matchedFdcId, 7);

    final old = DetectedFood.fromApiJson({'name': 'rice', 'estimated_grams': 150, 'matched': true});
    expect(old.matchedDescription, isNull);
  });

  test('applyMatch swaps the nutrition but keeps name and grams', () {
    final f = DetectedFood(name: 'rice', estimatedGrams: 150, caloriesPer100g: 380, matched: true);
    f.applyMatch(FoodItem(
      fdcId: 9,
      description: 'Rice, white, cooked',
      caloriesPer100g: 130,
      proteinPer100g: 2.7,
      carbsPer100g: 28,
      fatPer100g: 0.3,
    ));
    expect(f.name, 'rice');
    expect(f.estimatedGrams, 150);
    expect(f.caloriesPer100g, 130);
    expect(f.matchedDescription, 'Rice, white, cooked');
    expect(f.matchedFdcId, 9);
    expect(f.estimatedCalories, 195);
  });

  testWidgets('review shows the match, offers Change, and saves an edited name',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final items = [
      DetectedFood(
        name: 'rice',
        estimatedGrams: 150,
        caloriesPer100g: 130,
        proteinPer100g: 2.7,
        carbsPer100g: 28,
        fatPer100g: 0.3,
        matched: true,
        matchedDescription: 'Rice pudding, branded',
      ),
    ];
    List<FoodEntry>? saved;
    await tester.pumpWidget(CupertinoApp(
      home: Builder(
        builder: (context) => CupertinoButton(
          onPressed: () async => saved = await Navigator.push<List<FoodEntry>>(
            context,
            CupertinoPageRoute(
              builder: (_) => PhotoReviewScreen(items: items, mealType: MealType.lunch),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Matched: Rice pudding, branded'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField).first, 'white rice');
    await tester.tap(find.text('Add 1 item'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(saved!.single.name, 'white rice');
    expect(saved!.single.calories, 195);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
