import 'detected_food.dart';
import 'nutrients.dart';

/// A one-tap extra on the photo review screen. Either it adds a known amount
/// of a food that the camera can't see ("add" - oil, butter, dressing), or it
/// scales the photographed foods ("scale" - a restaurant portion).
/// The numbers come from the server (USDA), never from this app.
class Adjustment {
  const Adjustment({
    required this.id,
    required this.isScale,
    required this.label,
    this.entryName = '',
    this.grams = 0,
    this.factor = 1,
    this.caloriesPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.extrasPer100g = const {},
    this.matchedDescription,
    this.matchedFdcId,
    this.preparations = const [],
    this.kinds = const [],
    this.always = false,
  });

  final String id;
  final bool isScale;
  final String label;
  final String entryName;
  final double grams;
  final double factor;
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final Map<String, double> extrasPer100g;
  final String? matchedDescription;
  final int? matchedFdcId;
  final List<String> preparations;
  final List<String> kinds;
  final bool always;

  static Adjustment? fromJson(Object? raw) {
    try {
      final j = raw as Map<String, dynamic>;
      final scale = j['kind'] == 'scale';
      final calories = (j['calories_per_100g'] as num?)?.toDouble();
      if (!scale && calories == null) return null; // nothing to add without numbers
      return Adjustment(
        id: j['id'] as String,
        isScale: scale,
        label: j['label'] as String,
        entryName: (j['entry_name'] as String?) ?? '',
        grams: (j['grams'] as num?)?.toDouble() ?? 0,
        factor: (j['factor'] as num?)?.toDouble() ?? 1,
        caloriesPer100g: calories,
        proteinPer100g: (j['protein_g_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (j['carbs_g_per_100g'] as num?)?.toDouble(),
        fatPer100g: (j['fat_g_per_100g'] as num?)?.toDouble(),
        extrasPer100g: Nutrients.per100gFromApi(j),
        matchedDescription: j['matched_description'] as String?,
        matchedFdcId: (j['matched_fdc_id'] as num?)?.toInt(),
        preparations: [for (final p in (j['preparations'] as List? ?? const [])) p as String],
        kinds: [for (final k in (j['kinds'] as List? ?? const [])) k as String],
        always: j['always'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether this extra makes sense for what was photographed: oil for a fried
  /// food, dressing for a salad, nothing for plain fruit. A scale extra is
  /// always offered; an add extra needs the server's hint, so an older server
  /// that sends none offers only the scale.
  bool appliesTo(List<DetectedFood> photographed) {
    if (always) return true;
    return photographed.any((f) =>
        f.adjustmentId == null &&
        ((f.preparation != null && preparations.contains(f.preparation)) ||
            (f.kind != null && kinds.contains(f.kind))));
  }

  /// The food this extra adds to the meal.
  DetectedFood toFood() => DetectedFood(
        name: entryName,
        estimatedGrams: grams,
        caloriesPer100g: caloriesPer100g,
        proteinPer100g: proteinPer100g,
        carbsPer100g: carbsPer100g,
        fatPer100g: fatPer100g,
        extrasPer100g: extrasPer100g,
        matched: true,
        matchedDescription: matchedDescription,
        matchedFdcId: matchedFdcId,
        adjustmentId: id,
      );
}
