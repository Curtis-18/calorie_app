import '../models/house_recipe.dart';
import '../models/mood.dart';
import '../models/recipe.dart';

/// Which ingredients to ask TheMealDB for, per feature (names checked against
/// the live API on 22 Nov 2026; an unknown name just returns nothing).
const Map<FoodFeature, List<String>> featureIngredients = {
  FoodFeature.oilyFish: ['salmon', 'mackerel', 'sardines'],
  FoodFeature.wholeGrains: ['oats', 'oatmeal', 'brown_rice', 'quinoa'],
  FoodFeature.legumes: ['lentils', 'brown_lentils', 'chickpeas', 'black_beans', 'kidney_beans', 'tofu'],
  FoodFeature.leafyGreens: ['spinach', 'kale', 'cabbage'],
  FoodFeature.colourfulVeg: ['tomatoes', 'pumpkin', 'beetroot', 'courgettes', 'broccoli', 'butternut_squash', 'sweet_potatoes'],
  FoodFeature.fermented: ['yogurt', 'greek_yogurt', 'natural_yoghurt'],
  FoodFeature.nutsSeeds: ['walnuts', 'almonds', 'cashew_nuts', 'sesame_seed', 'tahini'],
  FoodFeature.fruit: ['blueberries', 'strawberries', 'raspberries', 'blackberries', 'apples', 'banana', 'mango', 'avocado'],
};

/// Words (whole words, any case) that show a feature in a dish name or an
/// ingredient name. Deliberately plain and short: easy to read and to review.
final Map<FoodFeature, RegExp> _keywords = {
  FoodFeature.oilyFish: _words(r'salmon|mackerel|sardines?|trout|herring|anchov(?:y|ies)|kippers?'),
  FoodFeature.wholeGrains: _words(r'oats?|oatmeal|porridge|brown rice|quinoa|barley|bulgur|bulghur|wholemeal|whole wheat|wholegrain|whole grain|rye|buckwheat|millet|farro|freekeh'),
  FoodFeature.legumes: _words(r'lentils?|chickpeas?|beans?|dal|dahl|dhal|hummus|edamame|tofu|split peas?'),
  FoodFeature.leafyGreens: _words(r'spinach|kale|chard|rocket|arugula|lettuce|cabbage|watercress|collards?|bok choy|pak choi|greens'),
  FoodFeature.fermented: _words(r'yogh?urt|kefir|kimchi|miso|sauerkraut|tempeh|natto|labneh'),
  FoodFeature.nutsSeeds: _words(r'almonds?|walnuts?|cashews?|pistachios?|peanuts?|hazelnuts?|pecans?|nuts?|seeds?|sesame|tahini|flax|chia|sunflower'),
  FoodFeature.eggs: _words(r'eggs?(?! rolls?)|omelette|omelet|frittata|shakshuka'),
  FoodFeature.fruit: _words(r'berr(?:y|ies)|blueberr(?:y|ies)|strawberr(?:y|ies)|raspberr(?:y|ies)|apples?|bananas?|oranges?|mango(?:es)?|pineapple|peach(?:es)?|pears?|grapes?|cherr(?:y|ies)|pomegranate|avocados?'),
  FoodFeature.warmComforting: _words(r'soups?|stews?|curry|curries|casserole|hotpot|chowder|risotto|broth|congee|ragu|lasagn[ae]|pot roast|porridge|dal|dahl|dhal|goulash|tagine|(?:fish|cottage|shepherd.s|chicken|steak|pot|meat) pie'),
  FoodFeature.lightFresh: _words(r'salads?|slaw|gazpacho|ceviche|poke|spring rolls?|fresh'),
  FoodFeature.friedHeavy: _words(r'deep[- ]fried|(?<!stir[- ])(?<!pan[- ])(?<!air[- ])fried|deep fry|battered|tempura|fritters?|fried chicken|nuggets?|katsu|schnitzel|burgers?|chips|croquettes?|doughnuts?|donuts?'),
  FoodFeature.sweet: _words(r'(?:apple|pecan|pumpkin|key lime|cream|banoffee|lemon meringue|cherry|berry|sweet|chocolate|choc chip|custard) pie|chocolate|choc chip|caramel|dessert|cakes?|brownies?|cookies?|tarts?|cheesecake|fudge|ice cream|crumble|trifle|muffins?|pudding|baklava|toffee|pancakes?|waffles?|sundae|mousse|sorbet'),
};

final RegExp _colourfulVeg = _words(
  r'tomato(?:es)?|peppers?|carrots?|beetroot|pumpkin|squash|courgettes?|zucchini|aubergines?|eggplant|broccoli|sweet potato(?:es)?|sweetcorn|corn',
);

RegExp _words(String alternatives) => RegExp('\\b(?:$alternatives)\\b', caseSensitive: false);

/// The features visible in some text: a dish name and/or its ingredient names.
/// "Plenty of vegetables" needs two different colourful vegetables.
Set<FoodFeature> featuresFromText(Iterable<String> texts) {
  final joined = texts.join(' | ');
  final found = <FoodFeature>{
    for (final entry in _keywords.entries)
      if (entry.value.hasMatch(joined)) entry.key,
  };
  final veg = _colourfulVeg.allMatches(joined).map((m) => m.group(0)!.toLowerCase()).toSet();
  if (veg.length >= 2) found.add(FoodFeature.colourfulVeg);
  return found;
}

/// How well a set of features fits a mood (sum of the table's weights).
int scoreFor(Mood mood, Set<FoodFeature> features) {
  final weights = moodWeights[mood]!;
  var total = 0;
  for (final f in features) {
    total += weights[f] ?? 0;
  }
  return total;
}

