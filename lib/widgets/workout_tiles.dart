import 'package:flutter/cupertino.dart';

import '../l10n/app_strings.dart';
import '../models/workouts.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_card.dart';
import 'move_icons.dart';
import 'pressable.dart';

/// A routine as a row in the library.
class WorkoutTile extends StatelessWidget {
  const WorkoutTile({super.key, required this.card, required this.onTap});

  final WorkoutCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          MoveIcon.slice(card.slice, size: 25, tile: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.body(size: 15.5, color: TrackerColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  [tr('{n} min', {'n': '${card.minutes}'}), card.levelLabel].where((x) => x.isNotEmpty).join(' · '),
                  style: AppType.caption(size: 12.5),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: TrackerColors.textTertiary),
        ],
      ),
    );
  }
}

/// A small square card for the sideways "Move bites" strip.
class BiteTile extends StatelessWidget {
  const BiteTile({super.key, required this.card, required this.onTap});

  final WorkoutCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TrackerColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: TrackerColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoveIcon.slice(card.slice, size: 22, tile: true),
            const SizedBox(height: 8),
            Text(card.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.body(size: 14, color: TrackerColors.textPrimary)),
            const SizedBox(height: 4),
            Text(tr('{n} min', {'n': '${card.minutes}'}), style: AppType.caption(size: 12)),
          ],
        ),
      ),
    );
  }
}

/// A filter chip (length or slice).
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;

  /// A small icon before the label.
  final Widget? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TrackerColors.accentWash : TrackerColors.glassFill,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: selected ? TrackerColors.accentStartText : TrackerColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 7)],
            Text(label, style: AppType.body(size: 13.5, color: selected ? TrackerColors.accentStartText : TrackerColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
