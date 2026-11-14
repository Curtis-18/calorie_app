/// The extra nutrients tracked beyond calories and macros.
///
/// The numbers come from the USDA food a log entry was matched to, never from
/// the photo estimate. A nutrient with no data is *unknown*, not zero: it is
/// simply absent from the map, and a day's total says how many foods it is
/// based on. Keys match the backend (`fiber_g`, `iron_mg`, ...).
class NutrientInfo {
  const NutrientInfo(this.key, this.label, this.unit, {this.targetKey, this.isLimit = false});

  final String key;
  final String label;
  final String unit;

  /// Where the daily reference amount sits in the server's `nutrient_targets`
  /// (null for sugar, which has none).
  final String? targetKey;

  /// A ceiling to stay under (sodium) rather than an amount to reach.
  final bool isLimit;
}

const nutrientInfos = <NutrientInfo>[
  NutrientInfo('fiber_g', 'Fibre', 'g', targetKey: 'fiber_g'),
  NutrientInfo('sugar_g', 'Sugar', 'g'),
  NutrientInfo('sodium_mg', 'Sodium', 'mg', targetKey: 'sodium_limit_mg', isLimit: true),
  NutrientInfo('iron_mg', 'Iron', 'mg', targetKey: 'iron_mg'),
  NutrientInfo('calcium_mg', 'Calcium', 'mg', targetKey: 'calcium_mg'),
];

/// Known amounts for one food as eaten. Never holds a key it has no value for.
class Nutrients {
  const Nutrients(this.amounts);

  final Map<String, double> amounts;

  bool get isEmpty => amounts.isEmpty;

  double? operator [](String key) => amounts[key];

  /// Parse a per-100 g set from a search result or photo item, whose fields
  /// are named `<key>_per_100g`. Empty when the food has none.
  static Map<String, double> per100gFromApi(Map<String, dynamic> json) => {
        for (final info in nutrientInfos)
          if (json['${info.key}_per_100g'] case final num value) info.key: value.toDouble(),
      };

  /// The amounts in [grams] of a food with these per-100 g values, or null
  /// when the food has no nutrient data at all.
  static Nutrients? forPortion(Map<String, double> per100g, double grams) {
    if (per100g.isEmpty) return null;
    return Nutrients({for (final e in per100g.entries) e.key: _tidy(e.value / 100 * grams)});
  }

  /// The same food at [factor] times the portion.
  Nutrients scaled(double factor) =>
      Nutrients({for (final e in amounts.entries) e.key: _tidy(e.value * factor)});

  // Two decimals is finer than the source data; avoids 2.2000000000000006.
  static double _tidy(double v) => (v * 100).roundToDouble() / 100;

  Map<String, dynamic> toJson() => amounts;

  /// From the device cache or the API (`null` or missing = no data).
  static Nutrients? fromJson(Object? json) {
    if (json is! Map) return null;
    final amounts = <String, double>{
      for (final info in nutrientInfos)
        if (json[info.key] case final num value) info.key: value.toDouble(),
    };
    return amounts.isEmpty ? null : Nutrients(amounts);
  }
}

/// One nutrient's total for a day.
class NutrientTotal {
  const NutrientTotal({required this.info, required this.amount, required this.foodsWithData, this.target});

  final NutrientInfo info;
  final double amount;

  /// How many of the day's foods had a value for this nutrient.
  final int foodsWithData;
  final int? target;
}

/// A day's nutrient totals, with how much of the day they cover.
class NutrientSummary {
  const NutrientSummary({required this.totals, required this.foods, required this.foodsWithData});

  final List<NutrientTotal> totals;
  final int foods;

  /// Foods with at least one nutrient value.
  final int foodsWithData;

  bool get hasData => foodsWithData > 0;

  /// Some of the day's foods are missing from these totals.
  bool get isPartial => foodsWithData < foods;

  factory NutrientSummary.of(Iterable<Nutrients?> perFood, {Map<String, int>? targets}) {
    final list = perFood.toList();
    return NutrientSummary(
      foods: list.length,
      foodsWithData: list.where((n) => n != null && !n.isEmpty).length,
      totals: [
        for (final info in nutrientInfos)
          NutrientTotal(
            info: info,
            amount: list.fold(0.0, (sum, n) => sum + (n?[info.key] ?? 0)),
            foodsWithData: list.where((n) => n?[info.key] != null).length,
            target: info.targetKey == null ? null : targets?[info.targetKey],
          ),
      ],
    );
  }
}

/// "2.4 g", "380 mg": one decimal under 10, whole numbers above.
String formatNutrient(double amount, String unit) {
  final text = amount < 10 && amount != amount.roundToDouble() ? amount.toStringAsFixed(1) : amount.round().toString();
  return '$text $unit';
}
