import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../models/messages.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

/// A routine the coach named: warm-up, main moves, cool-down and the safety
/// line, all words written by the server in the person's language.
Future<void> showWorkoutSheet(BuildContext context, CoachWorkout workout) {
  return showAppSheet<void>(context: context, builder: (_) => WorkoutSheet(workout: workout));
}

class WorkoutSheet extends StatelessWidget {
  const WorkoutSheet({super.key, required this.workout});

  final CoachWorkout workout;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.name, key: const ValueKey('workout_name'), style: AppType.title()),
          const SizedBox(height: 4),
          Text([w.duration, w.focus].where((x) => x.isNotEmpty).join(' · '),
              style: AppType.body(size: 14, color: TrackerColors.textSecondary)),
          if (w.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(w.summary, style: AppType.caption(size: 13)),
          ],
          for (final section in w.sections) ...[
            const SizedBox(height: 18),
            Text(section.title, style: AppType.body(size: 16, color: TrackerColors.textPrimary)),
            if (section.repeat != null) ...[
              const SizedBox(height: 2),
              Text(section.repeat!, key: const ValueKey('workout_repeat'), style: AppType.caption(size: 12)),
            ],
            for (final step in section.steps)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(step.name, style: AppType.body(size: 15, color: TrackerColors.textPrimary))),
                        const SizedBox(width: 12),
                        Text(step.amount, style: AppType.body(size: 14, color: TrackerColors.textSecondary)),
                      ],
                    ),
                    if (step.cue.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(step.cue, style: AppType.caption(size: 12.5)),
                    ],
                  ],
                ),
              ),
          ],
          if (w.safety.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(w.safety, key: const ValueKey('workout_safety'), style: AppType.caption(size: 12)),
          ],
          const SizedBox(height: 16),
          AppButton(key: const ValueKey('workout_done'), label: tr('Done'), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
