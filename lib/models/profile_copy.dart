import 'package:flutter/cupertino.dart';

import 'user_profile.dart';

/// The words users see for the profile answers. The enums keep their API
/// names (`sedentary`, `maintain`, ...); this is only how they read on screen.
///
/// Plain language on purpose: "sedentary" and "maintain" confused people.
/// Each activity option says what a typical week looks like, because people
/// pick the level by recognising themselves, not by the label.
extension GenderCopy on Gender {
  String get title => switch (this) {
    Gender.female => 'Female',
    Gender.male => 'Male',
  };
}

extension ActivityLevelCopy on ActivityLevel {
  String get title => switch (this) {
    ActivityLevel.sedentary => 'Mostly sitting',
    ActivityLevel.light => 'Lightly active',
    ActivityLevel.moderate => 'Moderately active',
    ActivityLevel.active => 'Very active',
    ActivityLevel.veryActive => 'Athlete level',
  };

  String get blurb => switch (this) {
    ActivityLevel.sedentary => 'Desk job or studying, and little or no exercise.',
    ActivityLevel.light => 'On your feet a fair bit, or exercise 1 to 3 days a week.',
    ActivityLevel.moderate => 'Exercise or sport 3 to 5 days a week.',
    ActivityLevel.active => 'Hard exercise 6 or 7 days a week, or a physical job.',
    ActivityLevel.veryActive => 'Intense training every day, or a very physical job.',
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
    Goal.lose => 'Lose weight',
    Goal.maintain => 'Stay the same',
    Goal.gain => 'Gain weight',
  };

  String get blurb => switch (this) {
    Goal.lose => 'A small, steady daily cut. No crash diets.',
    Goal.maintain => 'Keep your weight steady and build good habits.',
    Goal.gain => 'A small daily boost to build up gradually.',
  };

  IconData get icon => switch (this) {
    Goal.lose => CupertinoIcons.arrow_down_right_circle,
    Goal.maintain => CupertinoIcons.equal_circle,
    Goal.gain => CupertinoIcons.arrow_up_right_circle,
  };
}
