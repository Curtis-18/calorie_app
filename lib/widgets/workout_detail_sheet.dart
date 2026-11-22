import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../models/workouts.dart';
import '../screens/workout_player_screen.dart';
import '../services/workouts_service.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';
import 'move_icons.dart';

typedef WorkoutLoader = Future<WorkoutDetail> Function(String id);

/// A routine opened from the library: what is in it, the safety line, and Start.
Future<void> showWorkoutDetail(BuildContext context, WorkoutCard card, {WorkoutLoader? loader}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => WorkoutDetailSheet(card: card, loader: loader ?? WorkoutsService().detail),
  );
}

class WorkoutDetailSheet extends StatefulWidget {
  const WorkoutDetailSheet({super.key, required this.card, required this.loader});

  final WorkoutCard card;
  final WorkoutLoader loader;

  @override
  State<WorkoutDetailSheet> createState() => _WorkoutDetailSheetState();
}

class _WorkoutDetailSheetState extends State<WorkoutDetailSheet> {
  late Future<WorkoutDetail> _future = widget.loader(widget.card.id);

  void _start(WorkoutDetail detail) {
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    navigator.push(CupertinoPageRoute<void>(fullscreenDialog: true, builder: (_) => WorkoutPlayerScreen(workout: detail)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MoveIcon.slice(c.slice, size: 20, tile: true),
              const SizedBox(width: 12),
              Expanded(child: Text(c.name, key: const ValueKey('detail_name'), style: AppType.title())),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [tr('{n} min', {'n': '${c.minutes}'}), c.focus, c.levelLabel].where((x) => x.isNotEmpty).join(' · '),
            style: AppType.body(size: 14, color: TrackerColors.textSecondary),
          ),
          if (c.summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(c.summary, style: AppType.caption(size: 13)),
          ],
          FutureBuilder<WorkoutDetail>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 8),
                  child: Column(
                    children: [
                      Text(tr("Couldn't load this workout. Check your connection and try again."),
                          key: const ValueKey('detail_error'), style: AppType.body(size: 14, color: TrackerColors.textSecondary), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      AppButton.glass(
                        key: const ValueKey('detail_retry'),
                        label: tr('Try again'),
                        onPressed: () => setState(() => _future = widget.loader(widget.card.id)),
                      ),
                    ],
                  ),
                );
              }
              final d = snap.data;
              if (d == null) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Center(child: CupertinoActivityIndicator()));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final section in d.sections) ...[
                    const SizedBox(height: 16),
                    Text(section.title, style: AppType.body(size: 16, color: TrackerColors.textPrimary)),
                    if (section.repeat != null) ...[
                      const SizedBox(height: 2),
                      Text(section.repeat!, style: AppType.caption(size: 12)),
                    ],
                    for (final step in section.steps)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(step.name, style: AppType.body(size: 14.5, color: TrackerColors.textPrimary))),
                            const SizedBox(width: 12),
                            Text(step.amount, style: AppType.body(size: 13.5, color: TrackerColors.textSecondary)),
                          ],
                        ),
                      ),
                  ],
                  if (d.safety.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(d.safety, key: const ValueKey('detail_safety'), style: AppType.caption(size: 12)),
                  ],
                  const SizedBox(height: 16),
                  AppButton(key: const ValueKey('detail_start'), label: tr('Start'), icon: CupertinoIcons.play_fill, onPressed: () => _start(d)),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
