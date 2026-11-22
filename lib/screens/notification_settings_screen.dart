import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_prefs.dart';
import '../providers/notification_prefs_provider.dart';
import '../providers/web_push_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_field.dart';
import '../l10n/app_strings.dart';

/// Which notifications you want, when they may arrive, and a pause button.
///
/// The promise is on screen: a hard daily limit, quiet hours, and never
/// anything about weight or calories.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final prefs = state.prefs;

    Widget body;
    if (prefs == null) {
      body = state.loading
          ? const Padding(padding: EdgeInsets.only(top: 80), child: CupertinoActivityIndicator())
          : _LoadFailed(message: state.error ?? tr("Couldn't load your notification settings."), onRetry: notifier.load);
    } else {
      body = _Settings(prefs: prefs, saveError: state.saveError, notifier: notifier);
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: TrackerColors.navFill,
        border: AppDecor.hairlineTop,
        middle: Text(tr('Notifications')),
      ),
      child: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: body)),
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(children: [
          Text(message, style: AppType.callout(), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: tr('Try again'), expand: false, onPressed: onRetry),
        ]),
      );
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.prefs, required this.saveError, required this.notifier});

  final NotificationPrefs prefs;
  final String? saveError;
  final NotificationPrefsNotifier notifier;

  void _set(NotificationPrefs next, Map<String, Object?> changes) => notifier.change(next, changes);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = prefs.isPausedAt(DateTime.now());
    final web = ref.watch(webPushProvider);
    // Browser notifications replace the "not live yet" note wherever they can work.
    final browserCapable = web.status != WebPushStatus.unsupported && web.status != WebPushStatus.unavailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('At most {v1} a day, quiet at night, and never about your weight or calories.', {'v1': prefs.dailyCap}),
          style: AppType.callout(),
        ),
        if (browserCapable && web.status != WebPushStatus.checking) ...[
          const SizedBox(height: AppSpacing.lg),
          _BrowserPushCard(state: web, notifier: ref.read(webPushProvider.notifier)),
        ] else if (!NotificationPrefs.pushLive && web.status != WebPushStatus.checking) ...[
          const SizedBox(height: AppSpacing.lg),
          _Notice(
            key: ValueKey('push_not_live'),
            icon: CupertinoIcons.info,
            text: tr("Notifications arrive once the app is on your phone. Your choices are saved now and will apply then."),
          ),
        ],
        if (saveError != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _Notice(key: const ValueKey('save_error'), icon: CupertinoIcons.exclamationmark_triangle, text: saveError!, error: true),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('WHAT TO TELL ME', style: AppType.sectionLabel()),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _SwitchRow(
              keyName: 'friend_snaps',
              emoji: '📸',
              title: tr('Friends'),
              subtitle: tr('Bites, messages and friend requests'),
              value: prefs.friendSnaps,
              onChanged: (v) => _set(prefs.copyWith(friendSnaps: v), {'friend_snaps': v}),
            ),
            const AppDivider(),
            _SwitchRow(
              keyName: 'reactions',
              emoji: '🔥',
              title: tr('Reactions'),
              subtitle: tr('When someone reacts to your bite'),
              value: prefs.reactions,
              onChanged: (v) => _set(prefs.copyWith(reactions: v), {'reactions': v}),
            ),
            const AppDivider(),
            _SwitchRow(
              keyName: 'streak_reminders',
              emoji: '⏳',
              title: tr('Logging and streak reminders'),
              subtitle: tr("If you haven't logged today, or your streak is about to end"),
              value: prefs.streakReminders,
              onChanged: (v) => _set(prefs.copyWith(streakReminders: v), {'streak_reminders': v}),
            ),
            const AppDivider(),
            _SwitchRow(
              keyName: 'milestones',
              emoji: '🏅',
              title: tr('Badges and levels'),
              subtitle: tr('When you earn something new'),
              value: prefs.milestones,
              onChanged: (v) => _set(prefs.copyWith(milestones: v), {'milestones': v}),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('OPTIONAL', style: AppType.sectionLabel()),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _SwitchRow(
              keyName: 'meal_nudge',
              emoji: '🍽️',
              title: tr('A daily meal reminder'),
              subtitle: prefs.mealNudgeHour == null ? tr('Off') : tr('Every day at {v1}', {'v1': hourLabel(prefs.mealNudgeHour!)}),
              value: prefs.mealNudgeHour != null,
              onChanged: (v) {
                final hour = v ? 13 : null;
                _set(prefs.copyWith(mealNudgeHour: hour), {'meal_nudge_hour': hour ?? -1});
              },
            ),
            if (prefs.mealNudgeHour != null) ...[
              const AppDivider(),
              _ValueRow(
                keyName: 'meal_nudge_time',
                title: tr('Reminder time'),
                value: hourLabel(prefs.mealNudgeHour!),
                onTap: () async {
                  final hour = await _pickHour(context, tr('Reminder time'), prefs.mealNudgeHour!);
                  if (hour != null) _set(prefs.copyWith(mealNudgeHour: hour), {'meal_nudge_hour': hour});
                },
              ),
            ],
          ]),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('QUIET HOURS', style: AppType.sectionLabel()),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _ValueRow(
              keyName: 'quiet_start',
              title: tr('Quiet from'),
              value: hourLabel(prefs.quietStart),
              onTap: () async {
                final hour = await _pickHour(context, tr('Quiet from'), prefs.quietStart);
                if (hour != null) _set(prefs.copyWith(quietStart: hour), {'quiet_start': hour});
              },
            ),
            const AppDivider(),
            _ValueRow(
              keyName: 'quiet_end',
              title: tr('Until'),
              value: hourLabel(prefs.quietEnd),
              onTap: () async {
                final hour = await _pickHour(context, tr('Until'), prefs.quietEnd);
                if (hour != null) _set(prefs.copyWith(quietEnd: hour), {'quiet_end': hour});
              },
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          prefs.quietStart == prefs.quietEnd
              ? tr('No quiet hours set.')
              : tr('Nothing arrives between {v1} and {v2}.', {'v1': hourLabel(prefs.quietStart), 'v2': hourLabel(prefs.quietEnd)}),
          key: ValueKey('quiet_summary'),
          style: AppType.caption(color: TrackerColors.textTertiary),
        ),
        SizedBox(height: AppSpacing.xl),
        if (paused)
          AppButton(
            key: ValueKey('resume'),
            label: tr('Resume notifications'),
            onPressed: () => _set(prefs.copyWith(pausedUntil: null), {'pause_days': 0}),
          )
        else
          AppButton.glass(
            key: ValueKey('pause'),
            label: tr('Pause everything for a week'),
            icon: CupertinoIcons.pause_circle,
            onPressed: () => _set(
              prefs.copyWith(pausedUntil: DateTime.now().add(Duration(days: 7))),
              {'pause_days': 7},
            ),
          ),
        if (paused) ...[
          SizedBox(height: 6),
          Text(
            tr('Paused until {v1}.', {'v1': _dayLabel(prefs.pausedUntil!)}),
            key: ValueKey('paused_note'),
            style: AppType.caption(color: TrackerColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

String _dayLabel(DateTime d) {
  final months = [tr('Jan'), tr('Feb'), tr('Mar'), tr('Apr'), tr('May'), tr('Jun'), tr('Jul'), tr('Aug'), tr('Sep'), tr('Oct'), tr('Nov'), tr('Dec')];
  return '${months[d.month - 1]} ${d.day}';
}

Future<int?> _pickHour(BuildContext context, String title, int initial) {
  var selected = initial;
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (sheet) => Container(
      height: 300,
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: TrackerColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              CupertinoButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: Text(tr('Cancel'), style: AppType.button(color: TrackerColors.textSecondary, size: 15)),
              ),
              Expanded(child: Text(title, textAlign: TextAlign.center, style: AppType.headline())),
              CupertinoButton(
                onPressed: () => Navigator.of(sheet).pop(selected),
                child: Text(tr('Done'), style: AppType.button(color: TrackerColors.accentStartText, size: 15)),
              ),
            ]),
          ),
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: initial),
              onSelectedItemChanged: (i) => selected = i,
              children: [for (var h = 0; h < 24; h++) Center(child: Text(hourLabel(h), style: AppType.body(size: 18)))],
            ),
          ),
        ]),
      ),
    ),
  );
}

