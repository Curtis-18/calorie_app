import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';

/// Slim progress bar with a spring-animated fill, glow and a macro colour.
class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.color,
    this.unit = 'g',
  });

  final String label;
  final double current;
  final double target;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final value = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - current).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: AppDecor.glow(color, blur: 8, opacity: 0.6),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: AppType.caption(color: TrackerColors.textPrimary, size: 12)),
            const Spacer(),
            Text(
              '${current.round()}$unit',
              style: AppType.caption(color: TrackerColors.textPrimary, size: 12)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              ' / ${target.round()}$unit',
              style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          builder: (context, animated, _) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * animated;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.instant,
                    height: 10,
                    width: width.clamp(0.0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TrackerColors.alpha(color, 0.45), color],
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: AppDecor.glow(color, blur: 10, opacity: 0.45),
                    ),
                  ),
                  if (width > 6)
                    Positioned(
                      left: (width.clamp(0.0, constraints.maxWidth)) - 4,
                      top: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: TrackerColors.textPrimary,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          boxShadow: AppDecor.glow(color, blur: 10, opacity: 0.8),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (target > 0) ...[
          const SizedBox(height: 6),
          Text(
            remaining >= 0 ? '$remaining$unit left today' : '${remaining.abs()}$unit over',
            style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
          ),
        ],
      ],
    );
  }
}

/// Stacked protein / carbs / fat card for the dashboard.
class MacroBreakdownCard extends StatelessWidget {
  const MacroBreakdownCard({
    super.key,
    required this.protein,
    required this.proteinTarget,
    required this.carbs,
    required this.carbsTarget,
    required this.fat,
    required this.fatTarget,
  });

  final double protein;
  final int proteinTarget;
  final double carbs;
  final int carbsTarget;
  final double fat;
  final int fatTarget;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('MACROS', style: AppType.sectionLabel()),
              const Spacer(),
              const Icon(CupertinoIcons.chart_bar_fill, size: 13, color: TrackerColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MacroBar(
            label: 'Protein',
            current: protein,
            target: proteinTarget.toDouble(),
            color: TrackerColors.macroProtein,
          ),
          const SizedBox(height: AppSpacing.lg),
          MacroBar(
            label: 'Carbs',
            current: carbs,
            target: carbsTarget.toDouble(),
            color: TrackerColors.macroCarbs,
          ),
          const SizedBox(height: AppSpacing.lg),
          MacroBar(
            label: 'Fat',
            current: fat,
            target: fatTarget.toDouble(),
            color: TrackerColors.macroFat,
          ),
        ],
      ),
    );
  }
}
