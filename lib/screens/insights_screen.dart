import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/insights_provider.dart';
import '../providers/user_provider.dart';
import '../providers/weekly_report_provider.dart';
import '../widgets/weekly_report_card.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/pressable.dart';
import '../widgets/shimmer.dart';
import '../widgets/weekly_trend_chart.dart';
import '../widgets/weight/weight_card.dart';
import '../l10n/app_strings.dart';

/// Insights is no longer a tab: it opens on top of the tabs from the "Your week"
/// row on Today and from Profile.
Future<void> openInsights(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(builder: (_) => const InsightsScreen(showBack: true)));

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key, this.showBack = false});

  /// A back arrow in the header (when opened on top of the tabs).
  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final profile = ref.watch(userProfileProvider);
    final target = profile?.calorieTarget ?? 2000;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            PageHeader(
              onBack: showBack ? () => Navigator.of(context).maybePop() : null,
              title: tr('Insights'),
              subtitle: tr('Your week at a glance'),
              actions: [
                Semantics(
                  button: true,
                  label: tr('Refresh insights'),
                  child: Pressable(
                    onTap: insightsAsync.isLoading ? null : () => ref.read(insightsProvider.notifier).load(refresh: true),
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
                          : Icon(CupertinoIcons.refresh, size: 17, color: TrackerColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: insightsAsync.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  children: const [
                    WeightProgressCard(),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 170),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 220),
                    SizedBox(height: AppSpacing.lg),
                    SkeletonCard(height: 150),
                  ],
                ),
                // Weight progress is independent of the AI coach, so it
                // stays available when insights fail.
                error: (err, _) => ListView(
                  padding: EdgeInsets.fromLTRB(24, 18, 24, AppSpacing.tabBarClearance + bottomInset),
                  children: [
                    const WeightProgressCard(),
                    const SizedBox(height: AppSpacing.lg),
                    AppEmptyState(
                      icon: CupertinoIcons.wifi_exclamationmark,
                      title: tr('Could not load insights'),
                      message: '$err',
                      accent: TrackerColors.error,
                    ),
                  ],
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
                                child: Icon(
                                  CupertinoIcons.sparkles,
                                  color: TrackerColors.onAccent,
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
                          SectionHeader(label: tr('This week')),
                          const SizedBox(height: AppSpacing.lg),
                          WeeklyTrendChart(data: insights.weeklyTrend, target: target),
                          if (insights.estimatedEntries > 0) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              context.tr('Some foods this week were estimated, so treat those numbers as a guide.'),
                              key: const ValueKey('estimated_note'),
                              style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (ref.watch(weeklyReportProvider).valueOrNull case final report?) ...[
                      const SizedBox(height: AppSpacing.lg),
                      WeeklyReportCard(report: report),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    SectionHeader(label: tr('Body')),
                    const SizedBox(height: AppSpacing.md),
                    const WeightProgressCard(),
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
