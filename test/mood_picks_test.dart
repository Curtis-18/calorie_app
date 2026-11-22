import 'dart:convert';

import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/mood.dart';
import 'package:calorie_app/models/recipe.dart';
import 'package:calorie_app/screens/library_screen.dart';
import 'package:calorie_app/services/mood_picks.dart';
import 'package:calorie_app/services/recipe_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

RecipeSummary r(String id, String name) => RecipeSummary(id: id, name: name, thumbnailUrl: 'https://img.test/$id.jpg');

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('what the picker can see in a dish', () {
    test('plain food words, whole words only', () {
      expect(featuresFromText(['Baked Salmon with Spinach']), containsAll([FoodFeature.oilyFish, FoodFeature.leafyGreens]));
      expect(featuresFromText(['Lentil Soup']), containsAll([FoodFeature.legumes, FoodFeature.warmComforting]));
      expect(featuresFromText(['Greek Yoghurt Bowl']), contains(FoodFeature.fermented));
      expect(featuresFromText(['Goat curry']), isNot(contains(FoodFeature.wholeGrains)), reason: '"goat" is not "oat"');
      expect(featuresFromText(['Chicken Stir Fry']), isNot(contains(FoodFeature.friedHeavy)), reason: 'stir fry is not deep fried');
      expect(featuresFromText(['Beer Battered Fish and Chips']), contains(FoodFeature.friedHeavy));
      expect(featuresFromText(['Sticky Toffee Pudding']), contains(FoodFeature.sweet));
    });

    test('pies: savoury ones are comforting, sweet ones are sweet', () {
      expect(featuresFromText(['Three Fish Pie']), contains(FoodFeature.warmComforting));
      expect(featuresFromText(["Shepherd's Pie"]), contains(FoodFeature.warmComforting));
      expect(featuresFromText(['Apple Pie']), contains(FoodFeature.sweet));
      expect(featuresFromText(['Apple Pie']), isNot(contains(FoodFeature.warmComforting)));
      expect(featuresFromText(['Choc Chip Pecan Pie']), contains(FoodFeature.sweet));
    });

    test('fried dishes are heavy, but stir-fried, pan-fried and dal fry are not', () {
      expect(featuresFromText(['Fried cocoy banana']), contains(FoodFeature.friedHeavy));
      expect(featuresFromText(['Chicken Stir-fried Noodles']), isNot(contains(FoodFeature.friedHeavy)));
      expect(featuresFromText(['Pan-fried Salmon']), isNot(contains(FoodFeature.friedHeavy)));
      expect(featuresFromText(['Dal fry']), isNot(contains(FoodFeature.friedHeavy)));
    });

    test('an egg dish is an egg dish, an egg roll is not', () {
      expect(featuresFromText(['Egg Drop Soup']), contains(FoodFeature.eggs));
      expect(featuresFromText(['Air Fryer Egg Rolls']), isNot(contains(FoodFeature.eggs)));
    });

    test('"plenty of vegetables" needs two different colourful vegetables', () {
      expect(featuresFromText(['Roast carrots']), isNot(contains(FoodFeature.colourfulVeg)));
      expect(featuresFromText(['carrots', 'red pepper', 'olive oil']), contains(FoodFeature.colourfulVeg));
      expect(featuresFromText(['Carrot and carrot']), isNot(contains(FoodFeature.colourfulVeg)));
    });
  });

  group('the weights', () {
    test('every mood has something it likes, and every liked feature can be looked up or read from a name', () {
      for (final mood in Mood.values) {
        final weights = moodWeights[mood]!;
        expect(weights.values.any((w) => w > 0), isTrue, reason: '$mood');
        expect(featuresToFetch(mood).length, lessThanOrEqualTo(4));
      }
      for (final feature in featureIngredients.keys) {
        expect(featureIngredients[feature], isNotEmpty);
      }
    });

    test('a fried or sweet dish never beats a whole-grain or lentil one when tired', () {
      final tired = scoreFor(Mood.tired, featuresFromText(['Oat porridge with walnuts']));
      final fried = scoreFor(Mood.tired, featuresFromText(['Fried chicken nuggets']));
      final cake = scoreFor(Mood.tired, featuresFromText(['Chocolate cake']));
      expect(tired, greaterThan(fried));
      expect(tired, greaterThan(cake));
      expect(fried, lessThan(0));
    });

    test('only positive, readable features are ever given as reasons', () {
      final features = {FoodFeature.friedHeavy, FoodFeature.sweet, FoodFeature.legumes, FoodFeature.wholeGrains, FoodFeature.eggs};
      final reasons = reasonsFor(Mood.tired, features);
      expect(reasons, [FoodFeature.wholeGrains, FoodFeature.legumes]); // strongest first, at most two
      expect(reasonsFor(Mood.tired, {FoodFeature.friedHeavy}), isEmpty);
    });
  });

  group('ranking', () {
    test('a recipe found by two ingredients outranks one found by one, once per feature', () {
      final both = r('1', 'Salmon and Spinach Bake');
      final one = r('2', 'Plain Spinach Dish');
      final ranked = rankForMood(Mood.stressed, fromIngredient: {
        FoodFeature.oilyFish: [both],
        FoodFeature.leafyGreens: [both, one, one], // listed twice: still counts once
      });
      expect(ranked.first.recipe.id, '1');
      expect(ranked.first.score, 4);
      expect(ranked.map((p) => p.recipe.id), ['1', '2']);
      expect(ranked.first.reasons, [FoodFeature.oilyFish, FoodFeature.leafyGreens]);
    });

    test('the Browse list is judged by name too, weak matches are left out, and the list is capped', () {
      final pool = [
        r('1', 'Chicken Noodle Soup'),
        r('2', 'Beef Burger'),
        r('3', 'Apple Cake'),
        for (var i = 10; i < 40; i++) r('$i', 'Vegetable Stew $i'),
      ];
      final ranked = rankForMood(Mood.comfort, fromIngredient: const {}, pool: pool, limit: 5);
      expect(ranked.length, 5);
      expect(ranked.every((p) => p.score >= 2), isTrue);
      expect(ranked.map((p) => p.recipe.id), isNot(contains('2')));
      expect(ranked.map((p) => p.recipe.id), isNot(contains('3')));
    });

    test('a sweet dish is never suggested, whether its name or the catalogue says so, for any feeling', () {
      final pool = [r('1', 'Chocolate Lentil Brownie'), r('2', 'Lentil Stew'), r('3', 'Plain Bean Stew')];
      for (final mood in Mood.values) {
        final ranked = rankForMood(mood, fromIngredient: {FoodFeature.legumes: pool}, pool: pool, sweetIds: {'3'}, minScore: -99);
        expect(ranked.map((p) => p.recipe.id), isNot(contains('1')), reason: '$mood: sweet by name');
        expect(ranked.map((p) => p.recipe.id), isNot(contains('3')), reason: '$mood: sweet by the catalogue');
      }
    });

    test('a daily seed changes the order of equal scores but never the set, and 0 keeps name order', () {
      final pool = [for (var i = 1; i <= 12; i++) r('$i', 'Bean Stew ${String.fromCharCode(64 + i)}')];
      List<String> ids(int seed) => rankForMood(Mood.comfort, fromIngredient: const {}, pool: pool, seed: seed).map((p) => p.recipe.id).toList();
      expect(ids(0), [for (var i = 1; i <= 12; i++) '$i'], reason: 'name order');
      expect([...ids(5)]..sort(), [...ids(0)]..sort(), reason: 'same set');
      expect(ids(5), isNot(equals(ids(6))), reason: 'a different day, a different order');
      expect(ids(5), equals(ids(5)), reason: 'the same day, the same order');
    });

    test('ties are broken by name so the order is stable', () {
      final a = r('1', 'Bean Stew');
      final b = r('2', 'Lentil Stew');
      final ranked = rankForMood(Mood.comfort, fromIngredient: const {}, pool: [b, a]);
      expect(ranked.map((p) => p.recipe.name), ['Bean Stew', 'Lentil Stew']);
    });

    test('nothing fits: an empty list, not an error', () {
      expect(rankForMood(Mood.good, fromIngredient: const {}, pool: [r('1', 'Beef Burger')]), isEmpty);
    });
  });

  group('wording', () {
    // The same spirit as the notification word list: food is not a reward or a punishment,
    // and no claim about brain chemistry or treating anything.
    final banned = RegExp(r"treat|reward|earn|cheat|guilt|burn|boost|dopamine|serotonin|diet\b|detox|clean|\bbad\b|punish|cure|heal|therapy|depress|anxiety", caseSensitive: false);

    List<String> copy() => [
          for (final m in Mood.values) ...[m.label, m.blurb],
          for (final f in FoodFeature.values) if (f.reason != null) f.reason!,
          tr('How are you feeling?'),
          tr('Pick one for meal ideas. Nothing is saved.'),
          tr('Could not load ideas. Try again.'),
          tr('No matches right now. Try another feeling.'),
          tr('General ideas, not medical advice.'),
          tr('If a low mood lasts, it can help to talk to someone you trust or a doctor.'),
        ];

    test('English copy has none of the banned words', () {
      for (final line in copy()) {
        expect(banned.hasMatch(line), isFalse, reason: line);
      }
    });

    test('every language has its own words for every mood, blurb and reason', () {
      for (final lang in ['es', 'fr', 'de', 'pt', 'it']) {
        AppStrings.active = 'en';
        final english = copy();
        AppStrings.active = lang;
        final translated = copy();
        for (var i = 0; i < english.length; i++) {
          expect(translated[i], isNot(english[i]), reason: '$lang: ${english[i]}');
        }
      }
    });
  });

  group('on the Recipes page', () {
    // Browse by category, and "filter by ingredient" answers from a small table.
    MockClient backend({Map<String, List<RecipeSummary>> byIngredient = const {}, bool offlineForIngredients = false}) {
      Map<String, dynamic> meal(RecipeSummary x) => {'idMeal': x.id, 'strMeal': x.name, 'strMealThumb': x.thumbnailUrl};
      return MockClient((req) async {
        final q = req.url.queryParameters;
        if (q.containsKey('i')) {
          if (offlineForIngredients) throw http.ClientException('offline');
          return http.Response(jsonEncode({'meals': (byIngredient[q['i']] ?? []).map(meal).toList()}), 200);
        }
        if (q['c'] == 'Chicken') {
          return http.Response(jsonEncode({'meals': [meal(r('900', 'Chicken Noodle Soup'))]}), 200);
        }
        return http.Response(jsonEncode({'meals': null}), 200);
      });
    }

    Future<void> show(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed') || d.exceptionAsString().contains('Image')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      await tester.pumpWidget(ProviderScope(
        child: CupertinoApp(theme: AppTheme.cupertino, home: LibraryScreen(service: RecipeService(client: client))),
      ));
      await settle(tester);
    }

    testWidgets('five feelings, nothing suggested until one is picked', (tester) async {
      await show(tester, backend());
      for (final m in Mood.values) {
        expect(find.byKey(ValueKey('mood_${m.name}'), skipOffstage: false), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('mood_blurb'), skipOffstage: false), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('picking Tired suggests whole-grain and lentil meals with their reasons, and the choice is not saved', (tester) async {
      final lentilStew = r('1', 'Red Lentil Stew');
      final oats = r('2', 'Oat Porridge');
      await show(tester, backend(byIngredient: {'lentils': [lentilStew], 'oats': [oats]}));
      await tester.tap(find.byKey(const ValueKey('mood_tired'), skipOffstage: false));
      await settle(tester);

      expect(find.byKey(const ValueKey('mood_blurb'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('mood_pick_1'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('mood_pick_2'), skipOffstage: false), findsOneWidget);
      final reasons = tester.widget<Text>(find.byKey(const ValueKey('mood_reasons_1'), skipOffstage: false)).data!;
      expect(reasons, contains('Beans and lentils'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty, reason: 'a feeling is never stored');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('picking the same feeling again clears it', (tester) async {
      await show(tester, backend(byIngredient: {'lentils': [r('1', 'Red Lentil Stew')]}));
      await tester.tap(find.byKey(const ValueKey('mood_tired'), skipOffstage: false));
      await settle(tester);
      expect(find.byKey(const ValueKey('mood_pick_1'), skipOffstage: false), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mood_tired'), skipOffstage: false));
      await settle(tester);
      expect(find.byKey(const ValueKey('mood_pick_1'), skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('mood_blurb'), skipOffstage: false), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('only "a bit low" shows the kind pointer to someone who can help', (tester) async {
      await show(tester, backend());
      await tester.tap(find.byKey(const ValueKey('mood_good'), skipOffstage: false));
      await settle(tester);
      expect(find.byKey(const ValueKey('mood_care'), skipOffstage: false), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mood_low'), skipOffstage: false));
      await settle(tester);
      expect(find.byKey(const ValueKey('mood_care'), skipOffstage: false), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('comfort also judges the Browse list by dish names', (tester) async {
      await show(tester, backend());
      await tester.tap(find.byKey(const ValueKey('mood_comfort'), skipOffstage: false));
      await settle(tester);
      expect(find.byKey(const ValueKey('mood_pick_900'), skipOffstage: false), findsOneWidget, reason: 'Chicken Noodle Soup is warm');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('no connection: a plain message, and the page still works', (tester) async {
      await show(tester, backend(offlineForIngredients: true));
      await tester.tap(find.byKey(const ValueKey('mood_tired'), skipOffstage: false));
      await settle(tester);
      expect(find.byKey(const ValueKey('mood_failed'), skipOffstage: false), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
