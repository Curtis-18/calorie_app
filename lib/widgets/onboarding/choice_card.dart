import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../pressable.dart';

/// A big tappable option with an icon, a plain-language title and a line
/// saying what it means. Used instead of dropdowns, which hid the choices
/// behind ALL-CAPS jargon.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    this.blurb,
    required this.selected,
    required this.onTap,
    this.accent = TrackerColors.accentStart,
  });

  final IconData icon;
  final String title;
  final String? blurb;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: blurb == null ? title : '$title. $blurb',
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadii.buttonAll,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standard,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: selected ? TrackerColors.alpha(accent, 0.12) : TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            border: Border.all(
              color: selected ? TrackerColors.alpha(accent, 0.7) : TrackerColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? AppDecor.glow(accent, blur: 18, opacity: 0.18) : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.quick,
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? TrackerColors.calorieGradient : null,
                  color: selected ? null : TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
                ),
                child: Icon(icon, size: 20, color: selected ? TrackerColors.onAccent : TrackerColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.headline()),
                    if (blurb != null) ...[const SizedBox(height: 2), Text(blurb!, style: AppType.callout())],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AnimatedContainer(
                duration: AppMotion.quick,
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? accent : null,
                  border: selected ? null : Border.all(color: TrackerColors.borderStrong, width: 1.5),
                ),
                child: selected
                    ? Icon(CupertinoIcons.checkmark_alt, size: 14, color: TrackerColors.onAccent)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill switch between a few units (kg / lb, cm / ft / in).
class UnitPills<T> extends StatelessWidget {
  const UnitPills({super.key, required this.options, required this.value, required this.onChanged});

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TrackerColors.alpha(TrackerColors.textPrimary, 0.05),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: TrackerColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in options.entries)
            Pressable(
              onTap: () => onChanged(entry.key),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: AnimatedContainer(
                duration: AppMotion.quick,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: entry.key == value ? TrackerColors.calorieGradient : null,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  entry.value,
                  style: AppType.caption(
                    color: entry.key == value ? TrackerColors.onAccent : TrackerColors.textSecondary,
                    size: 12,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
