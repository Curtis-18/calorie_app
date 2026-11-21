import 'food_item.dart';
import 'nutrients.dart';
import '../l10n/app_strings.dart';

class DetectedFood {
  /// What the person reads and edits. In another language than English this is
  /// the server's `display_name` (the food's name in their language).
  String name;

  /// The server's English name, which the food database is searched with, and
  /// the [name] as first shown. While the person has not renamed the food,
  /// [lookupName] is the English one.
  final String? englishName;
  final String originalName;
  double estimatedGrams;
  double? caloriesPer100g;
  double? proteinPer100g;
  double? carbsPer100g;
  double? fatPer100g;
  Map<String, double> extrasPer100g; // fibre, iron etc. from the USDA match
  bool matched; // false if USDA had no match for this name
  String? matchedDescription; // the USDA food the numbers come from
  int? matchedFdcId;

  /// What the photo showed of how it was made ("fried") and what it is
  /// ("salad"), when the server could tell. Decides which one-tap extras to offer.
  final String? preparation;
  final String? kind;

  /// True when there was no database match and the numbers are a typical
  /// value for the dish (the server's `ai_estimate`). Such an item is
  /// treated as [matched] so it can be edited and saved; [estimateBasis] says
  /// what the numbers assume. Picking a real match clears both.
  bool estimated;
  String? estimateBasis;

  /// Set on a food added by a one-tap extra (oil, butter...), so toggling the
  /// chip off can take it away again.
  final String? adjustmentId;

  /// From the person's spoken note: extras they said went in ("butter"), and
  /// why an amount changed, shown under the food.
  final List<String> added;
  final String? noteApplied;

  DetectedFood({
    required this.name,
    this.englishName,
    String? originalName,
    required this.estimatedGrams,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.extrasPer100g = const {},
    this.matched = false,
    this.matchedDescription,
    this.matchedFdcId,
    this.preparation,
    this.kind,
    this.adjustmentId,
    this.added = const [],
    this.noteApplied,
    this.estimated = false,
    this.estimateBasis,
  }) : originalName = originalName ?? name;

  /// The name to search the food database with.
  String get lookupName => (englishName != null && name == originalName) ? englishName! : name;

  /// One item from `POST /estimate-photo`. Macros are present when the
  /// backend matched the food in USDA (`matched: true`).
  factory DetectedFood.fromApiJson(Map<String, dynamic> json) {
    final food = _fromApiJson(json);
    // An estimate has numbers but no database match (`matched: false` keeps
    // older apps from trying to save it). This app can: it shows the row as
    // "Estimated" and saves it with its basis.
    if (json['source'] == 'ai_estimate' && food.caloriesPer100g != null && !food.matched) {
      food.matched = true;
      food.estimated = true;
      final basis = (json['estimate_basis'] as String?)?.trim();
      food.estimateBasis = (basis == null || basis.isEmpty) ? tr('A typical value for this dish.') : basis;
    }
    return food;
  }

  static DetectedFood _fromApiJson(Map<String, dynamic> json) => DetectedFood(
        name: ((json['display_name'] as String?)?.trim().isNotEmpty ?? false) ? (json['display_name'] as String).trim() : json['name'] as String,
        englishName: json['name'] as String,
        estimatedGrams: (json['estimated_grams'] as num).toDouble(),
        caloriesPer100g: nonNegative(json['calories_per_100g'] as num?),
        proteinPer100g: nonNegative(json['protein_g_per_100g'] as num?),
        carbsPer100g: nonNegative(json['carbs_g_per_100g'] as num?),
        fatPer100g: nonNegative(json['fat_g_per_100g'] as num?),
        extrasPer100g: Nutrients.per100gFromApi(json),
        matched: json['matched'] == true,
        matchedDescription: json['matched_description'] as String?,
        matchedFdcId: (json['matched_fdc_id'] as num?)?.toInt(),
        preparation: json['preparation'] as String?,
        kind: json['kind'] as String?,
        added: [for (final a in (json['added'] as List? ?? const [])) if (a is String) a],
        noteApplied: json['note_applied'] as String?,
      );

  /// Point this item at [food]'s nutrition. Grams and the user's name stay.
  void applyMatch(FoodItem food) {
    caloriesPer100g = food.caloriesPer100g;
    proteinPer100g = food.proteinPer100g;
    carbsPer100g = food.carbsPer100g;
    fatPer100g = food.fatPer100g;
    extrasPer100g = food.extrasPer100g;
    matchedDescription = food.description;
    matchedFdcId = food.fdcId;
    matched = food.caloriesPer100g != null;
    estimated = false;
    estimateBasis = null;
  }

  int get estimatedCalories => ((caloriesPer100g ?? 0) / 100 * estimatedGrams).round();
  double get estimatedProtein => (proteinPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedCarbs => (carbsPer100g ?? 0) / 100 * estimatedGrams;
  double get estimatedFat => (fatPer100g ?? 0) / 100 * estimatedGrams;
  Nutrients? get estimatedNutrients => Nutrients.forPortion(extrasPer100g, estimatedGrams);
}