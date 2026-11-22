import '../l10n/app_strings.dart';

/// How a person says they feel, to get meal ideas. Chosen on the Recipes
/// page, never saved, never sent anywhere, never shown to friends.
enum Mood {
  tired,
  stressed,
  low,
  good,
  comfort;

  String get label => switch (this) {
        Mood.tired => tr('Tired'),
        Mood.stressed => tr('Stressed'),
        Mood.low => tr('A bit low'),
        Mood.good => tr('Feeling good'),
        Mood.comfort => tr('Want comfort'),
      };

  /// One plain line about the kind of meal suggested (no health claims).
  String get blurb => switch (this) {
        Mood.tired => tr('Steady, filling meals'),
        Mood.stressed => tr('Easy meals with whole grains, greens and nuts'),
        Mood.low => tr('Warm, simple meals with something fresh'),
        Mood.good => tr('Bright, colourful meals'),
        Mood.comfort => tr('Warm, cosy meals'),
      };
}

/// Plain facts about a meal that the picker can see. Each is something that is
/// in the dish or how it is cooked, never a claim about what it does to you.
enum FoodFeature {
  oilyFish,
  wholeGrains,
  legumes,
  leafyGreens,
  colourfulVeg,
  fermented,
  nutsSeeds,
  eggs,
  fruit,
  warmComforting,
  lightFresh,
  friedHeavy,
  sweet;

  /// The words shown as a reason ("Why this one"), or null for features that
  /// only ever count against a meal and are never shown as a reason.
  String? get reason => switch (this) {
        FoodFeature.oilyFish => tr('Oily fish'),
        FoodFeature.wholeGrains => tr('Whole grains'),
        FoodFeature.legumes => tr('Beans and lentils'),
        FoodFeature.leafyGreens => tr('Leafy greens'),
        FoodFeature.colourfulVeg => tr('Plenty of vegetables'),
        FoodFeature.fermented => tr('Fermented food'),
        FoodFeature.nutsSeeds => tr('Nuts or seeds'),
        FoodFeature.eggs => tr('Eggs'),
        FoodFeature.fruit => tr('Fruit'),
        FoodFeature.warmComforting => tr('Warm and comforting'),
        FoodFeature.lightFresh => tr('Light and fresh'),
        FoodFeature.friedHeavy || FoodFeature.sweet => null,
      };
}

/// How much each feature counts for each mood. Positive = a good fit, negative
/// = a poorer fit. These are editable numbers on purpose: the table is the
/// whole algorithm, and a dietitian can review it line by line.
const Map<Mood, Map<FoodFeature, int>> moodWeights = {
  Mood.tired: {
    FoodFeature.wholeGrains: 3,
    FoodFeature.legumes: 3,
    FoodFeature.eggs: 2,
    FoodFeature.oilyFish: 2,
    FoodFeature.nutsSeeds: 1,
    FoodFeature.leafyGreens: 1,
    FoodFeature.fruit: 1,
    FoodFeature.friedHeavy: -3,
    FoodFeature.sweet: -2,
  },
  Mood.stressed: {
    FoodFeature.wholeGrains: 2,
    FoodFeature.leafyGreens: 2,
    FoodFeature.nutsSeeds: 2,
    FoodFeature.oilyFish: 2,
    FoodFeature.fermented: 1,
    FoodFeature.warmComforting: 1,
    FoodFeature.friedHeavy: -2,
    FoodFeature.sweet: -1,
  },
  Mood.low: {
    FoodFeature.oilyFish: 3,
    FoodFeature.eggs: 2,
    FoodFeature.wholeGrains: 2,
    FoodFeature.leafyGreens: 2,
    FoodFeature.fermented: 2,
    FoodFeature.warmComforting: 2,
    FoodFeature.fruit: 1,
    FoodFeature.nutsSeeds: 1,
    FoodFeature.sweet: -2,
    FoodFeature.friedHeavy: -1,
  },
  Mood.good: {
    FoodFeature.colourfulVeg: 3,
    FoodFeature.lightFresh: 3,
    FoodFeature.fruit: 2,
    FoodFeature.oilyFish: 1,
    FoodFeature.leafyGreens: 1,
  },
  Mood.comfort: {
    FoodFeature.warmComforting: 4,
    FoodFeature.legumes: 1,
    FoodFeature.wholeGrains: 1,
    FoodFeature.eggs: 1,
    FoodFeature.friedHeavy: -1,
  },
};

/// A suggested recipe with the plain reasons it was picked.
class MoodPick<T> {
  const MoodPick({required this.recipe, required this.score, required this.reasons});

  final T recipe;
  final int score;
  final List<FoodFeature> reasons;
}
