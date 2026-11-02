/// Largest single portion we accept, in grams. Anything above is almost
/// certainly a typo (an extra zero) and would wreck the day's total.
const maxPortionGrams = 5000.0;

/// Parse a user-typed portion. Accepts "150", "12.5", "12,5" (comma
/// decimals) and "150 g". Returns null for empty, zero, negative or absurd
/// amounts rather than guessing: the old code silently used 100 g.
double? parseGrams(String input) {
  final cleaned = input.trim().toLowerCase().replaceAll(RegExp(r'\s*g$'), '').replaceAll(',', '.');
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value <= 0 || value > maxPortionGrams) return null;
  return value;
}

/// Calories for [grams] of a food with [per100g] kcal per 100 g, rounded to
/// the nearest kcal (at most 0.5 kcal off per entry).
int caloriesFor(double? per100g, double grams) => ((per100g ?? 0) / 100 * grams).round();
