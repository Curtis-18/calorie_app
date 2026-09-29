import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';

/// Onboarding step rail: gradient-filled capsules for completed steps and a
/// glowing dot for the active one.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.stepCount, required this.currentStep});

  final int stepCount;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stepCount * 2 - 1, (i) {
        if (i.isOdd) {
          final leftStep = i ~/ 2;
          final isFilled = leftStep < currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: AppMotion.medium,
                curve: AppMotion.spring,
                height: 3,
                decoration: BoxDecoration(
                  gradient: isFilled ? TrackerColors.calorieGradient : null,
                  color: isFilled ? null : TrackerColors.alpha(TrackerColors.textPrimary, 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
          );
        }

        final step = i ~/ 2;
        final isCompleted = step < currentStep;
        final isCurrent = step == currentStep;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1),
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.standard,
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isCompleted ? TrackerColors.calorieGradient : null,
              color: isCompleted ? null : TrackerColors.surface,
              border: Border.all(
                color: (isCompleted || isCurrent)
                    ? const Color(0x00000000)
                    : TrackerColors.borderStrong,
                width: 1.5,
              ),
              boxShadow: isCurrent
                  ? AppDecor.glow(TrackerColors.accentStart, blur: 14, opacity: 0.4)
                  : null,
            ),
            child: isCompleted
                ? const Icon(CupertinoIcons.check_mark, size: 14, color: TrackerColors.background)
                : Text(
                    '${step + 1}',
                    style: AppType.caption(
                      color: isCurrent ? TrackerColors.accentStart : TrackerColors.textTertiary,
                      size: 12,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
          ),
        );
      }),
    );
  }
}
