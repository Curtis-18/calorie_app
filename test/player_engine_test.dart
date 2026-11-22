import 'package:calorie_app/models/workouts.dart';
import 'package:calorie_app/services/player_engine.dart';
import 'package:flutter_test/flutter_test.dart';

PlayStep timed(int s, {String name = 'Move', int? side}) =>
    PlayStep(mode: StepMode.timed, name: name, cue: '', amount: '$s s', section: 'main', seconds: s, side: side);
PlayStep reps(int n) => PlayStep(mode: StepMode.reps, name: 'Squat', cue: '', amount: '$n reps', section: 'main', reps: n);
PlayStep rest(int s) => PlayStep(mode: StepMode.rest, name: 'Rest', cue: '', amount: '$s s', section: 'main', seconds: s);

void runTicks(PlayerEngine e, int n) {
  for (var i = 0; i < n; i++) {
    e.tick();
  }
}

void main() {
  test('a short get-ready countdown comes first and does not count as time spent', () {
    final e = PlayerEngine([timed(10)]);
    expect(e.isGettingReady, isTrue);
    expect(e.tick(), PlayerEvent.countdown);
    expect(e.tick(), PlayerEvent.countdown);
    expect(e.tick(), PlayerEvent.stepChanged);
    expect(e.isGettingReady, isFalse);
    expect(e.elapsedSeconds, 0);
    expect(e.remaining, 10);
  });

  test('a timed move counts down, then moves on by itself', () {
    final e = PlayerEngine([timed(5), timed(4)], getReadySeconds: 0);
    runTicks(e, 4);
    expect(e.index, 0);
    expect(e.remaining, 1);
    expect(e.tick(), PlayerEvent.stepChanged);
    expect(e.index, 1);
    expect(e.remaining, 4);
    expect(e.elapsedSeconds, 5);
  });

  test('the last three seconds ask for a beep', () {
    final e = PlayerEngine([timed(6)], getReadySeconds: 0);
    final events = [for (var i = 0; i < 5; i++) e.tick()];
    expect(events, [PlayerEvent.none, PlayerEvent.none, PlayerEvent.countdown, PlayerEvent.countdown, PlayerEvent.countdown]);
    expect(e.tick(), PlayerEvent.finished);
  });

  test('a rep move waits for Done, however long it takes, and the time still counts', () {
    final e = PlayerEngine([reps(10), timed(3)], getReadySeconds: 0);
    runTicks(e, 40);
    expect(e.index, 0);
    expect(e.elapsedSeconds, 40);
    expect(e.done(), PlayerEvent.stepChanged);
    expect(e.index, 1);
  });

  test('Done does nothing on a timed move or during the countdown', () {
    final e = PlayerEngine([timed(5), reps(5)]);
    expect(e.done(), PlayerEvent.none);
    e.skip(); // end of get ready
    expect(e.done(), PlayerEvent.none);
    expect(e.index, 0);
  });

  test('pausing stops the clock and the count of time', () {
    final e = PlayerEngine([timed(10)], getReadySeconds: 0);
    runTicks(e, 3);
    e.togglePause();
    runTicks(e, 50);
    expect(e.remaining, 7);
    expect(e.elapsedSeconds, 3);
    e.togglePause();
    e.tick();
    expect(e.remaining, 6);
  });

  test('a rest can be skipped or made longer, but a move cannot be lengthened', () {
    final e = PlayerEngine([rest(20), timed(5)], getReadySeconds: 0);
    e.extendRest();
    expect(e.remaining, 40);
    expect(e.skip(), PlayerEvent.stepChanged);
    expect(e.index, 1);
    e.extendRest();
    expect(e.remaining, 5);
  });

  test('next up skips rests and is null at the last move', () {
    final e = PlayerEngine([timed(5, name: 'A'), rest(20), timed(5, name: 'B')], getReadySeconds: 0);
    expect(e.nextMove?.name, 'B');
    e.skip();
    e.skip();
    expect(e.nextMove, isNull);
  });

  test('going back lands on the previous move, not on the rest before it', () {
    final e = PlayerEngine([timed(5, name: 'A'), rest(20), timed(5, name: 'B')], getReadySeconds: 0);
    e.skip();
    e.skip();
    expect(e.index, 2);
    expect(e.back(), PlayerEvent.stepChanged);
    expect(e.current.name, 'A');
    expect(e.remaining, 5);
    expect(e.back(), PlayerEvent.none);
  });

  test('finishing the last move ends the session and reports the time', () {
    final e = PlayerEngine([timed(60), timed(60)], getReadySeconds: 0);
    runTicks(e, 119);
    expect(e.finished, isFalse);
    expect(e.tick(), PlayerEvent.finished);
    expect(e.finished, isTrue);
    expect(e.progress, 1);
    expect(e.minutesDone, 2);
    // Nothing moves a finished session.
    expect(e.tick(), PlayerEvent.none);
    expect(e.skip(), PlayerEvent.none);
  });

  test('minutes done round to the nearest and are at least one once anything was done', () {
    PlayerEngine at(int seconds) {
      final e = PlayerEngine([reps(5)], getReadySeconds: 0);
      runTicks(e, seconds);
      return e;
    }

    expect(at(0).minutesDone, 0);
    expect(at(5).minutesDone, 1);
    expect(at(89).minutesDone, 1);
    expect(at(90).minutesDone, 2);
    expect(at(600).minutesDone, 10);
  });

  test('the ring fills as a timed move goes', () {
    final e = PlayerEngine([timed(10)], getReadySeconds: 0);
    expect(e.stepProgress, 0);
    runTicks(e, 5);
    expect(e.stepProgress, 0.5);
  });
}
