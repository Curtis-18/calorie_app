import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../providers/language_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../models/week_budget.dart';
import '../models/weight.dart';
import '../providers/budget_provider.dart';
import '../models/food_region.dart';
import '../providers/display_prefs_provider.dart';
import '../providers/food_region_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/shell_provider.dart';
import '../providers/user_provider.dart';
import '../providers/weight_provider.dart';
import '../services/tour_service.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_field.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/delete_account.dart';
import '../widgets/log_out.dart';
import '../widgets/settings_list.dart';
import 'friends_screen.dart' show showBlockedPeopleSheet;
import 'notification_settings_screen.dart';
import 'onboarding_screen.dart';
import 'username_screen.dart';

/// Everything that used to be scattered over the Today header, the profile
/// sheet and the bottom of Friends, in one place: account, appearance, what
/// Today shows, units, notifications, privacy, help, log out and delete.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull;
    return SettingsView(
      profile: ref.watch(userProfileProvider),
      username: friends?.myUsername,
      onUsernameChanged: () => ref.read(friendsProvider.notifier).load(),
      onBlockedPeople: () => showBlockedPeopleSheet(context, ref.read(friendsProvider.notifier).service),
    );
  }
}

class SettingsView extends ConsumerWidget {
  const SettingsView({
    super.key,
    required this.profile,
    this.username,
    this.onUsernameChanged,
    this.onBlockedPeople,
    this.onLogOut,
    this.onDeleteAccount,
  });

  final UserProfile? profile;

  /// The person's current username, once known.
  final String? username;
  final VoidCallback? onUsernameChanged;
  final VoidCallback? onBlockedPeople;

