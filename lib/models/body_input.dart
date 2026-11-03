import 'weight.dart';

/// How a height is typed in.
enum HeightUnit {
  cm('cm'),
  ftIn('ft / in');

  const HeightUnit(this.label);
  final String label;
}

/// Heights the app accepts. The server takes 3 to 8 whole feet (about 91 to
/// 264 cm); these stay inside that so a value that passes here never gets a
/// 422 for height.
const minHeightCm = 100.0;
const maxHeightCm = 250.0;

double? _number(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  return (value == null || value.isNaN || value.isInfinite) ? null : value;
}

/// Parse a typed height to centimetres, or null if it's missing, not a
/// number, or not a plausible adult height. Accepts "172,5".
///
/// For [HeightUnit.ftIn], [primary] is feet and [inches] is the inches part,
/// which may be empty (5 ft exactly).
double? parseHeightCm(HeightUnit unit, String primary, {String inches = ''}) {
  final double cm;
  switch (unit) {
    case HeightUnit.cm:
      final value = _number(primary);
      if (value == null) return null;
      cm = value;
    case HeightUnit.ftIn:
      final feet = _number(primary);
      final extra = inches.trim().isEmpty ? 0.0 : _number(inches);
      if (feet == null || extra == null || extra < 0 || extra >= 12) return null;
      cm = (feet * 12 + extra) * 2.54;
  }
  return (cm >= minHeightCm && cm <= maxHeightCm) ? cm : null;
}

/// Split a height in cm into whole feet and inches (one decimal) for display.
(int feet, double inches) feetAndInches(double cm) {
  final totalInches = cm / 2.54;
  var feet = (totalInches / 12).floor();
  var inches = double.parse((totalInches - feet * 12).toStringAsFixed(1));
  if (inches >= 12) {
    feet += 1;
    inches = 0;
  }
  return (feet, inches);
}

/// The unit people in this country normally use. Only a guess to pick a
/// sensible default; both are one tap away.
bool usesImperialUnits(String? countryCode) => const {'US', 'LR', 'MM'}.contains(countryCode?.toUpperCase());

/// What to say when a weight can't be used.
String weightProblem(WeightUnit unit) =>
    'Enter a weight between ${unit.format(20, decimals: 0)} and ${unit.format(400, decimals: 0)}.';

String heightProblem(HeightUnit unit) => unit == HeightUnit.cm
    ? 'Enter a height between ${minHeightCm.round()} and ${maxHeightCm.round()} cm.'
    : 'Enter a height between 3 ft 4 in and 8 ft 2 in.';
