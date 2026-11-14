import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_copy.dart';
import '../models/user_profile.dart';
import '../providers/friends_provider.dart';
import '../providers/user_provider.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/username_screen.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'app_button.dart';
import 'appearance_picker.dart';
import 'delete_account.dart';
import 'glass.dart';

/// The profile surface: targets from [userProfileProvider], appearance,
/// notifications, and the account actions (username, delete account).
Future<void> showProfileSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    // Inside AppSheet like every other sheet: without it the content had no
    // panel behind it, no padding, and couldn't scroll on a small phone.
    builder: (sheetContext) => AppSheet(
      child: Consumer(
        builder: (context, ref, _) => ProfileContent(
          profile: ref.watch(userProfileProvider),
          username: ref.watch(friendsProvider).valueOrNull?.myUsername,
          onUsernameChanged: () => ref.read(friendsProvider.notifier).load(),
        ),
      ),
    ),
  );
}

class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.profile,
    this.username,
    this.onUsernameChanged,
    this.onDeleteAccount,
  });

  final UserProfile? profile;

  /// The person's current username, once known.
  final String? username;
  final VoidCallback? onUsernameChanged;

  /// Replaces the delete-account flow; for tests.
  final Future<void> Function(BuildContext context)? onDeleteAccount;

  /// Username and delete account. Shown whether or not onboarding is done:
  /// the stores require that anyone with an account can delete it in the app.
  List<Widget> _accountActions(BuildContext context) => [
        if (username != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton.glass(
            key: const ValueKey('change_username'),
            label: 'Change username',
            icon: CupertinoIcons.at,
            onPressed: () {
              final navigator = Navigator.of(context);
              final changed = onUsernameChanged;
              navigator.pop();
              navigator.push(
                CupertinoPageRoute<void>(
                  builder: (routeContext) => UsernameScreen(
                    current: username,
                    onDone: (_) {
                      changed?.call();
                      Navigator.of(routeContext).pop();
                    },
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Center(
          child: CupertinoButton(
            key: const ValueKey('delete_account'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: () => (onDeleteAccount ?? confirmAndDeleteAccount)(context),
            child: Text('Delete account', style: AppType.caption(color: TrackerColors.error, size: 13)),
          ),
        ),
      ];

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
          const SizedBox(height: AppSpacing.xl),
          const AppearancePicker(),
          ..._accountActions(context),
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
                style: AppType.button(color: TrackerColors.onAccent, size: 22).copyWith(fontWeight: FontWeight.w800),
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
                    '${p.goal.title} · ${p.activityLevel.title}',
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
            Expanded(child: _Metric(label: 'Height', value: '${(p.heightCm / 100).toStringAsFixed(2)} m')),
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
            Expanded(child: _Metric(label: 'At rest', value: p.bmr?.round().toString() ?? '—', sub: 'calories burned')),
            Expanded(child: _Metric(label: 'Per day', value: p.tdee?.round().toString() ?? '—', sub: 'calories burned')),
            Expanded(
              child: _Metric(
                label: 'Target',
                value: (p.calorieTarget ?? 0).toString(),
                sub: 'calories a day',
                accent: TrackerColors.accentStartText,
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
        const SizedBox(height: AppSpacing.xl),
        const AppearancePicker(),
        const SizedBox(height: AppSpacing.xl),
        AppButton.glass(
          key: const ValueKey('open_notifications'),
          label: 'Notifications',
          icon: CupertinoIcons.bell,
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const NotificationSettingsScreen()),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
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
        ..._accountActions(context),
      ],
    );
  }
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
