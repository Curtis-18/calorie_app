import 'package:flutter/cupertino.dart';

import '../models/weekly_report.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../theme/app_shapes.dart';
import 'app_card.dart';

/// "Your week": how many days were logged, how many reached the protein goal,
/// and up to two habit patterns with a positive tip. Neutral colours; never a
/// lowest day, never a suggestion to eat less.
class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({super.key, required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final protein = report.proteinGoalDays;
    return AppCard(
      key: const ValueKey('weekly_report'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(label: 'Your week'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _Stat(value: '${report.daysLogged} of 7', label: 'days logged')),
              if (protein != null) Expanded(child: _Stat(value: '$protein', label: protein == 1 ? 'day at your protein goal' : 'days at your protein goal')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(report.message, style: AppType.body(size: 14, color: TrackerColors.textSecondary)),
          for (final p in report.patterns) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              key: ValueKey('pattern_${p.id}'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TrackerColors.alpha(TrackerColors.accentEnd, 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TrackerColors.alpha(TrackerColors.accentEnd, 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.text, style: AppType.body(size: 14)),
                  if (p.tip.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.tip, style: AppType.callout(size: 13)),
                  ],
                ],
              ),
            ),
          ],
          if (!report.enoughData && report.patterns.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Habit patterns show up after about two weeks of logging'
              '${report.daysNeeded > 0 ? ' (around ${report.daysNeeded} more logged days)' : ''}.',
              key: const ValueKey('patterns_waiting'),
              style: AppType.caption(size: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppType.title()),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption(size: 12)),
        ],
      );
}
