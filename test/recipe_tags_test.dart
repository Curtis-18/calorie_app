import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/models/recipe_tags.dart';
import 'package:calorie_app/providers/house_recipes_provider.dart';
import 'package:calorie_app/screens/my_recipes_view.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HouseRecipe recipe(String id, int kcal, double protein, double carbs) => HouseRecipe(
      id: id,
      title: 'Recipe $id',
      servings: 2,
      calories: kcal,
      proteinG: protein,
      carbsG: carbs,
      fatG: 10,
      estimated: false,
      mine: true,
    );

class _Recipes extends HouseRecipesNotifier {
  _Recipes(List<HouseRecipe> recipes) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    state = HouseRecipesState(recipes: recipes, loading: false);
  }
}

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the rules', () {
    Set<RecipeTag> t(int kcal, double p, double c) => tagsFor(kcal: kcal, proteinG: p, carbsG: c);

    test('high protein: 25 g or more a serving', () {
      expect(t(400, 25, 50), contains(RecipeTag.highProtein));
      expect(t(400, 24.9, 50), isNot(contains(RecipeTag.highProtein)));
    });

    test('low carb: 20 g or fewer a serving', () {
      expect(t(400, 5, 20), contains(RecipeTag.lowCarb));
      expect(t(400, 5, 20.1), isNot(contains(RecipeTag.lowCarb)));
      expect(t(400, 5, 0), contains(RecipeTag.lowCarb));
    });

    test('under 600 kcal: strictly fewer than 600', () {
      expect(t(599, 0, 90), contains(RecipeTag.under600));
      expect(t(600, 0, 90), isNot(contains(RecipeTag.under600)));
    });

    test('a recipe can have several tags, and none with no usable numbers', () {
      expect(t(450, 35, 12), {RecipeTag.highProtein, RecipeTag.lowCarb, RecipeTag.under600});
      expect(t(0, 30, 5), isEmpty);
      expect(t(-1, 30, 5), isEmpty);
      expect(t(400, double.nan, double.nan), {RecipeTag.under600});
      expect(t(400, 5, -3), {RecipeTag.under600});
    });

    test('is the same for the same numbers', () {
      expect(recipe('1', 480, 30, 12).tags, recipe('2', 480, 30, 12).tags);
    });
  });

  group('the words', () {
    final banned = RegExp(r'diet|burn|cheat|clean|detox|\bbad\b|\bgood\b|treat|reward|earn|guilt|punish|should|must|healthy|unhealthy|lose weight', caseSensitive: false);
    List<String> copy() => [for (final t in RecipeTag.values) ...[t.label, t.rule]];

    test('nothing calls a recipe good or bad, and nothing tells anyone what to eat', () {
      for (final line in copy()) {
        expect(banned.hasMatch(line), isFalse, reason: line);
      }
    });

    test('every language has its own words', () {
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

  group('the Mine tab', () {
    final mine = [
      recipe('a', 450, 35, 12), // high protein, low carb, under 600
      recipe('b', 780, 40, 60), // high protein only
      recipe('c', 300, 8, 15), // low carb, under 600
      recipe('d', 650, 10, 80), // none
    ];

    Future<void> show(WidgetTester tester, List<HouseRecipe> recipes) async {
      tester.view.physicalSize = const Size(750, 2600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final original = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        original?.call(d);
      };
      addTearDown(() => FlutterError.onError = original);
      await tester.pumpWidget(ProviderScope(
        overrides: [houseRecipesProvider.overrideWith((ref) => _Recipes(recipes))],
        child: CupertinoApp(theme: AppTheme.cupertino, home: const CupertinoPageScaffold(child: MyRecipesView())),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pick(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 200));
    }

    Finder row(String id) => find.byKey(ValueKey('house_$id'), skipOffstage: false);
    List<int> shown(List<String> ids) => [for (final id in ids) row(id).evaluate().length];

    testWidgets('three chips, nothing chosen, everything shown', (tester) async {
      await show(tester, mine);
      for (final k in ['tag_highProtein', 'tag_lowCarb', 'tag_under600']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(shown(['a', 'b', 'c', 'd']), [1, 1, 1, 1]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('one chip narrows the list and says how it was decided', (tester) async {
      await show(tester, mine);
      await pick(tester, 'tag_highProtein');
      expect(shown(['a', 'b', 'c', 'd']), [1, 1, 0, 0]);
      expect(find.text('High protein: at least 25 g of protein a serving.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('chips combine: every chosen one has to fit', (tester) async {
      await show(tester, mine);
      await pick(tester, 'tag_highProtein');
      await pick(tester, 'tag_lowCarb');
      expect(shown(['a', 'b', 'c', 'd']), [1, 0, 0, 0]);
      expect(find.byKey(const ValueKey('tag_rule_highProtein')), findsOneWidget);
      expect(find.byKey(const ValueKey('tag_rule_lowCarb')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a tag works together with a goal chip', (tester) async {
      await show(tester, mine);
      await pick(tester, 'goal_gain'); // b (780) and d (650)
      await pick(tester, 'tag_highProtein'); // only b
      expect(shown(['a', 'b', 'c', 'd']), [0, 1, 0, 0]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('tapping a chosen chip again clears it', (tester) async {
      await show(tester, mine);
      await pick(tester, 'tag_lowCarb');
      expect(row('b'), findsNothing);
      await pick(tester, 'tag_lowCarb');
      expect(shown(['a', 'b', 'c', 'd']), [1, 1, 1, 1]);
      expect(find.byKey(const ValueKey('tag_rule_lowCarb')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a mix nothing fits says so, kindly', (tester) async {
      await show(tester, [recipe('x', 700, 5, 90)]);
      await pick(tester, 'tag_under600');
      expect(find.byKey(const ValueKey('goal_none')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
