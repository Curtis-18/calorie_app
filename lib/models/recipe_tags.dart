import '../l10n/app_strings.dart';
import 'house_recipe.dart';

/// Quick filters on a recipe's own numbers per serving. Like the goals, they
/// are worked out in code from the numbers (never typed in, never stored), the
/// thresholds are written down once below, and none of them says a recipe is
/// good or bad. They narrow a list; they are not advice.
enum RecipeTag {
  highProtein,
  lowCarb,
  under600;

  String get label => switch (this) {
        RecipeTag.highProtein => tr('High protein'),
        RecipeTag.lowCarb => tr('Low carb'),
        RecipeTag.under600 => tr('Under 600 kcal'),
      };

  /// The rule, in words, shown while the chip is on.
  String get rule => switch (this) {
        RecipeTag.highProtein => tr('High protein: at least 25 g of protein a serving.'),
        RecipeTag.lowCarb => tr('Low carb: 20 g of carbs or fewer a serving.'),
        RecipeTag.under600 => tr('Under 600 kcal: fewer than 600 kcal a serving.'),
      };
}

const double highProteinMinG = 25;
const double lowCarbMaxG = 20;
const int under600Kcal = 600;

/// The tags these per-serving numbers earn. Empty when there are no usable
/// calories (a recipe with no numbers is not "low" in anything).
Set<RecipeTag> tagsFor({required int kcal, required double proteinG, required double carbsG}) {
  if (kcal <= 0) return const {};
  return {
    if (proteinG.isFinite && proteinG >= highProteinMinG) RecipeTag.highProtein,
    if (carbsG.isFinite && carbsG >= 0 && carbsG <= lowCarbMaxG) RecipeTag.lowCarb,
    if (kcal < under600Kcal) RecipeTag.under600,
  };
}

extension RecipeTags on HouseRecipe {
  Set<RecipeTag> get tags => tagsFor(kcal: calories, proteinG: proteinG, carbsG: carbsG);
}
