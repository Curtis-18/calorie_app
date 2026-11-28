import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/snaps.dart';
import '../models/whats_new.dart';
import '../providers/shell_provider.dart';
import '../providers/snaps_provider.dart';
import '../theme/app_motion.dart';
import 'snap_viewer_screen.dart';
import '../models/activity.dart';
import '../providers/activity_provider.dart';
import '../providers/whats_new_provider.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import '../widgets/app_card.dart';
import 'notification_settings_screen.dart';
import '../l10n/app_strings.dart';

/// Notifications: what's new in the app. Opening it clears the unread dot.
/// The gear opens the push-notification settings (what to tell you, quiet
/// hours, pause).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Whether it was unread when opened, so this visit can still mark it "New".
  late final bool _wasUnread = ref.read(whatsNewProvider);

  /// The lines that were unseen when this visit began, so they can still be
  /// marked "new" even though opening the list counts them as seen.
  Set<String> _newIds = {};

  @override
  void initState() {
    super.initState();
    _newIds = {for (final i in ref.read(activityProvider).items) if (!i.seen) i.id};
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(whatsNewProvider.notifier).markSeen();
      final notifier = ref.read(activityProvider.notifier);
      await notifier.load(); // the latest, in case something arrived since the last refresh
      if (!mounted) return;
      setState(() => _newIds = {..._newIds, for (final i in ref.read(activityProvider).items) if (!i.seen) i.id});
      notifier.markSeen();
    });
  }

  void _openFriends() {
    // Back to the tabs, on Friends, where the bites are.
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(shellTabProvider.notifier).state = ShellTab.friends;
  }

  /// A bite line opens that exact bite while it is still in the inbox (bites
  /// last 24 hours). Anything else, or a bite that has gone, opens Friends.
  Future<void> _open(ActivityItem item) async {
    final id = item.snapId;
    if (item.kind != ActivityKind.bite || id == null) return _openFriends();
    final inbox = ref.read(snapInboxProvider.notifier);
    if (!ref.read(snapInboxProvider).hasValue) await inbox.load(); // not loaded yet this session
    if (!mounted) return;
    final snaps = ref.read(snapInboxProvider).valueOrNull ?? const <InboxSnap>[];
    final index = snaps.indexWhere((s) => s.id == id && s.expiresAt.isAfter(DateTime.now()));
    if (index < 0) return _openFriends();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: AppMotion.medium,
        pageBuilder: (_, _, _) => SnapViewerScreen(snaps: snaps, startAt: index),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: TrackerColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(tr('Notifications')),
        backgroundColor: TrackerColors.background,
        trailing: CupertinoButton(
          key: const ValueKey('notification_settings'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32),
          onPressed: () => Navigator.push(context, CupertinoPageRoute<void>(builder: (_) => const NotificationSettingsScreen())),
          child: Icon(CupertinoIcons.gear_alt, size: 22, color: TrackerColors.textSecondary),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            _FromFriends(items: ref.watch(activityProvider).items, newIds: _newIds, onOpen: _open),
            for (final release in whatsNewReleases) ...[
              _ReleaseCard(release: release, isNew: _wasUnread && release.id == latestWhatsNew.id),
              const SizedBox(height: AppSpacing.lg),
            ],
            Center(child: Text(tr('That’s everything for now.'), style: AppType.caption(size: 12))),
          ],
        ),
      ),
    );
  }
}

/// Bites and reactions from friends, newest first. Messages and friend
/// requests are never listed here.
class _FromFriends extends StatelessWidget {
  const _FromFriends({required this.items, required this.newIds, required this.onOpen});

  final List<ActivityItem> items;
  final Set<String> newIds;
  final void Function(ActivityItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        key: const ValueKey('from_friends'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(tr('From friends').toUpperCase(), style: AppType.sectionLabel()),
            ),
            if (items.isEmpty)
              Padding(
                key: const ValueKey('from_friends_empty'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(tr('Bites and reactions from friends show up here.'), style: AppType.callout(size: 13)),
              ),
            for (final item in items)
              CupertinoButton(
                key: ValueKey('activity_${item.id}'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(0, 44),
                onPressed: () => onOpen(item),
                child: Row(
                  children: [
                    Text(item.kind == ActivityKind.bite ? '🍜' : (item.emoji ?? '🔥'), style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.kind == ActivityKind.bite
                            ? tr('{name} sent you a bite', {'name': item.username})
                            : tr('{name} reacted to your bite', {'name': item.username}),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body(size: 15),
                      ),
                    ),
                    if (newIds.contains(item.id))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(key: ValueKey('activity_new_${item.id}'), width: 8, height: 8, decoration: BoxDecoration(color: TrackerColors.accentStart, shape: BoxShape.circle)),
                      ),
                    Text(shortAgo(now, item.createdAt, justNow: tr('now')), style: AppType.caption(size: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.isNew});

  final WhatsNewRelease release;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey('release_${release.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tr(release.title), style: AppType.title())),
              if (isNew)
                Container(
                  key: const ValueKey('new_pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TrackerColors.alpha(TrackerColors.accentEnd, 0.18),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text('NEW', style: AppType.caption(size: 10, color: TrackerColors.accentEnd)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < release.items.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TrackerColors.alpha(TrackerColors.accentEnd, 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(release.items[i].icon, size: 18, color: TrackerColors.accentEnd),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(release.items[i].title), style: AppType.body(size: 15)),
                      const SizedBox(height: 2),
                      Text(tr(release.items[i].body), style: AppType.callout(size: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A small dot to put on something that leads to the unread notifications.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('unread_dot'),
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: TrackerColors.accentStart, shape: BoxShape.circle),
      );
}
