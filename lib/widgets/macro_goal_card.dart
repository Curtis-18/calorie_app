import 'package:flutter/material.dart';
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
    final ratio = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final isOver = remaining < 0;

    final String statusText = consumed == 0
        ? '${target.round()}$unit needed'
        : isOver
        ? '${remaining.abs().round()}$unit over'
        : '${remaining.round()}$unit left';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
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
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 3.5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: TrackerColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      isOver ? TrackerColors.error : color,
                    ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TrackerColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
