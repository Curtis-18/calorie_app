import '../l10n/app_strings.dart';
import 'house_recipe.dart';
import 'user_profile.dart';

/// Which goal a recipe suits, worked out from its own numbers per serving.
/// Nothing is typed in by an author and nothing is stored: the same recipe
/// always gets the same answer, and the rules below are all there is.
///
/// A recipe can suit more than one goal (a 620 kcal serving is both a
/// maintenance and a weight-gain meal). None of these is "good" or "bad", and
/// none says how much a person should eat.
enum RecipeGoal {
  loss,
  maintain,
  gain;

  String get label => switch (this) {
        RecipeGoal.loss => tr('Weight loss'),
        RecipeGoal.maintain => tr('Maintain'),
        RecipeGoal.gain => tr('Weight gain'),
      };

  /// The rule, in words, shown when the filter is on.
  String get rule => switch (this) {
        RecipeGoal.loss => tr('Up to 500 kcal a serving, with at least a fifth of the calories from protein.'),
        RecipeGoal.maintain => tr('Between 350 and 650 kcal a serving.'),
        RecipeGoal.gain => tr('600 kcal or more a serving.'),
      };
}

/// The chip that matches the goal the person chose in their profile, so the
/// Mine tab can start on it ("All" stays one tap away). Null: start on All.
RecipeGoal? recipeGoalFor(Goal? goal) => switch (goal) {
      Goal.lose => RecipeGoal.loss,
      Goal.maintain => RecipeGoal.maintain,
      Goal.gain => RecipeGoal.gain,
      null => null,
    };

/// The thresholds, written down once and covered by tests.
const int lossMaxKcal = 500;
const int lossMinKcal = 100; // below this it is a snack or a drink, not a meal
const double lossMinProteinShare = 0.20; // share of the calories that come from protein
const int maintainMinKcal = 350;
const int maintainMaxKcal = 650;
const int gainMinKcal = 600;

/// The goals [kcal] and [proteinG] per serving suit. Empty when there are no
/// usable numbers.
Set<RecipeGoal> goalsFor({required int kcal, required double proteinG}) {
  if (kcal <= 0) return const {};
  final proteinShare = (proteinG.isFinite && proteinG > 0 ? proteinG * 4 : 0) / kcal;
  return {
    if (kcal >= lossMinKcal && kcal <= lossMaxKcal && proteinShare >= lossMinProteinShare) RecipeGoal.loss,
    if (kcal >= maintainMinKcal && kcal <= maintainMaxKcal) RecipeGoal.maintain,
    if (kcal >= gainMinKcal) RecipeGoal.gain,
  };
}

extension RecipeGoals on HouseRecipe {
  Set<RecipeGoal> get goals => goalsFor(kcal: calories, proteinG: proteinG);
}