  /// Replace the log-out and delete-account flows; for tests.
  final Future<void> Function(BuildContext context)? onLogOut;
  final Future<void> Function(BuildContext context)? onDeleteAccount;

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: builder));

  Future<void> _replayTour(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await TourService.reset(TourService.dashboard);
    // Back to the tabs, on Today, where the tour starts.
    navigator.popUntil((route) => route.isFirst);
    ref.read(shellTabProvider.notifier).state = ShellTab.today;
    ref.read(tourReplayProvider.notifier).state++;
  }

  Future<void> _saveBudget(BuildContext context, WidgetRef ref, Map<String, Object?> changes) async {
    final error = await ref.read(budgetProvider.notifier).update(changes);
    if (error == null || !context.mounted) return;
    await showAppDialog(context: context, title: context.tr("Couldn't change that"), message: error, confirmLabel: 'OK');
  }

  /// Choose the app's language, or "Automatic" to follow the phone. The choice
  /// is remembered on this device and applies at once.
  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(languageProvider);
    // A record so "Automatic" (null) can be told from dismissing the sheet.
    final picked = await showCupertinoModalPopup<({String? code})>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.tr('Choose a language')),
        message: Text(context.tr('Some screens are still in English while we finish translating them.')),
        actions: [
          CupertinoActionSheetAction(
            key: const ValueKey('language_auto'),
            isDefaultAction: current == null,
            onPressed: () => Navigator.pop(context, (code: null)),
            child: Text(context.tr('Automatic')),
          ),
          for (final l in supportedLanguages)
            CupertinoActionSheetAction(
              key: ValueKey('language_${l.code}'),
              isDefaultAction: l.code == current,
              onPressed: () => Navigator.pop(context, (code: l.code)),
              child: Text(l.nativeName),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel'))),
      ),
    );
    if (picked == null || picked.code == current) return;
    await ref.read(languageProvider.notifier).set(picked.code);
  }

  String _languageValue(BuildContext context, String? saved, String active) {
    final name = languageName(active) ?? tr('English');
    return saved == null ? '${context.tr('Automatic')} · $name' : name;
  }

  String _regionValue(BuildContext context, String? key) {
    final label = foodRegionLabel(key);
    return label == null ? context.tr('Not set') : context.tr(label);
  }

  Future<void> _pickRegion(BuildContext context, WidgetRef ref, String? current) async {
    // A record so "None" (clear) can be told from dismissing the sheet.
    final picked = await showCupertinoModalPopup<({String? key})>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.tr('Where do you mostly eat?')),
        message: Text(context.tr('It only helps the camera name dishes. It never limits what you can log.')),
        actions: [
          for (final r in foodRegions)
            CupertinoActionSheetAction(
              key: ValueKey('region_${r.key}'),
              isDefaultAction: r.key == current,
              onPressed: () => Navigator.pop(context, (key: r.key)),
              child: Text(context.tr(r.label)),
            ),
          CupertinoActionSheetAction(
            key: const ValueKey('region_none'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, (key: null)),
            child: Text(context.tr('Don’t use a region')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel'))),
      ),
    );
    if (picked == null || picked.key == current || !context.mounted) return;
    final error = await ref.read(foodRegionProvider.notifier).set(picked.key);
    if (error == null || !context.mounted) return;
    await showAppDialog(context: context, title: context.tr("Couldn't change that"), message: error, confirmLabel: 'OK');
  }

  Future<void> _pickWeekStart(BuildContext context, WidgetRef ref, BudgetPrefs prefs) async {
    final picked = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.tr('Week starts on')),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, 0), child: Text(context.tr('Monday'))),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, 6), child: Text(context.tr('Sunday'))),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text(context.tr('Cancel'))),
      ),
    );
    if (picked == null || picked == prefs.weekStartDay || !context.mounted) return;
    await _saveBudget(context, ref, {
      'week_start_day': picked,
      // Weekend flex is listed from the first day of the week, so it moves with it.
      if (prefs.weekendFlex) 'weights': weekendFlexWeights(picked),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displayPrefsProvider);
    final displayNotifier = ref.read(displayPrefsProvider.notifier);
    final unit = ref.watch(weightUnitProvider);
    final budget = ref.watch(budgetProvider);
    final budgetPrefs = budget.prefs ?? const BudgetPrefs();
    final p = profile;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
        middle: Text(context.tr('Settings')),
      ),
      child: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsGroup(
                      label: context.tr('Account'),
                      children: [
                        if (username != null)
                          SettingsRow(
                            key: const ValueKey('change_username'),
                            icon: CupertinoIcons.at,
                            title: context.tr('Username'),
                            value: '@$username',
                            onTap: () => _push(
                              context,
                              (routeContext) => UsernameScreen(
                                current: username,
                                onDone: (_) {
                                  onUsernameChanged?.call();
                                  Navigator.of(routeContext).pop();
                                },
                              ),
                            ),
                          ),
                        SettingsRow(
                          key: const ValueKey('edit_profile'),
                          icon: CupertinoIcons.slider_horizontal_3,
                          title: p == null ? context.tr('Set up profile') : context.tr('Profile and goals'),
                          subtitle: p == null
                              ? context.tr('Answer a few questions to get your targets')
                              : context.tr('Weight, height, activity and goal'),
                          onTap: () => _push(context, (_) => OnboardingScreen(existingProfile: p)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const AppearancePicker(),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Language'),
                      footer: ref.watch(languageProvider) == null ? context.tr('Follows your phone’s language') : null,
                      children: [
                        SettingsRow(
                          key: const ValueKey('language'),
                          icon: CupertinoIcons.textformat,
                          color: TrackerColors.accentEnd,
                          title: context.tr('Language'),
                          value: _languageValue(context, ref.watch(languageProvider), ref.watch(activeLanguageProvider)),
                          onTap: () => _pickLanguage(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Today screen'),
                      footer: context.tr('Calories and meals always show. These cards are optional.'),
                      children: [
                        SettingsSwitchRow(
                          key: const ValueKey('toggle_macros'),
                          icon: CupertinoIcons.chart_pie,
                          color: TrackerColors.macroProtein,
                          title: context.tr('Macros'),
                          subtitle: context.tr('Protein, carbs and fat'),
                          value: display.showMacros,
                          onChanged: displayNotifier.setShowMacros,
                        ),
                        SettingsSwitchRow(
                          key: const ValueKey('toggle_nutrients'),
                          icon: CupertinoIcons.leaf_arrow_circlepath,
                          color: TrackerColors.success,
                          title: context.tr('Nutrients'),
                          subtitle: context.tr('A "View nutrients" row under macros'),
                          value: display.showNutrients,
                          onChanged: displayNotifier.setShowNutrients,
                        ),
                        SettingsSwitchRow(
                          key: const ValueKey('toggle_launch_camera'),
                          icon: CupertinoIcons.camera_fill,
                          color: TrackerColors.accentStart,
                          title: context.tr('Open the camera at launch'),
                          subtitle: context.tr('Start a meal photo as soon as the app opens'),
                          value: display.launchToCamera,
                          onChanged: displayNotifier.setLaunchToCamera,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Food'),
                      footer: context.tr('Helps the camera name regional dishes. You can always correct what it finds.'),
                      children: [
                        SettingsRow(
                          key: const ValueKey('food_region'),
                          icon: CupertinoIcons.globe,
                          color: TrackerColors.accentEnd,
                          title: context.tr('Where you mostly eat'),
                          value: _regionValue(context, ref.watch(foodRegionProvider)),
                          onTap: () => _pickRegion(context, ref, ref.read(foodRegionProvider)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Weekly budget'),
                      footer: context.tr('Eat a bit more one day and the rest of the week eases gently, inside your healthy range. Days you don’t log are left out.'),
                      children: [
                        SettingsSwitchRow(
                          key: const ValueKey('toggle_weekly_budget'),
                          icon: CupertinoIcons.calendar,
                          color: TrackerColors.accentEnd,
                          title: context.tr('Flexible weekly target'),
                          subtitle: context.tr('Today’s plan adjusts a little across the week'),
                          value: budgetPrefs.weekly,
                          onChanged: (on) => _saveBudget(context, ref, {'mode': on ? 'weekly' : 'daily'}),
                        ),
                        SettingsSwitchRow(
                          key: const ValueKey('toggle_weekend_flex'),
                          icon: CupertinoIcons.sun_max,
                          color: TrackerColors.accentEnd,
                          title: context.tr('Weekend flex'),
                          subtitle: context.tr('A little more on Saturday and Sunday'),
                          value: budgetPrefs.weekendFlex,
                          onChanged: (on) => _saveBudget(context, ref, {
                            'weights': on ? weekendFlexWeights(budgetPrefs.weekStartDay) : <double>[],
                            if (on) 'mode': 'weekly',
                          }),
                        ),
                        SettingsSwitchRow(
                          key: const ValueKey('toggle_budget_nudges'),
                          icon: CupertinoIcons.chat_bubble_text,
                          color: TrackerColors.accentEnd,
                          title: context.tr('Gentle nudges'),
                          subtitle: context.tr('A kind suggestion after a bigger day'),
                          value: budgetPrefs.nudges,
                          onChanged: (on) => _saveBudget(context, ref, {'nudges': on}),
                        ),
                        SettingsRow(
                          key: const ValueKey('week_start'),
                          icon: CupertinoIcons.calendar_today,
                          color: TrackerColors.accentEnd,
                          title: context.tr('Week starts on'),
                          value: budgetPrefs.weekStartDay == 6 ? context.tr('Sunday') : context.tr('Monday'),
                          onTap: () => _pickWeekStart(context, ref, budgetPrefs),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Units'),
                      children: [
                        SettingsRow(
                          icon: CupertinoIcons.gauge,
                          color: TrackerColors.macroCarbs,
                          title: context.tr('Weight'),
                          trailing: CupertinoSlidingSegmentedControl<WeightUnit>(
                            key: const ValueKey('weight_unit'),
                            groupValue: unit,
                            backgroundColor: TrackerColors.alpha(TrackerColors.textPrimary, 0.08),
                            thumbColor: TrackerColors.surfaceHigh,
                            children: {
                              for (final u in WeightUnit.values)
                                u: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(u.label, style: AppType.caption(color: TrackerColors.textPrimary, size: 13)),
                                ),
                            },
                            onValueChanged: (u) {
                              if (u != null) ref.read(weightUnitProvider.notifier).set(u);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Notifications and privacy'),
                      children: [
                        SettingsRow(
                          key: const ValueKey('open_notifications'),
                          icon: CupertinoIcons.bell,
                          color: TrackerColors.macroFat,
                          title: context.tr('Notifications'),
                          subtitle: context.tr('What to tell you, quiet hours, pause'),
                          onTap: () => _push(context, (_) => const NotificationSettingsScreen()),
                        ),
                        SettingsRow(
                          key: const ValueKey('blocked_people'),
                          icon: CupertinoIcons.hand_raised,
                          color: TrackerColors.warning,
                          title: context.tr('Blocked people'),
                          onTap: onBlockedPeople,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      label: context.tr('Help'),
                      children: [
                        SettingsRow(
                          key: const ValueKey('replay_tour'),
                          icon: CupertinoIcons.play_circle,
                          title: context.tr('Replay the tutorial'),
                          subtitle: context.tr('A quick walk through the app'),
                          onTap: () => _replayTour(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          key: const ValueKey('log_out'),
                          icon: CupertinoIcons.square_arrow_right,
                          color: TrackerColors.textSecondary,
                          title: context.tr('Log out'),
                          onTap: () => (onLogOut ?? confirmAndLogOut)(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Shown whether or not onboarding is done: the stores
                    // require that anyone with an account can delete it here.
                    Center(
                      child: CupertinoButton(
                        key: const ValueKey('delete_account'),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () => (onDeleteAccount ?? confirmAndDeleteAccount)(context),
                        child: Text(context.tr('Delete account'), style: AppType.caption(color: TrackerColors.error, size: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
