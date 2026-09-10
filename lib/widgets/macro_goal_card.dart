import 'package:flutter/cupertino.dart';
import '../theme/tracker_colors.dart';

class MacroGoalCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double consumed;
  final double target;
  final String unit;
  final VoidCallback? onTap;

  const MacroGoalCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.consumed,
    required this.target,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = target - consumed;
    final isOver = remaining < 0;

    final String statusText = consumed == 0
        ? '${target.round()}$unit needed'
        : isOver
        ? '${remaining.abs().round()}$unit over'
        : '${remaining.round()}$unit left';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: TrackerColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TrackerColors.divider, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CupertinoActivityIndicator(
                  ),
                  Icon(icon, size: 16, color: color),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: TrackerColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: TrackerColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
