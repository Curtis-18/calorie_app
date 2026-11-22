import 'package:calorie_app/services/day_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int target({bool today = true, int? weekly, int? profile = 2000, int extra = 0}) =>
      dayCalorieTarget(isToday: today, weeklyAllowanceToday: weekly, profileTarget: profile, movementExtra: extra);

  group('the number the Today ring counts toward', () {
    test('is the profile target by default, and 2000 when there is none', () {
      expect(target(), 2000);
      expect(target(profile: 1800), 1800);
      expect(target(profile: null), 2000);
    });

    test('the weekly allowance replaces it on today only', () {
      expect(target(weekly: 1700), 1700);
      expect(target(today: false, weekly: 1700, profile: 1800), 1800);
    });

    test('movement the person chose to add is on top, today only', () {
      expect(target(extra: 25), 2025);
      expect(target(profile: 1800, weekly: 1700, extra: 45), 1745);
      expect(target(today: false, profile: 1800, extra: 45), 1800, reason: 'a past day never gets it');
    });

    test('nothing added (Off, or no movement) changes nothing, and a bad value cannot lower it', () {
      expect(target(extra: 0), 2000);
      expect(target(extra: -50), 2000);
    });
  });
}
