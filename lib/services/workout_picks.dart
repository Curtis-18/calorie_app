import '../models/mood.dart';
import '../models/workouts.dart';

/// Which routines to suggest for how someone feels. The ids are a hand-written
/// short list per feeling, in the order to offer them, never a claim that a
/// workout fixes a mood: the line under them just says what kind of session it
/// is. The feeling is never saved or sent anywhere.
const Map<Mood, List<String>> feelingPicks = {
  Mood.tired: ['reset_5', 'walk_10', 'flow_10', 'desk_2'],
  Mood.stressed: ['flow_10', 'stretch_10', 'walk_10', 'desk_2'],
  Mood.low: ['walk_10', 'dance_3', 'play_5', 'wake_3'],
  Mood.good: ['strength_20', 'cardio_20', 'dance_15', 'full_15'],
  Mood.comfort: ['stretch_10', 'flow_10', 'reset_5', 'walk_10'],
};

/// Up to [limit] routines from the library for [mood]. Routines the server no
/// longer has are skipped, so an older or newer server never breaks the row.
List<WorkoutCard> suggestFor(Mood mood, List<WorkoutCard> library, {int limit = 3}) {
  final byId = {for (final c in library) c.id: c};
  return [
    for (final id in feelingPicks[mood] ?? const <String>[])
      ?byId[id],
  ].take(limit).toList();
}

/// The length chips on the library. 0 means "any".
const List<int> lengthFilters = [0, 5, 10, 15, 20, 30];

/// Routines of up to [maxMinutes] (when set) in [slice] (when set), shortest first.
/// "Up to 10" shows the 10-minute ones and shorter bites too, so a short
/// session is never hidden by choosing a longer chip.
List<WorkoutCard> filterLibrary(List<WorkoutCard> all, {int maxMinutes = 0, MoveSlice? slice}) {
  final out = [
    for (final c in all)
      if ((maxMinutes == 0 || c.minutes <= maxMinutes) && (slice == null || c.slice == slice)) c,
  ];
  out.sort((a, b) => a.minutes != b.minutes ? a.minutes.compareTo(b.minutes) : a.id.compareTo(b.id));
  return out;
}

/// The "Move bites": the short ones, 2 to 5 minutes.
List<WorkoutCard> bitesOf(List<WorkoutCard> all) => filterLibrary(all, maxMinutes: 5);

/// A gentle nudge for the slice that has had the least this week, only among
/// the slices nothing was done in. Null when everything has had a turn or the
/// person hasn't started (no pressure on an empty week).
MoveSlice? sliceToTry(MoveWeek week) {
  if (week.minutes == 0) return null;
  final empty = [for (final s in MoveSlice.values) if (week.slice(s).minutes == 0) s];
  return empty.isEmpty ? null : empty.first;
}
