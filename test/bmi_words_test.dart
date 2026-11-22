import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _withBmi(double? bmi) => UserProfile(
      weightKg: 70,
      heightCm: 175,
      dateOfBirth: DateTime(1995, 5, 5),
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
      goal: Goal.maintain,
      bmi: bmi,
    );

void main() {
  tearDown(() => AppStrings.active = 'en');

  test('the BMI line is a neutral range, split at the usual cut-offs', () {
    expect(_withBmi(17.9).bmiCategory, 'Below range');
    expect(_withBmi(18.5).bmiCategory, 'In range');
    expect(_withBmi(24.9).bmiCategory, 'In range');
    expect(_withBmi(25).bmiCategory, 'Above range');
    expect(_withBmi(29.9).bmiCategory, 'Above range');
    expect(_withBmi(30).bmiCategory, 'Well above range');
    expect(_withBmi(null).bmiCategory, 'Unknown');
  });

  test('no clinical label in any language', () {
    final clinical = RegExp(r'obes|overweight|underweight|adiposas|obésit|obesid|sobrepeso|bajo peso|normalgewicht|normopeso|peso normal|poids normal', caseSensitive: false);
    for (final lang in ['en', 'es', 'fr', 'de', 'pt', 'it']) {
      AppStrings.active = lang;
      for (final bmi in [17.0, 22.0, 27.0, 33.0]) {
        final words = _withBmi(bmi).bmiCategory;
        expect(clinical.hasMatch(words), isFalse, reason: '$lang $bmi -> $words');
        if (lang != 'en') expect(words, isNot(_enFor(bmi)), reason: '$lang $bmi is not translated');
      }
    }
  });
}

String _enFor(double bmi) => bmi < 18.5 ? 'Below range' : bmi < 25 ? 'In range' : bmi < 30 ? 'Above range' : 'Well above range';
