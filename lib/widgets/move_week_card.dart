import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../models/workouts.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'move_icons.dart';

/// "Your week": minutes toward the weekly guide, the seven days, the four slices
/// of the Move plate and strength days. A rest day is just an empty dot: it
/// never counts against anyone (roadmap R2.3 and R9).
class MoveWeekCard extends StatelessWidget {
  const MoveWeekCard({super.key, required this.week, this.nudge, this.plateKey});

  final MoveWeek week;

  /// A slice nothing was done in yet, offered as a friendly idea (or null).
  final MoveSlice? nudge;

  /// Lets the Workouts tour point at the four slices.
  final GlobalKey? plateKey;

  /// Monday first, in the language on screen.
  static List<String> dayInitials([String? lang]) =>
      _initials[lang ?? AppStrings.active] ?? _initials['en']!;

  static const _initials = <String, List<String>>{
    'en': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    'es': ['L', 'M', 'X', 'J', 'V', 'S', 'D'],
    'fr': ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
    'de': ['M', 'D', 'M', 'D', 'F', 'S', 'S'],
    'pt': ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'],
    'it': ['L', 'M', 'M', 'G', 'V', 'S', 'D'],
  };

  @override
  Widget build(BuildContext context) {
    final days = dayInitials();
    return AppCard(
      key: const ValueKey('move_week'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _MinutesRing(progress: week.progress, track: TrackerColors.glassFill),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${week.minutes}', key: const ValueKey('week_minutes'), style: AppType.title().copyWith(fontSize: 26)),
                        Text(tr('min'), style: AppType.caption(size: 11)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('This week'), style: AppType.sectionLabel()),
                    const SizedBox(height: 4),
                    Text(
                      tr('{n} of {goal} min', {'n': '${week.minutes}', 'goal': '${week.goalMinutes}'}),
                      key: const ValueKey('week_goal'),
                      style: AppType.body(size: 15, color: TrackerColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('{n} of {goal} strength days', {'n': '${week.strengthDays}', 'goal': '${week.strengthDaysGoal}'}),
                      key: const ValueKey('week_strength'),
                      style: AppType.caption(size: 12.5),
                    ),
                    if (week.streak > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        week.streak == 1 ? tr('1 moved week') : tr('{n} moved weeks', {'n': '${week.streak}'}),
                        key: const ValueKey('week_streak'),
                        style: AppType.body(size: 13.5, color: TrackerColors.accentStartText),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            key: const ValueKey('week_days'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _Day(initial: days[i], moved: week.movedDays[i], today: i == week.todayIndex, future: i > week.todayIndex),
            ],
          ),
          const SizedBox(height: 16),
          Text(tr('Your move plate'), style: AppType.sectionLabel()),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: plateKey,
            child: Row(
              children: [
                for (final s in MoveSlice.values) ...[
                  Expanded(child: _SliceTile(slice: s, total: week.slice(s), suggested: nudge == s)),
                  if (s != MoveSlice.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (nudge != null) ...[
            const SizedBox(height: 10),
            Text(
              tr('Nothing in {slice} yet this week. Fancy a go?', {'slice': nudge!.label.toLowerCase()}),
              key: const ValueKey('week_nudge'),
              style: AppType.caption(size: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.initial, required this.moved, required this.today, required this.future});

  final String initial;
  final bool moved;
  final bool today;
  final bool future;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: moved ? TrackerColors.calorieGradient : null,
            color: moved ? null : TrackerColors.glassFill,
            border: today ? Border.all(color: TrackerColors.accentStartText, width: 1.5) : null,
          ),
          child: moved ? Icon(CupertinoIcons.checkmark, size: 15, color: TrackerColors.onAccent) : null,
        ),
        const SizedBox(height: 4),
        Text(initial, style: AppType.caption(size: 11, color: future ? TrackerColors.textTertiary : TrackerColors.textSecondary)),
      ],
    );
  }
}

class _SliceTile extends StatelessWidget {
  const _SliceTile({required this.slice, required this.total, required this.suggested});

  final MoveSlice slice;
  final SliceTotal total;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final lit = total.minutes > 0;
    return Container(
      key: ValueKey('slice_${slice.name}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: lit ? TrackerColors.accentWash : TrackerColors.glassFill,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: suggested ? TrackerColors.accentStartText : (lit ? TrackerColors.borderStrong : TrackerColors.border)),
      ),
      child: Column(
        children: [
          MoveIcon(slice.glyph, size: 24, color: lit ? slice.color : TrackerColors.textTertiary),
          const SizedBox(height: 4),
          Text(
            lit ? tr('{n} min', {'n': '${total.minutes}'}) : '-',
            style: AppType.body(size: 12.5, color: lit ? TrackerColors.textPrimary : TrackerColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _MinutesRing extends CustomPainter {
  _MinutesRing({required this.progress, required this.track});

  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [TrackerColors.flameStart, TrackerColors.flameEnd],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MinutesRing old) => old.progress != progress || old.track != track;
}
