import '../models/house_recipe.dart';

/// Meal ideas shown after a session: the person's own recipes with the most
/// protein per serving. Deliberately NOT sized to the workout and never tied to
/// calories (roadmap R2.3: no "earning" or "making up for" food). A recipe needs
/// at least [minProteinG] to be offered, so the list is never padding.
const double minProteinG = 15;

List<HouseRecipe> refuelIdeas(List<HouseRecipe> recipes, {int limit = 3}) {
  final candidates = [
    for (final r in recipes)
      if (r.mine && r.calories > 0 && r.proteinG >= minProteinG) r,
  ];
  candidates.sort((a, b) {
    final byProtein = b.proteinG.compareTo(a.proteinG);
    return byProtein != 0 ? byProtein : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return candidates.take(limit).toList();
}
