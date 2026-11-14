import 'nutrients.dart';

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

  FoodItem({
    required this.fdcId,
    required this.description,
    this.dataType,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.extrasPer100g = const {},
  });

  /// One result from the backend's `GET /foods/search`.
  factory FoodItem.fromApiJson(Map<String, dynamic> json) => FoodItem(
        fdcId: (json['fdc_id'] as num).toInt(),
        description: json['description'] as String? ?? 'Unknown food',
        dataType: json['data_type'] as String?,
        caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble(),
        proteinPer100g: (json['protein_g_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (json['carbs_g_per_100g'] as num?)?.toDouble(),
        fatPer100g: (json['fat_g_per_100g'] as num?)?.toDouble(),
        extrasPer100g: Nutrients.per100gFromApi(json),
      );
}