/// The positive features present, strongest first: why this meal was picked.
List<FoodFeature> reasonsFor(Mood mood, Set<FoodFeature> features, {int max = 2}) {
  final weights = moodWeights[mood]!;
  final good = [
    for (final f in features)
      if ((weights[f] ?? 0) > 0 && f.reason != null) f,
  ]..sort((a, b) {
      final byWeight = (weights[b] ?? 0).compareTo(weights[a] ?? 0);
      return byWeight != 0 ? byWeight : a.index.compareTo(b.index);
    });
  return good.take(max).toList();
}

/// Which features are worth looking up in the catalogue for [mood]: the
/// strongest few, so a pick costs a handful of requests, not dozens.
List<FoodFeature> featuresToFetch(Mood mood, {int top = 4}) {
  final weights = moodWeights[mood]!;
  final positive = [
    for (final e in weights.entries)
      if (e.value > 0 && featureIngredients.containsKey(e.key)) e.key,
  ]..sort((a, b) => weights[b]!.compareTo(weights[a]!));
  return positive.take(top).toList();
}

/// A dish with any of these is never suggested for a feeling (sweet dishes
/// stay in Browse; a feeling is not a reason to reach for sugar).
const Set<FoodFeature> neverSuggested = {FoodFeature.sweet};

/// A small deterministic mix of a recipe id and a seed, to vary which of
/// several equally good meals come first from one day to the next.
int _mix(String id, int seed) {
  // FNV-1a with the seed folded in first, then a final shuffle of the bits so
  // ids that differ by one character do not stay in order.
  var h = (2166136261 ^ (seed * 2654435761)) & 0xffffffff;
  for (final unit in id.codeUnits) {
    h = ((h ^ unit) * 16777619) & 0xffffffff;
  }
  h ^= h >> 15;
  h = (h * 2246822519) & 0xffffffff;
  return h ^ (h >> 13);
}

/// Ranks recipes for [mood]. [fromIngredient] maps a feature to the recipes the
/// catalogue says contain it (looked up by ingredient); [pool] is any list of
/// recipes to also judge by their name alone (the Browse list). A recipe counts
/// once per feature however many ways it matched. [sweetIds] are recipes the
/// catalogue itself files under desserts. Equal scores are put in name order,
/// or, when [seed] is not 0 (the picker passes the day), in a mix that changes
/// daily so the same dozen are not always first.
List<MoodPick<RecipeSummary>> rankForMood(
  Mood mood, {
  required Map<FoodFeature, List<RecipeSummary>> fromIngredient,
  Iterable<RecipeSummary> pool = const [],
  Set<String> sweetIds = const {},
  int seed = 0,
  int limit = 12,
  int minScore = 2,
}) {
  final byId = <String, RecipeSummary>{};
  final featuresById = <String, Set<FoodFeature>>{};

  void see(RecipeSummary r, Iterable<FoodFeature> features) {
    byId[r.id] = r;
    (featuresById[r.id] ??= <FoodFeature>{}).addAll(features);
  }

  for (final entry in fromIngredient.entries) {
    for (final r in entry.value) {
      see(r, [entry.key]);
    }
  }
  for (final r in pool) {
    see(r, const []);
  }
  // Every recipe is also judged by its own name (soup, salad, fried...).
  for (final id in byId.keys.toList()) {
    featuresById[id]!.addAll(featuresFromText([byId[id]!.name]));
  }

  for (final id in sweetIds) {
    featuresById[id]?.add(FoodFeature.sweet);
  }

  final picks = <MoodPick<RecipeSummary>>[];
  for (final entry in featuresById.entries) {
    if (entry.value.any(neverSuggested.contains)) continue;
    final score = scoreFor(mood, entry.value);
    if (score < minScore) continue;
    picks.add(MoodPick(recipe: byId[entry.key]!, score: score, reasons: reasonsFor(mood, entry.value)));
  }
  picks.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byReasons = b.reasons.length.compareTo(a.reasons.length);
    if (byReasons != 0) return byReasons;
    if (seed != 0) {
      final byMix = _mix(a.recipe.id, seed).compareTo(_mix(b.recipe.id, seed));
      if (byMix != 0) return byMix;
    }
    return a.recipe.name.toLowerCase().compareTo(b.recipe.name.toLowerCase());
  });
  return picks.take(limit).toList();
}


/// Ranks the person's OWN recipes for [mood], with the same table and the same
/// rules as [rankForMood]. Their ingredient names are known, so a dish like
/// "Mum's stew" is judged by what is in it. Recipes a friend shared with them
/// are left out: this list is "from your recipes".
List<MoodPick<HouseRecipe>> rankMineForMood(
  Mood mood,
  Iterable<HouseRecipe> recipes, {
  int seed = 0,
  int limit = 5,
  int minScore = 2,
}) {
  final picks = <MoodPick<HouseRecipe>>[];
  for (final r in recipes) {
    if (!r.mine) continue;
    final features = featuresFromText([r.title, ...r.ingredients.map((i) => i.name)]);
    if (features.any(neverSuggested.contains)) continue;
    final score = scoreFor(mood, features);
    if (score < minScore) continue;
    picks.add(MoodPick(recipe: r, score: score, reasons: reasonsFor(mood, features)));
  }
  picks.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byReasons = b.reasons.length.compareTo(a.reasons.length);
    if (byReasons != 0) return byReasons;
    if (seed != 0) {
      final byMix = _mix(a.recipe.id, seed).compareTo(_mix(b.recipe.id, seed));
      if (byMix != 0) return byMix;
    }
    return a.recipe.title.toLowerCase().compareTo(b.recipe.title.toLowerCase());
  });
  return picks.take(limit).toList();
}
