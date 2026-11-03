import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/user_profile.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../app_button.dart';
import '../glass.dart';

/// The payoff at the end of onboarding: the plan that was just worked out,
/// in plain words. [maintenanceNotice] explains why a weight-loss goal came
/// out as "stay the same" when that happens.
Future<void> showPlanReadySheet(BuildContext context, {required UserProfile profile, String? maintenanceNotice}) {
  return showAppSheet<void>(
    context: context,
    builder: (sheet) => AppSheet(
      child: PlanReady(profile: profile, maintenanceNotice: maintenanceNotice, onDone: () => Navigator.of(sheet).pop()),
    ),
  );
}

class PlanReady extends StatelessWidget {
  const PlanReady({super.key, required this.profile, required this.onDone, this.maintenanceNotice});

  final UserProfile profile;
  final VoidCallback onDone;
  final String? maintenanceNotice;

  @override
  Widget build(BuildContext context) {
    final calories = profile.calorieTarget ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: TrackerColors.calorieGradient,
              shape: BoxShape.circle,
              boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 28, opacity: 0.4),
            ),
            child: Icon(CupertinoIcons.sparkles, size: 28, color: TrackerColors.onAccent),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Your plan is ready', textAlign: TextAlign.center, style: AppType.title()),
        const SizedBox(height: AppSpacing.lg),
        Text(
          NumberFormat.decimalPattern().format(calories),
          textAlign: TextAlign.center,
          style: AppType.display(size: 58, color: TrackerColors.accentEndText),
        ),
        Text('calories a day', textAlign: TextAlign.center, style: AppType.callout().copyWith(fontSize: 15)),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _Macro(label: 'Protein', grams: profile.proteinTargetG, color: TrackerColors.macroProtein),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Macro(label: 'Carbs', grams: profile.carbsTargetG, color: TrackerColors.macroCarbs),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _Macro(label: 'Fat', grams: profile.fatTargetG, color: TrackerColors.macroFat),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (maintenanceNotice != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TrackerColors.alpha(TrackerColors.accentEnd, 0.1),
              borderRadius: AppRadii.smallAll,
              border: Border.all(color: TrackerColors.alpha(TrackerColors.accentEnd, 0.25)),
            ),
            child: Text(maintenanceNotice!, style: AppType.callout(color: TrackerColors.accentEndText)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          "It's a starting estimate. Log your meals for a week or two and we'll help you fine-tune it.",
          textAlign: TextAlign.center,
          style: AppType.callout(),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(label: "Let's go", onPressed: onDone),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams, required this.color});

  final String label;
  final int? grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(color, 0.1),
        borderRadius: AppRadii.buttonAll,
        border: Border.all(color: TrackerColors.alpha(color, 0.28)),
      ),
      child: Column(
        children: [
          Text('${grams ?? 0}g', style: AppType.headline(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption(color: TrackerColors.textSecondary, size: 11.5)),
        ],
      ),
    );
  }
}
