import '../models/food_entry.dart';

/// Saves several entries side by side and tells which ones did NOT save.
///
/// A scanned meal is several entries. Awaiting them with a bare `Future.wait`
/// turns one refused item into an error for the whole meal, even though the
/// others were saved, and a retry of "the meal" then duplicates those. Here
/// each entry succeeds or fails on its own; [add] must undo its own optimistic
/// change when it throws (the log provider does).
///
/// Returns the failed entries in their original order (empty when all saved).
Future<List<FoodEntry>> saveEntriesIndependently(
  List<FoodEntry> entries,
  Future<void> Function(FoodEntry entry) add,
) async {
  final failed = List<bool>.filled(entries.length, false);
  await Future.wait([
    for (var i = 0; i < entries.length; i++)
      () async {
        try {
          await add(entries[i]);
        } catch (_) {
          failed[i] = true;
        }
      }(),
  ]);
  return [for (var i = 0; i < entries.length; i++) if (failed[i]) entries[i]];
}

/// The names of failed entries for a message: the first few, then "+N".
String failedItemNames(List<FoodEntry> failed, {int max = 4}) {
  final names = failed.map((e) => e.name.trim()).where((n) => n.isNotEmpty).toList();
  if (names.isEmpty) return '';
  final shown = names.take(max).join(', ');
  return names.length > max ? '$shown +${names.length - max}' : shown;
}
