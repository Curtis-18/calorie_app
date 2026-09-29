import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../screens/onboarding_screen.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'glass.dart';

/// Read-only profile surface: the data already held by [userProfileProvider].
Future<void> showProfileSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final profile = ref.watch(userProfileProvider);
        return _ProfileContent(profile: profile);
      },
    ),
  );
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your profile', style: AppType.title()),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Complete onboarding to see your targets.',
            style: AppType.callout(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Set up profile',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const OnboardingScreen()),
              );
            },
          ),
        ],
      );
    }

    final p = profile!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: TrackerColors.calorieGradient,
                borderRadius: AppRadii.buttonAll,
                boxShadow: AppDecor.glow(TrackerColors.accentStart, blur: 18, opacity: 0.3),
              ),
              child: Text(
                p.gender == Gender.female ? 'F' : 'M',
                style: AppType.button(size: 22).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.age} years old', style: AppType.headline()),
                  const SizedBox(height: 2),
                  Text(
                    '${_label(p.goal)} goal · ${_label(p.activityLevel)}',
                    style: AppType.callout(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: _Metric(label: 'Weight', value: '${p.weightKg.round()} kg')),
            Expanded(child: _Metric(label: 'Height', value: '${(p.heightCm / 100).round() / 10} m')),
            Expanded(
              child: _Metric(
                label: 'BMI',
                value: p.bmi?.toStringAsFixed(1) ?? '—',
                sub: p.bmiCategory,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _Metric(label: 'BMR', value: p.bmr?.round().toString() ?? '—', sub: 'kcal base')),
            Expanded(child: _Metric(label: 'TDEE', value: p.tdee?.round().toString() ?? '—', sub: 'kcal burn')),
            Expanded(
              child: _Metric(
                label: 'Target',
                value: (p.calorieTarget ?? 0).toString(),
                sub: 'kcal / day',
                accent: TrackerColors.accentStart,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FrostedGlass(
          opacity: 0.07,
          borderRadius: AppRadii.buttonAll,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _MacroRow(
                  label: 'Protein',
                  value: '${(p.proteinTargetG ?? 0)}g',
                  color: TrackerColors.macroProtein,
                ),
                const SizedBox(height: AppSpacing.md),
                _MacroRow(
                  label: 'Carbs',
                  value: '${(p.carbsTargetG ?? 0)}g',
                  color: TrackerColors.macroCarbs,
                ),
                const SizedBox(height: AppSpacing.md),
                _MacroRow(
                  label: 'Fat',
                  value: '${(p.fatTargetG ?? 0)}g',
                  color: TrackerColors.macroFat,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.glass(
          label: 'Edit profile',
          icon: CupertinoIcons.pencil,
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => OnboardingScreen(existingProfile: p)),
            );
          },
        ),
      ],
    );
  }

  static String _label(Object value) =>
      value.toString().split('.').last.replaceAll('_', ' ');
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.sub, this.accent});

  final String label;
  final String value;
  final String? sub;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppType.headline(color: accent ?? TrackerColors.textPrimary).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: AppType.caption(color: TrackerColors.textTertiary, size: 9)),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption(color: TrackerColors.textTertiary, size: 9),
          ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(label, style: AppType.caption(size: 13)),
        const Spacer(),
        Text(
          value,
          style: AppType.caption(color: TrackerColors.textPrimary, size: 13)
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
