import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: TrackerColors.background,
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: TrackerColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: insightsAsync.isLoading
                ? null
                : () => ref.read(insightsProvider.notifier).load(refresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: insightsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: TrackerColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load insights.\n$err',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
                  const Icon(Icons.auto_awesome, color: TrackerColors.primary, size: 28),
                  const SizedBox(height: 12),
                  Text(insights.narrative, style: Theme.of(context).textTheme.bodyLarge),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                            const Icon(Icons.check_circle_outline,
                                color: TrackerColors.secondary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(tip, style: Theme.of(context).textTheme.bodyMedium),
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