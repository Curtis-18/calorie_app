import 'package:flutter/material.dart';
import '../models/insights.dart';
import '../theme/tracker_colors.dart';

class WeeklyTrendChart extends StatelessWidget {
  final List<DayTrend> data;
  final int target;

  const WeeklyTrendChart({super.key, required this.data, required this.target});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.map((d) => d.calories).fold<int>(target, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((day) {
          final heightFactor = maxValue == 0 ? 0.0 : day.calories / maxValue;
          final isToday = _isSameDay(day.date, DateTime.now());
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Text(
                    day.calories > 0 ? day.calories.toString() : '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor.clamp(0.03, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isToday
                                ? TrackerColors.primary
                                : TrackerColors.secondary.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _weekdayLabel(day.date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: TrackerColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayLabel(DateTime date) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[date.weekday - 1];
  }
}