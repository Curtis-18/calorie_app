import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/insights_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';
import '../widgets/weekly_trend_chart.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final profile = ref.watch(userProfileProvider);
    final target = profile?.calorieTarget ?? 2000;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: FrostedGlass(
                opacity: 0.9,
                tint: TrackerColors.navFill,
                blur: 24,
                borderRadius: BorderRadius.zero,
                border: AppDecor.hairlineTop,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 20, 12),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Insights', style: AppType.title()),
                          const SizedBox(height: 2),
                          Text('Your week at a glance', style: AppType.caption(size: 12)),
                        ],
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: insightsAsync.isLoading
                            ? null
                            : () => ref.read(insightsProvider.notifier).load(refresh: true),
                        dimWhenDisabled: true,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TrackerColors.alpha(TrackerColors.textPrimary, 0.07),
                            shape: BoxShape.circle,
                            border: Border.all(color: TrackerColors.border, width: 1),
                          ),
                          child: insightsAsync.isLoading
                              ? const PulsingRing(size: 18, strokeWidth: 2)
                              : const Icon(
                                  CupertinoIcons.refresh,
                                  size: 17,
                                  color: TrackerColors.textPrimary,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: insightsAsync.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  children: const [
                    SkeletonCard(height: 170),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 220),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 150),
                  ],
                ),
                error: (err, _) => AppEmptyState(
                  icon: CupertinoIcons.wifi_exclamationmark,
                  title: 'Could not load insights',
                  message: '$err',
                  accent: TrackerColors.error,
                ),
                data: (insights) => ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  children: [
                    AppCard(
                      glow: TrackerColors.accentStart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: TrackerColors.calorieGradient,
                                  borderRadius: AppRadii.smallAll,
                                  boxShadow: AppDecor.glow(
                                    TrackerColors.accentStart,
                                    blur: 14,
                                    opacity: 0.3,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.sparkles,
                                  color: TrackerColors.textPrimary,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Text('AI COACH', style: AppType.sectionLabel()),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: AppMotion.slow,
                            curve: AppMotion.standard,
                            builder: (context, t, child) => Opacity(opacity: t, child: child),
                            child: Text(
                              insights.narrative,
                              style: AppType.body(size: 15, color: TrackerColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(label: 'This week'),
                          const SizedBox(height: AppSpacing.lg),
                          WeeklyTrendChart(data: insights.weeklyTrend, target: target),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(label: 'Tips'),
                          const SizedBox(height: AppSpacing.lg),
                          ...insights.tips.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom: entry.key == insights.tips.length - 1 ? 0 : AppSpacing.md,
                              ),
                              child: _TipRow(index: entry.key, tip: entry.value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.tabBarClearance + bottomInset),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.index, required this.tip});

  final int index;
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.textPrimary, 0.04),
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: TrackerColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TrackerColors.alpha(TrackerColors.macroProtein, 0.14),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: AppDecor.glow(TrackerColors.macroProtein, blur: 10, opacity: 0.25),
            ),
            child: const Icon(
              CupertinoIcons.check_mark,
              size: 11,
              color: TrackerColors.macroProtein,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              tip,
              style: AppType.body(size: 14, color: TrackerColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
