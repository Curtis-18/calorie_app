import 'nutrients.dart';
import '../l10n/app_strings.dart';

/// `data_type` the backend sends for the barcode fallback.
const openFoodFactsDataType = 'Open Food Facts';

class FoodItem {
  final int fdcId;
  final String description;
  final String? dataType;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  /// Fibre, sugar, sodium, iron and calcium per 100 g, where USDA has them.
  final Map<String, double> extrasPer100g;

  /// What the per-100 numbers are per: 'g' or 'ml'. Drinks (USDA Branded
  /// liquids, Open Food Facts products sold by volume) are labelled per 100 ml,
  /// so the amount is asked in millilitres; the maths is the same. An older
  /// backend doesn't send it: grams, as before.
  final String perUnit;
  bool get perMl => perUnit == 'ml';

  /// A product the backend found in Open Food Facts when USDA had none (its
  /// data must be credited, and it has no USDA id).
  bool get isOpenFoodFacts => dataType == openFoodFactsDataType;

  FoodItem({
    required this.fdcId,
    required this.description,
    this.dataType,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.extrasPer100g = const {},
    this.perUnit = 'g',
  });

  /// One result from the backend's `GET /foods/search`.
  factory FoodItem.fromApiJson(Map<String, dynamic> json) => FoodItem(
        fdcId: (json['fdc_id'] as num).toInt(),
        description: json['description'] as String? ?? tr('Unknown food'),
        dataType: json['data_type'] as String?,
        caloriesPer100g: nonNegative(json['calories_per_100g'] as num?),
        proteinPer100g: nonNegative(json['protein_g_per_100g'] as num?),
        carbsPer100g: nonNegative(json['carbs_g_per_100g'] as num?),
        fatPer100g: nonNegative(json['fat_g_per_100g'] as num?),
        extrasPer100g: Nutrients.per100gFromApi(json),
        perUnit: json['per_unit'] == 'ml' ? 'ml' : 'g',
      );
}