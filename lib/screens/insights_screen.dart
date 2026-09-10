import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/insights_provider.dart';
import '../providers/user_provider.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/weekly_trend_chart.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final profile = ref.watch(userProfileProvider);
    final target = profile?.calorieTarget ?? 2000;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Insights'),
        trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.refresh),
            onPressed: insightsAsync.isLoading
                ? null
                : () => ref.read(insightsProvider.notifier).load(refresh: true),
            ),
      ),
      child: insightsAsync.when(
        loading: () => const Center(
          child: CupertinoActivityIndicator(color: TrackerColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load insights.\n$err',
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.textStyle,
            ),
          ),
        ),
        data: (insights) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.sparkles, color: TrackerColors.primary, size: 28),
                  const SizedBox(height: 12),
                  Text(insights.narrative, style: CupertinoTheme.of(context).textTheme.textStyle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WEEK',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  WeeklyTrendChart(data: insights.weeklyTrend, target: target),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIPS',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...insights.tips.map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(CupertinoIcons.check_mark_circled,
                                color: TrackerColors.secondary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(tip, style: CupertinoTheme.of(context).textTheme.textStyle),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}