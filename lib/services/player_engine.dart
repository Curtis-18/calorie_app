import '../models/workouts.dart';

/// What just happened, so the screen can buzz or beep at the right moments.
enum PlayerEvent { none, countdown, stepChanged, finished }

/// The workout player's brain, with no clock of its own: the screen calls
/// [tick] once a second. Keeping it plain makes every rule easy to test.
///
/// A timed move counts down by itself and moves on at zero. A rep move waits
/// for "Done". A rest counts down and can be skipped or lengthened. Time spent
/// is counted whenever the player is running and not paused, so what gets
/// logged is what the person actually did.
class PlayerEngine {
  PlayerEngine(this.steps, {this.getReadySeconds = 3})
      : assert(steps.isNotEmpty),
        getReady = getReadySeconds,
        remaining = steps.first.seconds ?? 0;

  final List<PlayStep> steps;
  final int getReadySeconds;

  /// How long a rest grows by when the person asks for more.
  static const int restExtra = 20;

  /// Seconds left of the "3, 2, 1" before the first move.
  int getReady;
  int index = 0;

  /// Seconds left on a timed move or rest (0 for a rep move).
  int remaining;
  bool paused = false;
  bool finished = false;
  int elapsedSeconds = 0;

  /// Names of the moves switched to their easier version, for this workout
  /// only (never saved). By name, so the same move in a later round starts
  /// easier too; the person can switch back on any step.
  final Set<String> _easier = {};

  /// Reps the person set with minus / plus on a rep step, by step index (the
  /// prescribed number until they change it).
  final Map<int, int> _repsAt = {};

  /// Rep moves of the main part finished with "Done": (move id, reps), by
  /// step index. Sent with the session so next time can say "Last time: 12".
  final Map<int, ({String move, int reps})> _done = {};

  /// Most reps one set can record (the server accepts 1 to 500).
  static const int maxReps = 500;

  PlayStep get _plain => steps[index.clamp(0, steps.length - 1)];

  /// What to show and time now: the step, or its easier version if chosen.
  PlayStep get current {
    final step = _plain;
    final gentler = step.easier;
    return gentler != null && _easier.contains(step.name) ? gentler : step;
  }

  /// Whether this step has an easier version to switch to (or back from).
  bool get canEase => !finished && !isGettingReady && _plain.easier != null;

  /// Whether the easier version is the one showing.
  bool get isEased => canEase && _easier.contains(_plain.name);

  /// "Easier version" / "Usual version": swap this move (and the same move in
  /// later rounds). A timed move starts its countdown again at the new length.
  PlayerEvent toggleEasier() {
    if (!canEase) return PlayerEvent.none;
    final name = _plain.name;
    if (!_easier.remove(name)) _easier.add(name);
    remaining = current.seconds ?? 0;
    _repsAt.remove(index); // a different move: back to its own number
    return PlayerEvent.stepChanged;
  }

  /// The reps shown on a rep step: what the person set, else the plan.
  int get currentReps => _repsAt[index] ?? current.reps ?? 0;

  /// Minus / plus on a rep step: how many they actually did (1 to [maxReps]).
  void adjustReps(int delta) {
    if (finished || isGettingReady || current.mode != StepMode.reps) return;
    _repsAt[index] = (currentReps + delta).clamp(1, maxReps);
  }

  /// The main part's rep sets finished so far, in order.
  List<({String move, int reps})> get sets => [for (final i in _done.keys.toList()..sort()) _done[i]!];

  /// The next move to do, skipping rests ("Next up").
  PlayStep? get nextMove {
    for (var i = index + 1; i < steps.length; i++) {
      if (steps[i].mode != StepMode.rest) return steps[i];
    }
    return null;
  }

  bool get isGettingReady => getReady > 0 && !finished;
  bool get isRest => current.mode == StepMode.rest;

  /// 0.0 at the start to 1.0 at the end, by moves completed.
  double get progress => finished ? 1 : index / steps.length;

  /// 0.0 (just started) to 1.0 (about to finish) for the ring on a timed step.
  double get stepProgress {
    final total = current.seconds;
    if (finished || total == null || total <= 0) return 0;
    return ((total - remaining) / total).clamp(0.0, 1.0);
  }

  /// Whole minutes done so far, rounded to the nearest, never below 1 once anything was done.
  int get minutesDone => elapsedSeconds <= 0 ? 0 : ((elapsedSeconds + 30) ~/ 60).clamp(1, 600);

  PlayerEvent tick() {
    if (paused || finished) return PlayerEvent.none;
    if (getReady > 0) {
      getReady--;
      return getReady == 0 ? PlayerEvent.stepChanged : PlayerEvent.countdown;
    }
    elapsedSeconds++;
    if (current.mode == StepMode.reps) return PlayerEvent.none;
    remaining--;
    if (remaining <= 0) return _advance();
    return remaining <= 3 ? PlayerEvent.countdown : PlayerEvent.none;
  }

  /// "Done" on a rep move.
  PlayerEvent done() {
    if (finished || isGettingReady || current.mode != StepMode.reps) return PlayerEvent.none;
    final move = current.move;
    if (move != null && current.section == 'main') _done[index] = (move: move, reps: currentReps);
    return _advance();
  }

  /// Skip whatever is on screen (a rest, or a move that can't be done today).
  PlayerEvent skip() {
    if (finished) return PlayerEvent.none;
    if (isGettingReady) {
      getReady = 0;
      return PlayerEvent.stepChanged;
    }
    return _advance();
  }

  /// Back to the start of the previous move.
  PlayerEvent back() {
    if (finished || isGettingReady || index == 0) return PlayerEvent.none;
    index--;
    // Going back over a rest would only be a wait; land on the move before it.
    if (steps[index].mode == StepMode.rest && index > 0) index--;
    remaining = current.seconds ?? 0;
    return PlayerEvent.stepChanged;
  }

  void extendRest() {
    if (isRest && !finished) remaining += restExtra;
  }

  void togglePause() {
    if (!finished) paused = !paused;
  }

  PlayerEvent _advance() {
    index++;
    if (index >= steps.length) {
      index = steps.length - 1;
      finished = true;
      remaining = 0;
      return PlayerEvent.finished;
    }
    remaining = current.seconds ?? 0;
    return PlayerEvent.stepChanged;
  }
}
