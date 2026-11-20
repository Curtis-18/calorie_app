import 'package:flutter/cupertino.dart';

import 'user_profile.dart';
import '../l10n/app_strings.dart';

/// The words users see for the profile answers. The enums keep their API
/// names (`sedentary`, `maintain`, ...); this is only how they read on screen.
///
/// Plain language on purpose: "sedentary" and "maintain" confused people.
/// Each activity option says what a typical week looks like, because people
/// pick the level by recognising themselves, not by the label.
extension GenderCopy on Gender {
  String get title => switch (this) {
    Gender.female => tr('Female'),
    Gender.male => tr('Male'),
  };
}

extension ActivityLevelCopy on ActivityLevel {
  String get title => switch (this) {
    ActivityLevel.sedentary => tr('Mostly sitting'),
    ActivityLevel.light => tr('Lightly active'),
    ActivityLevel.moderate => tr('Moderately active'),
    ActivityLevel.active => tr('Very active'),
    ActivityLevel.veryActive => tr('Athlete level'),
  };

  String get blurb => switch (this) {
    ActivityLevel.sedentary => tr('Desk job or studying, and little or no exercise.'),
    ActivityLevel.light => tr('On your feet a fair bit, or exercise 1 to 3 days a week.'),
    ActivityLevel.moderate => tr('Exercise or sport 3 to 5 days a week.'),
    ActivityLevel.active => tr('Hard exercise 6 or 7 days a week, or a physical job.'),
    ActivityLevel.veryActive => tr('Intense training every day, or a very physical job.'),
  };

  IconData get icon => switch (this) {
    ActivityLevel.sedentary => CupertinoIcons.compass,
    ActivityLevel.light => CupertinoIcons.person_crop_circle,
    ActivityLevel.moderate => CupertinoIcons.heart,
    ActivityLevel.active => CupertinoIcons.bolt,
    ActivityLevel.veryActive => CupertinoIcons.flame,
  };
}

extension GoalCopy on Goal {
  String get title => switch (this) {
    Goal.lose => tr('Lose weight'),
    Goal.maintain => tr('Stay the same'),
    Goal.gain => tr('Gain weight'),
  };

  String get blurb => switch (this) {
    Goal.lose => tr('A small, steady daily cut. No crash diets.'),
    Goal.maintain => tr('Keep your weight steady and build good habits.'),
    Goal.gain => tr('A small daily boost to build up gradually.'),
  };

  IconData get icon => switch (this) {
    Goal.lose => CupertinoIcons.arrow_down_right_circle,
    Goal.maintain => CupertinoIcons.equal_circle,
    Goal.gain => CupertinoIcons.arrow_up_right_circle,
  };
}
