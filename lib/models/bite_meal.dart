/// The label a person can stamp on a bite so friends see which meal it is.
enum BiteMeal {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snack('Snack');

  const BiteMeal(this.label);
  final String label;

  /// The likely meal for a local hour (0-23), so the right chip is already
  /// picked when the camera opens.
  static BiteMeal forHour(int hour) {
    if (hour >= 5 && hour < 11) return breakfast;
    if (hour >= 11 && hour < 15) return lunch;
    if (hour >= 17 && hour < 22) return dinner;
    return snack;
  }
}
