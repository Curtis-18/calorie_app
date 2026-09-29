import 'package:flutter/cupertino.dart';
import '../models/insights.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// Weekly calorie bars with a staggered spring grow, gradient fill and a
/// glowing "today" bar plus a dashed target line.
class WeeklyTrendChart extends StatefulWidget {
  const WeeklyTrendChart({super.key, required this.data, required this.target});

  final List<DayTrend> data;
  final int target;

  @override
  State<WeeklyTrendChart> createState() => _WeeklyTrendChartState();
}

class _WeeklyTrendChartState extends State<WeeklyTrendChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text('No data for this week yet', style: AppType.caption()),
        ),
      );
    }

    final maxValue = data
        .map((d) => d.calories)
        .fold<int>(widget.target, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 30);

    const chartHeight = 132.0;
    final targetFactor = widget.target / maxValue;

    return SizedBox(
      height: chartHeight + 22,
      child: Stack(
        children: [
          if (targetFactor > 0.04 && targetFactor < 1.0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 22 + chartHeight * targetFactor,
              child: Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: TrackerColors.alpha(TrackerColors.textPrimary, 0.18)),
                  ),
                  const SizedBox(width: 6),
                  Text('TARGET', style: AppType.caption(color: TrackerColors.textTertiary, size: 8)),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((day) {
              final factor = (day.calories / maxValue).clamp(0.0, 1.0);
              final isToday = _isSameDay(day.date, DateTime.now());
              final index = data.indexOf(day);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.calories > 0 ? _compact(day.calories) : '',
                        style: AppType.caption(
                          color: isToday ? TrackerColors.accentEnd : TrackerColors.textTertiary,
                          size: 9,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: chartHeight - 26,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final t = CurvedAnimation(
                              parent: _controller,
                              curve: Interval(
                                (index * 0.07).clamp(0.0, 0.6),
                                (0.45 + index * 0.07).clamp(0.5, 1.0),
                                curve: AppMotion.spring,
                              ),
                            ).value;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: (factor.clamp(0.02, 1.0) * t).clamp(0.0, 1.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isToday
                                          ? [TrackerColors.accentEnd, TrackerColors.accentStart]
                                          : [
                                              TrackerColors.alpha(TrackerColors.textPrimary, 0.22),
                                              TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: isToday
                                        ? AppDecor.glow(TrackerColors.accentStart, blur: 12, opacity: 0.35)
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weekdayLabel(day.date),
                        style: AppType.caption(
                          color: isToday ? TrackerColors.textPrimary : TrackerColors.textTertiary,
                          size: 10,
                        ).copyWith(fontWeight: isToday ? FontWeight.w800 : FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _compact(int value) =>
      value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toString();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayLabel(DateTime date) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[date.weekday - 1];
  }
}
