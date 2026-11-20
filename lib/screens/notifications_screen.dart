import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/whats_new.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(whatsNewProvider.notifier).markSeen();
    });
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
