/// The calories the Today ring counts toward.
///
/// Start from the flexible weekly allowance when it is on (today only), else the
/// profile's daily target, else 2000. Then add the movement the person chose to
/// add to their plan: today only, and only when they turned it on, so every
/// other day and everyone who left it Off is unchanged.
int dayCalorieTarget({
  required bool isToday,
  required int? weeklyAllowanceToday,
  required int? profileTarget,
  required int movementExtra,
}) {
  final base = (isToday ? weeklyAllowanceToday : null) ?? profileTarget ?? 2000;
  final extra = isToday && movementExtra > 0 ? movementExtra : 0;
  return base + extra;
}