/// Notifications in this browser: the one place push works today.
class _BrowserPushCard extends StatelessWidget {
  const _BrowserPushCard({required this.state, required this.notifier});

  final WebPushState state;
  final WebPushNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final on = state.status == WebPushStatus.on;
    final canToggle = (state.status == WebPushStatus.on || state.status == WebPushStatus.off) && !state.busy;
    return Column(
      key: const ValueKey('browser_push'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.status == WebPushStatus.installFirst)
          _Notice(
            key: const ValueKey('push_install_first'),
            icon: CupertinoIcons.square_arrow_up,
            text: tr('On iPhone, add NuStreak to your Home Screen first (Share, then Add to Home Screen), then open it from there to turn notifications on.'),
          )
        else if (state.status == WebPushStatus.blocked)
          _Notice(
            key: const ValueKey('push_blocked'),
            icon: CupertinoIcons.bell_slash,
            text: tr("Notifications are blocked for this site. Allow them in your browser's site settings, then come back."),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              _SwitchRow(
                keyName: 'browser_push',
                emoji: '🔔',
                title: tr('Notifications in this browser'),
                subtitle: tr("Friend bites and reminders, even when NuStreak isn't open."),
                value: on,
                onChanged: (v) {
                  if (!canToggle) return;
                  v ? notifier.enable() : notifier.disable();
                },
              ),
              if (on) ...[
                const AppDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CupertinoButton(
                      key: const ValueKey('push_test'),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: state.busy ? null : notifier.sendTest,
                      child: Text(tr('Send a test notification'), style: AppType.callout(color: TrackerColors.accentEnd)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        if (state.message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(state.message!, key: const ValueKey('push_message'), style: AppType.caption(color: TrackerColors.textSecondary, size: 12.5)),
        ],
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.keyName,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppType.headline()),
              const SizedBox(height: 2),
              Text(subtitle, style: AppType.caption(color: TrackerColors.textSecondary)),
            ]),
          ),
          CupertinoSwitch(
            key: ValueKey('switch_$keyName'),
            value: value,
            activeTrackColor: TrackerColors.accentEnd,
            onChanged: onChanged,
          ),
        ]),
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.keyName, required this.title, required this.value, required this.onTap});

  final String keyName;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
        key: ValueKey('row_$keyName'),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Row(children: [
          Expanded(child: Text(title, style: AppType.headline())),
          Text(value, style: AppType.body(color: TrackerColors.accentStartText)),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_right, size: 14, color: TrackerColors.textTertiary),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? TrackerColors.error : TrackerColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? TrackerColors.alpha(TrackerColors.error, 0.12) : TrackerColors.alpha(TrackerColors.textPrimary, 0.05),
        borderRadius: AppRadii.smallAll,
        border: Border.all(color: error ? TrackerColors.alpha(TrackerColors.error, 0.28) : TrackerColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppType.caption(color: color, size: 12.5))),
      ]),
    );
  }
}
