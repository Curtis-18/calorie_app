import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_copy.dart';
import '../models/progress.dart';
import '../models/user_profile.dart';
import '../models/weight.dart';
import '../providers/friends_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/user_provider.dart';
import '../providers/weight_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/game/flame_style.dart';
import '../widgets/game/progress_sheet.dart';
import '../widgets/page_header.dart';
import '../widgets/pressable.dart';
import '../widgets/profile_photo.dart';
import '../widgets/settings_list.dart';
import 'notification_settings_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';

/// The Profile tab: who you are, your progress, your plan and your body
/// numbers, with Settings behind the gear. Replaces the old profile sheet.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull;
    return ProfileView(
      profile: ref.watch(userProfileProvider),
      progress: ref.watch(progressProvider),
      unit: ref.watch(weightUnitProvider),
      username: friends?.myUsername,
      avatarUrl: friends?.myAvatarUrl,
      onPhotoChanged: () => ref.read(friendsProvider.notifier).load(),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.profile,
    this.progress,
    this.unit = WeightUnit.kg,
    this.username,
    this.avatarUrl,
    this.onPhotoChanged,
    this.photoButton,
    this.onOpenSettings,
  });

  final UserProfile? profile;
  final ProgressData? progress;
  final WeightUnit unit;

  /// The person's username and picture, once known.
  final String? username;
  final String? avatarUrl;
  final VoidCallback? onPhotoChanged;

  /// Replace the photo button and the Settings route; for tests.
  final Widget? photoButton;
  final VoidCallback? onOpenSettings;

  // Full-screen flows go over the tab bar, as they did from the old sheet.
  void _pushOver(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(builder: builder));

  void _openSettings(BuildContext context) =>
      onOpenSettings != null ? onOpenSettings!() : _pushOver(context, (_) => const SettingsScreen());

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CupertinoPageScaffold(
      child: DecoratedBox(
        decoration: BoxDecoration(color: TrackerColors.background),
        child: Column(
          children: [
            PageHeader(
              title: 'Profile',
              actions: [
                AppIconButton(
                  key: const ValueKey('open_settings'),
                  icon: CupertinoIcons.gear_alt,
                  onPressed: () => _openSettings(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.gutter, 18, AppSpacing.gutter, AppSpacing.tabBarClearance + bottomInset),
                children: [
                  _identity(p),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ProgressRow(progress: progress!, onTap: () => showProgressSheet(context)),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  if (p == null)
                    AppCard(
                      child: Column(
                        children: [
                          Text('Finish setting up', style: AppType.headline()),
                          const SizedBox(height: 4),
                          Text(
                            'Answer a few questions to get your daily calorie and macro targets.',
                            style: AppType.callout(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Set up profile',
                            onPressed: () => _pushOver(context, (_) => const OnboardingScreen()),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const SectionHeader(label: 'Your plan'),
                    const SizedBox(height: AppSpacing.md),
                    _PlanCard(profile: p),
                    const SizedBox(height: AppSpacing.xxl),
                    const SectionHeader(label: 'Body'),
                    const SizedBox(height: AppSpacing.md),
                    _BodyCard(profile: p, unit: unit),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.glass(
                      key: const ValueKey('edit_plan'),
                      label: 'Update my details',
                      icon: CupertinoIcons.pencil,
                      onPressed: () => _pushOver(context, (_) => OnboardingScreen(existingProfile: p)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        key: const ValueKey('profile_notifications'),
                        icon: CupertinoIcons.bell,
                        color: TrackerColors.macroFat,
                        title: 'Notifications',
                        onTap: () => _pushOver(context, (_) => const NotificationSettingsScreen()),
                      ),
                      SettingsRow(
                        key: const ValueKey('profile_settings'),
                        icon: CupertinoIcons.gear_alt,
                        color: TrackerColors.textSecondary,
                        title: 'Settings',
                        subtitle: 'Appearance, units, privacy, account',
                        onTap: () => _openSettings(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity(UserProfile? p) {
    final name = username;
    final details = p == null
        ? null
        : name != null
            ? '${p.age} years old · ${p.goal.title}'
            : '${p.goal.title} · ${p.activityLevel.title}';
    return AppCard(
      glow: TrackerColors.accentStart,
      child: Row(
        children: [
          // Their picture once they have a username (friends see it next to
          // the name); before that, a plain badge.
          if (name != null)
            photoButton ??
                ProfilePhotoButton(
                  key: const ValueKey('profile_photo'),
                  username: name,
                  imageUrl: avatarUrl,
                  onChanged: onPhotoChanged,
                  size: 68,
                )
          else
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: TrackerColors.calorieGradient, shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.person_fill, color: TrackerColors.onAccent, size: 26),
            ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name != null ? '@$name' : (p != null ? '${p.age} years old' : 'Your profile'),
                  style: AppType.title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details != null) ...[
                  const SizedBox(height: 2),
                  Text(details, style: AppType.callout()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak and level side by side; either opens the progress sheet.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress, required this.onTap});

  final ProgressData progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final streak = progress.streak;
    final flame = FlameStyle.of(streak.tier, dim: streak.current == 0);
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            key: const ValueKey('profile_streak'),
            icon: CupertinoIcons.flame_fill,
            color: flame.color,
            value: '${streak.current}',
            label: 'day streak',
            sub: 'Best ${streak.best}',
            onTap: onTap,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatTile(
            key: const ValueKey('profile_level'),
            icon: CupertinoIcons.star_fill,
            color: TrackerColors.accentEnd,
            value: '${progress.level.level}',
            label: 'level',
            sub: '${progress.level.xp} XP',
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$value $label. $sub. Open progress.',
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecor.card(borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TrackerColors.alpha(color, 0.14),
                  borderRadius: AppRadii.smallAll,
                ),
                child: Icon(icon, size: 19, color: TrackerColors.ink(color)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: AppType.title().copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1),
                    ),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.caption(size: 12.5)),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(color: TrackerColors.textTertiary, size: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The daily calorie target with the macro targets underneath.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.calorieTarget ?? 0}',
                style: AppType.display(size: 40, color: TrackerColors.accentStartText),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('calories a day', style: AppType.callout(), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppDivider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _Macro(label: 'Protein', grams: p.proteinTargetG, color: TrackerColors.macroProtein)),
              Expanded(child: _Macro(label: 'Carbs', grams: p.carbsTargetG, color: TrackerColors.macroCarbs)),
              Expanded(child: _Macro(label: 'Fat', grams: p.fatTargetG, color: TrackerColors.macroFat)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams, required this.color});

  final String label;
  final num? grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: AppType.caption(size: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${grams ?? 0}g',
          style: AppType.headline().copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }
}

/// Weight, height and BMI, then what the body burns at rest and in a day.
class _BodyCard extends StatelessWidget {
  const _BodyCard({required this.profile, required this.unit});

  final UserProfile profile;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Metric(label: 'Weight', value: unit.format(p.weightKg, decimals: 0))),
              Expanded(child: _Metric(label: 'Height', value: '${(p.heightCm / 100).toStringAsFixed(2)} m')),
              Expanded(child: _Metric(label: 'BMI', value: p.bmi?.toStringAsFixed(1) ?? '—', sub: p.bmiCategory)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppDivider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(label: 'At rest', value: p.bmr?.round().toString() ?? '—', sub: 'calories burned'),
              ),
              Expanded(
                child: _Metric(label: 'Per day', value: p.tdee?.round().toString() ?? '—', sub: 'calories burned'),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.caption(color: TrackerColors.textSecondary, size: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppType.headline().copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        if (sub != null)
          Text(
            sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption(color: TrackerColors.textTertiary, size: 11),
          ),
      ],
    );
  }
}
