import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appearance.dart';
import '../providers/appearance_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'pressable.dart';

/// Light / Dark / Auto, as three big tiles. Applies instantly, so the sheet it
/// sits in turns into a live preview.
class AppearancePicker extends ConsumerWidget {
  const AppearancePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appearanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('APPEARANCE', style: AppType.sectionLabel()),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final mode in AppearanceMode.values) ...[
              Expanded(
                child: _ModeTile(
                  mode: mode,
                  selected: mode == current,
                  onTap: () => ref.read(appearanceProvider.notifier).set(mode),
                ),
              ),
              if (mode != AppearanceMode.values.last) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: AppMotion.quick,
          child: Text(
            current.blurb,
            key: ValueKey(current),
            style: AppType.caption(color: TrackerColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.selected, required this.onTap});

  final AppearanceMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} appearance',
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadii.buttonAll,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.1) : TrackerColors.surfaceElevated,
            borderRadius: AppRadii.buttonAll,
            border: Border.all(
              color: selected ? TrackerColors.alpha(TrackerColors.accentStart, 0.65) : TrackerColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.quick,
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? TrackerColors.calorieGradient : null,
                  color: selected ? null : TrackerColors.alpha(TrackerColors.textPrimary, 0.06),
                ),
                child: Icon(
                  mode.icon,
                  size: 18,
                  color: selected ? TrackerColors.onAccent : TrackerColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mode.label,
                style: AppType.caption(
                  color: selected ? TrackerColors.textPrimary : TrackerColors.textSecondary,
                  size: 12.5,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
