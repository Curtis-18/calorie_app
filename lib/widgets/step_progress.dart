import 'package:flutter/material.dart';
import '../theme/tracker_colors.dart';

class StepProgress extends StatelessWidget {
  final int stepCount;
  final int currentStep;

  const StepProgress({super.key, required this.stepCount, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stepCount * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStep = i ~/ 2;
          final isFilled = leftStep < currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: isFilled ? TrackerColors.primary : TrackerColors.divider,
            ),
          );
        }
        final step = i ~/ 2;
        final isCompleted = step < currentStep;
        final isCurrent = step == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? TrackerColors.primary : TrackerColors.surface,
            border: Border.all(
              color: isCompleted || isCurrent ? TrackerColors.primary : TrackerColors.divider,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: TrackerColors.background)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isCurrent ? TrackerColors.primary : TrackerColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
