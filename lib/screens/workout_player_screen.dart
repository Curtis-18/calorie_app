import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../models/workouts.dart';
import '../providers/house_recipes_provider.dart';
import '../providers/workouts_provider.dart';
import '../services/refuel_picks.dart';
import '../widgets/house_recipe_sheet.dart';
import '../services/player_engine.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';

/// Opens the player full screen, over the tab bar.
Future<void> openWorkoutPlayer(BuildContext context, WorkoutDetail workout) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(fullscreenDialog: true, builder: (_) => WorkoutPlayerScreen(workout: workout)),
  );
}

/// The guided session: one move per screen, a big ring for timed moves, a big
/// Done for rep moves, automatic rests, "next up", pause, and a plain finish
/// summary that saves what was actually done (roadmap R9).
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  const WorkoutPlayerScreen({super.key, required this.workout, this.tickEvery = const Duration(seconds: 1)});

  final WorkoutDetail workout;

  /// Tests make this shorter; the app always uses one second.
  final Duration tickEvery;

  @override
  ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

enum _Saving { idle, saving, saved, failed }

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen> {
  late final PlayerEngine _engine = PlayerEngine(widget.workout.play);
  Timer? _timer;
  _Saving _saving = _Saving.idle;
  MovementEntry? _saved;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tickEvery, (_) => _handle(_engine.tick()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handle(PlayerEvent event) {
    switch (event) {
      case PlayerEvent.countdown:
        HapticFeedback.selectionClick();
      case PlayerEvent.stepChanged:
        HapticFeedback.mediumImpact();
      case PlayerEvent.finished:
        HapticFeedback.heavyImpact();
        _timer?.cancel();
        unawaited(_save());
      case PlayerEvent.none:
        break;
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final minutes = _engine.minutesDone;
    if (minutes < 1 || _saving == _Saving.saving || _saving == _Saving.saved) return;
    setState(() => _saving = _Saving.saving);
    final entry = await ref.read(moveProvider.notifier).log(minutes: minutes, routineId: widget.workout.card.id);
    if (!mounted) return;
    setState(() {
      _saved = entry;
      _saving = entry == null ? _Saving.failed : _Saving.saved;
    });
  }

  Future<void> _close() async {
    if (_engine.finished || _engine.minutesDone < 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _engine.paused = true);
    final choice = await showAppSheet<String>(
      context: context,
      builder: (ctx) => AppSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Stop here?'), style: AppType.title()),
            const SizedBox(height: 6),
            Text(
              tr('You can save what you did so far. {n} min.', {'n': '${_engine.minutesDone}'}),
              style: AppType.body(size: 14, color: TrackerColors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppButton(key: const ValueKey('stop_save'), label: tr('Save and finish'), onPressed: () => Navigator.pop(ctx, 'save')),
            const SizedBox(height: 8),
            AppButton.glass(key: const ValueKey('stop_keep'), label: tr('Keep going'), onPressed: () => Navigator.pop(ctx, 'keep')),
            const SizedBox(height: 8),
            AppButton.glass(key: const ValueKey('stop_discard'), label: tr("Don't save"), onPressed: () => Navigator.pop(ctx, 'discard')),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'save':
        _timer?.cancel();
        setState(() => _engine.finished = true);
        await _save();
      case 'discard':
        Navigator.of(context).pop();
      default:
        setState(() => _engine.paused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      child: SafeArea(
        child: _engine.finished
            ? _Summary(
                workout: widget.workout,
                minutes: _engine.minutesDone,
                saving: _saving,
                saved: _saved,
                onRetry: _save,
                onDone: () => Navigator.of(context).pop(),
              )
            : _Playing(
                engine: _engine,
                workout: widget.workout,
                onClose: _close,
                onChanged: _handle,
              ),
      ),
    );
  }
}

class _Playing extends StatelessWidget {
  const _Playing({required this.engine, required this.workout, required this.onClose, required this.onChanged});

  final PlayerEngine engine;
  final WorkoutDetail workout;
  final VoidCallback onClose;
  final void Function(PlayerEvent) onChanged;

  String _sectionLabel(PlayStep step) => switch (step.section) {
        'warm' => tr('Warm-up'),
        'cool' => tr('Cool-down'),
        _ => step.round != null && workout.rounds > 1
            ? tr('Round {n} of {total}', {'n': '${step.round}', 'total': '${workout.rounds}'})
            : tr('Main moves'),
      };

  @override
  Widget build(BuildContext context) {
    final step = engine.current;
    final ready = engine.isGettingReady;
    final next = engine.nextMove;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Pressable(
                key: const ValueKey('player_close'),
                onTap: onClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: TrackerColors.glassFill, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.xmark, size: 18, color: TrackerColors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Stack(children: [
                      Container(color: TrackerColors.glassFill),
                      FractionallySizedBox(
                        widthFactor: engine.progress.clamp(0.0, 1.0),
                        child: Container(
                          key: const ValueKey('player_progress'),
                          decoration: const BoxDecoration(gradient: TrackerColors.calorieGradient),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            ready ? workout.card.name : _sectionLabel(step),
            key: const ValueKey('player_section'),
            style: AppType.sectionLabel(),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          if (ready)
            _GetReady(seconds: engine.getReady, first: engine.steps.first)
          else
            _StepView(
              engine: engine,
              step: step,
              onDone: () => onChanged(engine.done()),
              onMoreRest: () {
                engine.extendRest();
                onChanged(PlayerEvent.none);
              },
            ),
          const Spacer(),
          if (!ready && next != null && !engine.isRest)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                tr('Next: {name}', {'name': next.name}),
                key: const ValueKey('player_next'),
                style: AppType.body(size: 14, color: TrackerColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          if (!ready && engine.isRest && next != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                tr('Up next: {name}', {'name': next.name}),
                key: const ValueKey('player_next'),
                style: AppType.body(size: 15, color: TrackerColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                key: const ValueKey('player_back'),
                icon: CupertinoIcons.backward_end_fill,
                label: tr('Back'),
                onTap: () => onChanged(engine.back()),
              ),
              const SizedBox(width: 22),
              _RoundButton(
                key: const ValueKey('player_pause'),
                icon: engine.paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                label: engine.paused ? tr('Resume') : tr('Pause'),
                big: true,
                onTap: () {
                  engine.togglePause();
                  onChanged(PlayerEvent.none);
                },
              ),
              const SizedBox(width: 22),
              _RoundButton(
                key: const ValueKey('player_skip'),
                icon: CupertinoIcons.forward_end_fill,
                label: tr('Skip'),
                onTap: () => onChanged(engine.skip()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GetReady extends StatelessWidget {
  const _GetReady({required this.seconds, required this.first});

  final int seconds;
  final PlayStep first;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Get ready'), style: AppType.title(), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('$seconds', key: const ValueKey('player_get_ready'), style: AppType.display(size: 96)),
        const SizedBox(height: 12),
        Text(first.name, style: AppType.body(size: 16, color: TrackerColors.textSecondary), textAlign: TextAlign.center),
      ],
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.engine, required this.step, required this.onDone, required this.onMoreRest});

  final PlayerEngine engine;
  final PlayStep step;
  final VoidCallback onDone;
  final VoidCallback onMoreRest;

  String? get _sideLabel => switch (step.side) {
        1 => tr('First side'),
        2 => tr('Other side'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final isRest = step.mode == StepMode.rest;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(step.name, key: const ValueKey('player_name'), style: AppType.title().copyWith(fontSize: 28), textAlign: TextAlign.center),
        if (_sideLabel != null) ...[
          const SizedBox(height: 6),
          Text(_sideLabel!, key: const ValueKey('player_side'), style: AppType.body(size: 16, color: TrackerColors.accentStartText)),
        ],
        const SizedBox(height: 22),
        if (step.mode == StepMode.reps) ...[
          Text('${step.reps}', key: const ValueKey('player_reps'), style: AppType.display(size: 110)),
          Text(step.amount.replaceFirst(RegExp(r'^\d+\s*'), ''), style: AppType.body(size: 16, color: TrackerColors.textSecondary)),
          const SizedBox(height: 22),
          AppButton(key: const ValueKey('player_done'), label: tr('Done'), expand: false, onPressed: onDone),
        ] else ...[
          SizedBox(
            width: 230,
            height: 230,
            child: CustomPaint(
              painter: _RingPainter(
                progress: engine.stepProgress,
                track: TrackerColors.glassFill,
                colors: isRest
                    ? [TrackerColors.freeze, TrackerColors.freeze]
                    : [TrackerColors.flameStart, TrackerColors.flameEnd],
              ),
              child: Center(
                child: Text(_clock(engine.remaining), key: const ValueKey('player_time'), style: AppType.display(size: 64)),
              ),
            ),
          ),
          if (isRest) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton.glass(
                  key: const ValueKey('player_more_rest'),
                  label: tr('+20 s'),
                  expand: false,
                  height: 44,
                  onPressed: onMoreRest,
                ),
              ],
            ),
          ],
        ],
        if (step.cue.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(step.cue, key: const ValueKey('player_cue'), style: AppType.body(size: 14.5, color: TrackerColors.textSecondary), textAlign: TextAlign.center),
        ],
      ],
    );
  }

  static String _clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    return s >= 60 ? '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}' : '$s';
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.colors});

  final double progress;
  final Color track;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: colors.length == 1 ? [colors.first, colors.first] : colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.label, required this.onTap, this.big = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 72.0 : 52.0;
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        haptics: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: big ? null : TrackerColors.glassFill,
            gradient: big ? TrackerColors.calorieGradient : null,
          ),
          child: Icon(icon, size: big ? 30 : 22, color: big ? TrackerColors.onAccent : TrackerColors.textPrimary),
        ),
      ),
    );
  }
}

/// The finish screen. Plain and warm: what was done, that it is saved, and, only
/// when the weight is known, a rough estimate that is never added to the day's
/// calories (roadmap R2.3: movement is never a payment for food).
class _Summary extends ConsumerWidget {
  const _Summary({
    required this.workout,
    required this.minutes,
    required this.saving,
    required this.saved,
    required this.onRetry,
    required this.onDone,
  });

  final WorkoutDetail workout;
  final int minutes;
  final _Saving saving;
  final MovementEntry? saved;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kcal = saved?.estKcal;
    final ideas = refuelIdeas(ref.watch(houseRecipesProvider).recipes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        children: [
          const Spacer(),
          Text(workout.card.slice.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 14),
          Text(tr('Nice moving'), key: const ValueKey('summary_title'), style: AppType.title().copyWith(fontSize: 30), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(workout.card.name, style: AppType.body(size: 15, color: TrackerColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 26),
          Text(
            minutes < 1 ? '-' : tr('{n} min', {'n': '$minutes'}),
            key: const ValueKey('summary_minutes'),
            style: AppType.display(size: 56),
          ),
          Text(workout.card.slice.label, style: AppType.body(size: 15, color: TrackerColors.textSecondary)),
          if (kcal != null && kcal > 0) ...[
            const SizedBox(height: 18),
            Text(tr('About {n} kcal (a rough estimate)', {'n': '$kcal'}), key: const ValueKey('summary_kcal'), style: AppType.body(size: 14)),
            const SizedBox(height: 4),
            Text(
              ref.watch(moveProvider.select((m) => m.week.eatBackPercent)) > 0
                  ? tr('Part of this is added to today’s plan, as you chose.')
                  : tr("This isn't added to your daily calories."),
              key: const ValueKey('summary_kcal_note'),
              style: AppType.caption(size: 12.5),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          switch (saving) {
            _Saving.saved => Text(tr('Added to your week'), key: const ValueKey('summary_saved'), style: AppType.body(size: 14, color: TrackerColors.success)),
            _Saving.failed => AppButton.glass(
                key: const ValueKey('summary_retry'),
                label: tr("Couldn't save. Try again"),
                expand: false,
                height: 44,
                onPressed: onRetry,
              ),
            _Saving.saving => const CupertinoActivityIndicator(),
            _Saving.idle => const SizedBox.shrink(),
          },
          if (ideas.isNotEmpty) ...[
            const SizedBox(height: 22),
            Align(alignment: Alignment.centerLeft, child: Text(tr('Ideas for your next meal'), style: AppType.sectionLabel())),
            const SizedBox(height: 2),
            Align(alignment: Alignment.centerLeft, child: Text(tr('From your recipes, higher in protein.'), style: AppType.caption(size: 12.5))),
            const SizedBox(height: 8),
            for (final r in ideas)
              Pressable(
                key: ValueKey('refuel_${r.id}'),
                onTap: () => showHouseRecipeSheet(context, r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14.5, color: TrackerColors.textPrimary))),
                      Text(tr('{p} g protein', {'p': '${r.proteinG.round()}'}), style: AppType.body(size: 13, color: TrackerColors.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
          const Spacer(),
          AppButton(key: const ValueKey('summary_done'), label: tr('Done'), onPressed: onDone),
        ],
      ),
    );
  }
}
