import 'package:calorie_app/models/mood.dart';
import 'package:calorie_app/models/workouts.dart';
import 'package:calorie_app/services/workout_picks.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutCard card(String id, int minutes, MoveSlice slice) =>
    WorkoutCard(id: id, name: id, minutes: minutes, focus: '', slice: slice, level: 'easy', levelLabel: 'Easy', summary: '');

final library = [
  card('walk_15', 15, MoveSlice.cardio),
  card('desk_2', 2, MoveSlice.mobility),
  card('reset_5', 5, MoveSlice.mobility),
  card('walk_10', 10, MoveSlice.cardio),
  card('strength_20', 20, MoveSlice.strength),
  card('dance_3', 3, MoveSlice.fun),
];

void main() {
  test('each feeling gets its own short list, in order, skipping ones the server does not have', () {
    expect(suggestFor(Mood.tired, library).map((c) => c.id), ['reset_5', 'walk_10', 'desk_2']);
    expect(suggestFor(Mood.good, library).map((c) => c.id), ['strength_20']);
    expect(suggestFor(Mood.low, library, limit: 1).map((c) => c.id), ['walk_10']);
  });

  test('every feeling has suggestions and none of them names a hard session for tired or low', () {
    for (final m in Mood.values) {
      expect(feelingPicks[m], isNotEmpty);
    }
    for (final m in [Mood.tired, Mood.low, Mood.stressed, Mood.comfort]) {
      expect(feelingPicks[m]!.any((id) => id.startsWith('strength')), isFalse, reason: '$m');
    }
  });

  test('an empty library suggests nothing', () {
    expect(suggestFor(Mood.tired, const []), isEmpty);
  });

  test('a length filter keeps that length and the shorter ones, shortest first', () {
    expect(filterLibrary(library, maxMinutes: 10).map((c) => c.id), ['desk_2', 'dance_3', 'reset_5', 'walk_10']);
    expect(filterLibrary(library).length, library.length);
    expect(filterLibrary(library).first.id, 'desk_2');
  });

  test('the slice filter combines with the length', () {
    expect(filterLibrary(library, slice: MoveSlice.cardio).map((c) => c.id), ['walk_10', 'walk_15']);
    expect(filterLibrary(library, maxMinutes: 10, slice: MoveSlice.cardio).map((c) => c.id), ['walk_10']);
    expect(filterLibrary(library, slice: MoveSlice.strength, maxMinutes: 5), isEmpty);
  });

  test('bites are the 2 to 5 minute ones', () {
    expect(bitesOf(library).map((c) => c.id), ['desk_2', 'dance_3', 'reset_5']);
  });

  test('the slice to try is only offered once the week has started, and only for an empty slice', () {
    expect(sliceToTry(const MoveWeek()), isNull);
    expect(sliceToTry(const MoveWeek(minutes: 20, bySlice: {MoveSlice.cardio: SliceTotal(minutes: 20, sessions: 1)})), MoveSlice.strength);
    expect(
      sliceToTry(const MoveWeek(minutes: 40, bySlice: {
        MoveSlice.strength: SliceTotal(minutes: 10, sessions: 1),
        MoveSlice.cardio: SliceTotal(minutes: 10, sessions: 1),
        MoveSlice.mobility: SliceTotal(minutes: 10, sessions: 1),
        MoveSlice.fun: SliceTotal(minutes: 10, sessions: 1),
      })),
      isNull,
    );
  });
}
