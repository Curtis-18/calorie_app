import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/models/recipe_goal.dart';
import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/providers/house_recipes_provider.dart';
import 'package:calorie_app/screens/my_recipes_view.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HouseRecipe recipe(String id, String title, int kcal, double protein, {bool mine = true}) => HouseRecipe(
      id: id,
      title: title,
      servings: 2,
      calories: kcal,
      proteinG: protein,
      carbsG: 40,
      fatG: 10,
      estimated: false,
      mine: mine,
    );

class _Recipes extends HouseRecipesNotifier {
  _Recipes(List<HouseRecipe> recipes) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    state = HouseRecipesState(recipes: recipes, loading: false);
  }
}

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the rules', () {
    Set<RecipeGoal> g(int kcal, double protein) => goalsFor(kcal: kcal, proteinG: protein);

    test('weight loss: up to 500 kcal and at least a fifth of the calories from protein', () {
      expect(g(400, 25), contains(RecipeGoal.loss)); // 100 of 400 = 25%
      expect(g(500, 25), contains(RecipeGoal.loss)); // 100 of 500 = exactly 20%
      expect(g(500, 24.9), isNot(contains(RecipeGoal.loss)));
      expect(g(501, 40), isNot(contains(RecipeGoal.loss)), reason: 'over 500');
      expect(g(450, 10), isNot(contains(RecipeGoal.loss)), reason: 'little protein');
      expect(g(80, 20), isNot(contains(RecipeGoal.loss)), reason: 'a snack or a drink, not a meal');
    });

    test('maintenance: 350 to 650 kcal', () {
      expect(g(349, 0), isNot(contains(RecipeGoal.maintain)));
      expect(g(350, 0), contains(RecipeGoal.maintain));
      expect(g(650, 0), contains(RecipeGoal.maintain));
      expect(g(651, 0), isNot(contains(RecipeGoal.maintain)));
    });

    test('weight gain: 600 kcal or more', () {
      expect(g(599, 30), isNot(contains(RecipeGoal.gain)));
      expect(g(600, 0), contains(RecipeGoal.gain));
      expect(g(1200, 0), contains(RecipeGoal.gain));
    });

    test('a recipe can suit more than one goal, and none with no usable numbers', () {
      expect(g(620, 10), {RecipeGoal.maintain, RecipeGoal.gain});
      expect(g(450, 30), {RecipeGoal.loss, RecipeGoal.maintain});
      expect(g(0, 30), isEmpty);
      expect(g(-5, 30), isEmpty);
      expect(g(400, double.nan), {RecipeGoal.maintain});
      expect(g(400, -3), {RecipeGoal.maintain});
    });

    test('the same recipe always gets the same answer', () {
      expect(recipe('1', 'Stew', 480, 30).goals, recipe('2', 'Other', 480, 30).goals);
    });
  });

  test('each profile goal has its chip; no profile means All', () {
    expect(recipeGoalFor(Goal.lose), RecipeGoal.loss);
    expect(recipeGoalFor(Goal.maintain), RecipeGoal.maintain);
    expect(recipeGoalFor(Goal.gain), RecipeGoal.gain);
    expect(recipeGoalFor(null), isNull);
  });

  group('the words', () {
    final banned = RegExp(r'diet|burn|cheat|clean|detox|\bbad\b|\bgood\b|treat|reward|earn|guilt|punish|should|must|healthy|unhealthy', caseSensitive: false);
    List<String> copy() => [
          for (final goal in RecipeGoal.values) ...[goal.label, goal.rule],
          tr('Matched from each recipe’s calories and protein. A guide, not advice.'),
          tr('None of your recipes match this yet.'),
        ];

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
      recipe('a', 'Chicken and rice', 450, 35), // loss + maintain
      recipe('b', 'Big lasagne', 780, 30), // gain
      recipe('c', 'Plain pasta', 500, 12), // maintain
      recipe('d', 'Friend soup', 300, 5, mine: false), // none
    ];

    Future<void> show(WidgetTester tester, List<HouseRecipe> recipes, {RecipeGoal? own}) async {
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
        overrides: [
          houseRecipesProvider.overrideWith((ref) => _Recipes(recipes)),
          // No override: the real provider, which can't read a profile here and so starts on All.
          if (own != null) ownRecipeGoalProvider.overrideWithValue(own),
        ],
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

    testWidgets('starts on All, with all four chips, when the profile is not known', (tester) async {
      await show(tester, mine);
      for (final k in ['goal_all', 'goal_loss', 'goal_maintain', 'goal_gain']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(row(id), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('goal_rule')), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('weight loss shows only matching recipes and says how they were matched', (tester) async {
      await show(tester, mine);
      await pick(tester, 'goal_loss');
      expect(row('a'), findsOneWidget);
      expect(row('b'), findsNothing);
      expect(row('c'), findsNothing);
      expect(row('d'), findsNothing);
      expect(find.text('Up to 500 kcal a serving, with at least a fifth of the calories from protein.'), findsOneWidget);
      expect(find.text('Matched from each recipe’s calories and protein. A guide, not advice.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('maintain and gain', (tester) async {
      await show(tester, mine);
      await pick(tester, 'goal_maintain');
      expect([row('a'), row('b'), row('c')].map((f) => f.evaluate().length), [1, 0, 1]);
      await pick(tester, 'goal_gain');
      expect([row('a'), row('b'), row('c')].map((f) => f.evaluate().length), [0, 1, 0]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('tapping the chosen chip again, or All, brings everything back', (tester) async {
      await show(tester, mine);
      await pick(tester, 'goal_gain');
      expect(row('a'), findsNothing);
      await pick(tester, 'goal_gain');
      expect(row('a'), findsOneWidget);
      await pick(tester, 'goal_loss');
      await pick(tester, 'goal_all');
      expect([row('a'), row('b'), row('c'), row('d')].map((f) => f.evaluate().length), [1, 1, 1, 1]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a goal nothing matches says so, kindly', (tester) async {
      await show(tester, [recipe('x', 'Snack', 200, 2)]);
      await pick(tester, 'goal_gain');
      expect(find.byKey(const ValueKey('goal_none')), findsOneWidget);
      expect(find.text('None of your recipes match this yet.'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('starts on the chip that matches the person\'s own goal, and All is one tap away', (tester) async {
      await show(tester, mine, own: RecipeGoal.gain);
      expect([row('a'), row('b'), row('c'), row('d')].map((f) => f.evaluate().length), [0, 1, 0, 0]);
      expect(find.text('600 kcal or more a serving.'), findsOneWidget);
      await pick(tester, 'goal_all');
      expect([row('a'), row('b'), row('c'), row('d')].map((f) => f.evaluate().length), [1, 1, 1, 1]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a chosen chip is not remembered: the tab starts on the person\'s goal again', (tester) async {
      await show(tester, mine, own: RecipeGoal.maintain);
      await pick(tester, 'goal_gain');
      await tester.pumpWidget(const SizedBox());
      await show(tester, mine, own: RecipeGoal.maintain);
      expect([row('a'), row('b'), row('c')].map((f) => f.evaluate().length), [1, 0, 1]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the filter is not remembered when the tab is opened again', (tester) async {
      await show(tester, mine);
      await pick(tester, 'goal_gain');
      await tester.pumpWidget(const SizedBox());
      await show(tester, mine);
      expect(row('a'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
