import 'dart:convert';

import 'package:calorie_app/models/detected_food.dart';
import 'package:calorie_app/models/food_entry.dart';
import 'package:calorie_app/models/food_item.dart';
import 'package:calorie_app/models/nutrients.dart';
import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/nutrients_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const _spinach = {
  'fdc_id': 1,
  'description': 'Spinach, raw',
  'calories_per_100g': 23,
  'fiber_g_per_100g': 2.2,
  'sugar_g_per_100g': 0.42,
  'sodium_mg_per_100g': 79,
  'iron_mg_per_100g': 2.71,
  'calcium_mg_per_100g': null, // USDA has no value: unknown, not zero
};

FoodEntry _entry(String id, {Nutrients? nutrients}) => FoodEntry(
      id: id,
      name: id,
      calories: 100,
      mealType: MealType.lunch,
      source: FoodSource.manual,
      timestamp: DateTime(2026, 11, 14, 12),
      nutrients: nutrients,
    );

void main() {
  group('reading and scaling', () {
    test('a search result keeps only the nutrients USDA has', () {
      final item = FoodItem.fromApiJson(_spinach);
      expect(item.extrasPer100g, {'fiber_g': 2.2, 'sugar_g': 0.42, 'sodium_mg': 79.0, 'iron_mg': 2.71});
    });

    test('an older backend without the fields means no data, not zeros', () {
      final item = FoodItem.fromApiJson({'fdc_id': 1, 'description': 'Rice', 'calories_per_100g': 130});
      expect(item.extrasPer100g, isEmpty);
      expect(Nutrients.forPortion(item.extrasPer100g, 150), isNull);
    });

    test('amounts scale with the portion', () {
      final n = Nutrients.forPortion(FoodItem.fromApiJson(_spinach).extrasPer100g, 200)!;
      expect(n.amounts, {'fiber_g': 4.4, 'sugar_g': 0.84, 'sodium_mg': 158.0, 'iron_mg': 5.42});
      expect(n['calcium_mg'], isNull);
    });

    test('a photo item carries them, and a changed match replaces them', () {
      final food = DetectedFood.fromApiJson({..._spinach, 'name': 'spinach', 'estimated_grams': 50, 'matched': true});
      expect(food.estimatedNutrients!['iron_mg'], 1.36);

      food.applyMatch(FoodItem(fdcId: 2, description: 'Kale', caloriesPer100g: 35, extrasPer100g: const {'iron_mg': 1.6}));
      expect(food.estimatedNutrients!.amounts, {'iron_mg': 0.8});

      food.applyMatch(FoodItem(fdcId: 3, description: 'Mystery', caloriesPer100g: 10));
      expect(food.estimatedNutrients, isNull);
    });

    test('an entry round-trips through the device cache and reads the API shape', () {
      final entry = _entry('a', nutrients: const Nutrients({'iron_mg': 2.7}));
      final cached = FoodEntry.fromJson(jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>);
      expect(cached.nutrients!.amounts, {'iron_mg': 2.7});

      // An entry cached before nutrients existed still loads.
      expect(FoodEntry.fromJson(jsonDecode(jsonEncode(_entry('b').toJson())) as Map<String, dynamic>).nutrients, isNull);

      final fromApi = FoodEntry.fromApiJson({
        'id': 'c', 'name': 'x', 'calories': 1, 'meal_type': 'lunch', 'source': 'photo',
        'timestamp': '2026-11-14T12:00:00', 'nutrients': {'fiber_g': 3, 'zinc_mg': 9},
      });
      expect(fromApi.nutrients!.amounts, {'fiber_g': 3.0}); // unknown keys are ignored
      final none = FoodEntry.fromApiJson({
        'id': 'd', 'name': 'x', 'calories': 1, 'meal_type': 'lunch', 'source': 'photo',
        'timestamp': '2026-11-14T12:00:00', 'nutrients': null,
      });
      expect(none.nutrients, isNull);
    });

    test('scaling an entry scales its nutrients too', () {
      final doubled = _entry('a', nutrients: const Nutrients({'iron_mg': 2.7, 'fiber_g': 1.1})).scaled(2);
      expect(doubled.calories, 200);
      expect(doubled.nutrients!.amounts, {'iron_mg': 5.4, 'fiber_g': 2.2});
    });
  });

  group('targets', () {
    test('the profile reads them from /targets and keeps them in its cache', () {
      final profile = UserProfile.fromTargetsJson({
        'date_of_birth': '1990-01-01', 'sex': 'female', 'activity_level': 'moderate', 'goal': 'maintain',
        'height_cm': 165, 'weight_kg': 60, 'bmr': 1300, 'tdee': 2000, 'calorie_target': 2000, 'bmi': 22,
        'protein_g': 96, 'fat_g': 67, 'carbs_g': 254,
        'nutrient_targets': {'fiber_g': 28, 'sodium_limit_mg': 2300, 'iron_mg': 18, 'calcium_mg': 1000},
      })!;
      expect(profile.nutrientTargets!['iron_mg'], 18);
      final cached = UserProfile.fromJson(jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>);
      expect(cached.nutrientTargets, profile.nutrientTargets);
    });

    test('an older backend or cache without them is fine', () {
      final profile = UserProfile.fromTargetsJson({
        'date_of_birth': '1990-01-01', 'sex': 'male', 'activity_level': 'light', 'goal': 'lose',
        'height_cm': 180, 'weight_kg': 80, 'calorie_target': 2000,
      })!;
      expect(profile.nutrientTargets, isNull);
    });
  });

  group('the day summary', () {
    final targets = {'fiber_g': 28, 'sodium_limit_mg': 2300, 'iron_mg': 18, 'calcium_mg': 1000};

    test('adds up what is known and counts what it is based on', () {
      final s = NutrientSummary.of([
        const Nutrients({'fiber_g': 4, 'iron_mg': 2.5}),
        const Nutrients({'fiber_g': 6, 'sodium_mg': 300}),
        null, // an old or unmatched entry
      ], targets: targets);

      expect((s.foods, s.foodsWithData, s.isPartial), (3, 2, true));
      final byKey = {for (final t in s.totals) t.info.key: t};
      expect((byKey['fiber_g']!.amount, byKey['fiber_g']!.foodsWithData, byKey['fiber_g']!.target), (10.0, 2, 28));
      expect((byKey['sodium_mg']!.amount, byKey['sodium_mg']!.target), (300.0, 2300));
      expect(byKey['calcium_mg']!.foodsWithData, 0); // nobody had calcium data
      expect(byKey['sugar_g']!.target, isNull); // there is no sugar target
    });

    test('formatting', () {
      expect(formatNutrient(2.44, 'g'), '2.4 g');
      expect(formatNutrient(4, 'g'), '4 g');
      expect(formatNutrient(379.6, 'mg'), '380 mg');
    });
  });

  group('the View nutrients row', () {
    testWidgets('is one slim row, and tapping it opens the numbers in a sheet', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final summary = NutrientSummary.of(
        [const Nutrients({'fiber_g': 12, 'iron_mg': 6.5})],
        targets: {'fiber_g': 28, 'iron_mg': 18},
      );
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(child: NutrientsRow(summary: summary, onTap: () => showNutrientsSheet(context, summary))),
          ),
        ),
      ));
      expect(find.text('View nutrients'), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrient_fiber_g')), findsNothing, reason: 'the numbers stay hidden until opened');
      expect(tester.getSize(find.byKey(const ValueKey('nutrients_row'))).height, lessThan(80));

      await tester.tap(find.byKey(const ValueKey('nutrients_row')));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('NUTRIENTS'), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrient_fiber_g')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('nutrient_fiber_g'))).data, '12 g');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester, NutrientSummary summary) => tester.pumpWidget(CupertinoApp(
          theme: AppTheme.cupertino,
          home: CupertinoPageScaffold(child: Center(child: NutrientsCard(summary: summary))),
        ));

    String shown(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey('nutrient_$key'))).data!;

    testWidgets('shows totals against targets, and "No data" rather than 0 for an unknown nutrient', (tester) async {
      await pump(
        tester,
        NutrientSummary.of(
          [const Nutrients({'fiber_g': 12, 'sodium_mg': 900, 'iron_mg': 6.5, 'sugar_g': 20})],
          targets: {'fiber_g': 28, 'sodium_limit_mg': 2300, 'iron_mg': 18, 'calcium_mg': 1000},
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(shown(tester, 'fiber_g'), '12 g');
      expect(find.text(' / 28 g'), findsOneWidget);
      expect(find.text(' of 2300 mg limit'), findsOneWidget);
      expect(shown(tester, 'iron_mg'), '6.5 mg');
      expect(shown(tester, 'calcium_mg'), 'No data');
      // Every food has data, so no "based on" caveat; the disclaimer stays.
      final note = tester.widget<Text>(find.byKey(const ValueKey('nutrients_note'))).data!;
      expect(note, isNot(contains('Based on')));
      expect(note, contains('not medical advice'));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('says so when only some foods have data', (tester) async {
      await pump(tester, NutrientSummary.of([const Nutrients({'fiber_g': 3}), null, null]));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('nutrients_note'))).data,
        startsWith('Based on 1 of 3 foods today'),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('an empty day and a day with no data each explain themselves, with no numbers', (tester) async {
      await pump(tester, NutrientSummary.of(const []));
      expect(find.textContaining('show up here as you log food'), findsOneWidget);

      await pump(tester, NutrientSummary.of([null, null]));
      expect(find.textContaining("don't have nutrient data"), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrient_fiber_g')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('never uses alarming words', (tester) async {
      await pump(
        tester,
        NutrientSummary.of([const Nutrients({'sodium_mg': 5000, 'iron_mg': 0.1})], targets: {'sodium_limit_mg': 2300, 'iron_mg': 18}),
      );
      final text = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ').toLowerCase();
      for (final word in ['deficien', 'too much', 'too little', 'warning', 'danger', 'over', 'low ']) {
        expect(text, isNot(contains(word)), reason: word);
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
