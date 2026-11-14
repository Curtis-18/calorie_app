import 'package:flutter/cupertino.dart';
import '../models/nutrients.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'glass.dart';

/// Fibre, sugar, sodium, iron and calcium for the day on screen.
///
/// Deliberately calm: one neutral colour, no red for "over" or "under", and
/// no advice. The numbers only count foods that have nutrient data, and the
/// card says so when some of the day's foods don't.
class NutrientsCard extends StatelessWidget {
  const NutrientsCard({super.key, required this.summary, this.bare = false});

  final NutrientSummary summary;

  /// Without its own card, for when it already sits in a sheet.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('NUTRIENTS', style: AppType.sectionLabel()),
              const Spacer(),
              Icon(CupertinoIcons.leaf_arrow_circlepath, size: 13, color: TrackerColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!summary.hasData)
            Text(
              summary.foods == 0
                  ? 'Fibre, sugar, sodium, iron and calcium show up here as you log food.'
                  : "The foods logged so far don't have nutrient data.",
              key: const ValueKey('nutrients_empty'),
              style: AppType.caption(color: TrackerColors.textTertiary, size: 12),
            )
          else ...[
            for (final total in summary.totals) _NutrientRow(total: total),
            const SizedBox(height: 4),
            Text(
              summary.isPartial
                  ? 'Based on ${summary.foodsWithData} of ${summary.foods} foods today; the rest have no '
                      'nutrient data. Daily amounts are general guidance for adults, not medical advice.'
                  : 'Daily amounts are general guidance for adults, not medical advice.',
              key: const ValueKey('nutrients_note'),
              style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
            ),
          ],
        ],
      );
    if (bare) return content;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: content,
    );
  }
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({required this.total});

  final NutrientTotal total;

  @override
  Widget build(BuildContext context) {
    final info = total.info;
    final known = total.foodsWithData > 0;
    final target = total.target;
    final fraction = known && target != null && target > 0 ? (total.amount / target).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(info.label, style: AppType.caption(color: TrackerColors.textPrimary, size: 12)),
              const Spacer(),
              Text(
                // Unknown is shown as unknown, never as a zero.
                known ? formatNutrient(total.amount, info.unit) : 'No data',
                key: ValueKey('nutrient_${info.key}'),
                style: AppType.caption(
                  color: known ? TrackerColors.textPrimary : TrackerColors.textTertiary,
                  size: 12,
                ).copyWith(fontWeight: known ? FontWeight.w800 : FontWeight.w500),
              ),
              if (known && target != null)
                Text(
                  info.isLimit ? ' of $target ${info.unit} limit' : ' / $target ${info.unit}',
                  style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
                ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Stack(
                children: [
                  Container(height: 5, color: TrackerColors.alpha(TrackerColors.textPrimary, 0.06)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction),
                    duration: AppMotion.medium,
                    curve: AppMotion.standard,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      child: Container(height: 5, color: TrackerColors.alpha(TrackerColors.accentEnd, 0.85)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The slim "View nutrients" row under the macros: the five numbers take up a
/// lot of room, so Today shows only this and the card opens on tap.
class NutrientsRow extends StatelessWidget {
  const NutrientsRow({super.key, required this.summary, required this.onTap});

  final NutrientSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View nutrients',
      child: AppCard(
        key: const ValueKey('nutrients_row'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TrackerColors.alpha(TrackerColors.success, 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(CupertinoIcons.leaf_arrow_circlepath, size: 17, color: TrackerColors.success),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View nutrients', style: AppType.body(size: 15.5).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(
                    'Fibre, sugar, sodium, iron and calcium',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption(color: TrackerColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// The day's nutrients in a bottom sheet.
Future<void> showNutrientsSheet(BuildContext context, NutrientSummary summary) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => AppSheet(child: NutrientsCard(summary: summary, bare: true)),
  );
}
