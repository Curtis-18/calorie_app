import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../providers/messages_provider.dart';
import '../providers/snaps_provider.dart';
import '../screens/bite_flow.dart';
import '../screens/conversations_screen.dart';
import '../screens/snap_viewer_screen.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';
import '../theme/tracker_colors.dart';
import 'pressable.dart';

/// Two tiles under the calorie ring: Bites and Messages.
///
/// NuStreak is about logging what you eat and sharing it with friends, so the
/// sharing half should be one glance and one tap away on the first screen, not
/// only behind the Friends tab. Each tile shows what is waiting (a number and
/// who it is from) and opens it. Bites with nothing waiting is an invitation to
/// send one.
class HomeSocialTiles extends ConsumerWidget {
  const HomeSocialTiles({super.key, this.pickPhoto});

  /// Replaces the camera; for tests.
  final Future<XFile?> Function()? pickPhoto;

  /// What the Bites tile says. Public so it can be tested on its own.
  static String bitesLine(int unseen, String? latestFrom) {
    if (unseen <= 0) return tr('Snap one for your friends');
    if (unseen == 1 || latestFrom == null) return latestFrom == null ? tr('{n} new', {'n': unseen}) : tr('From {name}', {'name': latestFrom});
    return tr('{n} new, latest from {name}', {'n': unseen, 'name': latestFrom});
  }

  /// What the Messages tile says.
  static String messagesLine(int unread, String? latestFrom) {
    if (unread <= 0) return tr('All caught up');
    if (unread == 1 || latestFrom == null) return latestFrom == null ? tr('{n} new', {'n': unread}) : tr('From {name}', {'name': latestFrom});
    return tr('{n} new, latest from {name}', {'n': unread, 'name': latestFrom});
  }

  /// The tile itself: straight to the camera, then pick who gets the bite.
  Future<void> _snap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final shared = await runBiteFlow(context, pickPhoto: pickPhoto);
    if (shared == null || !context.mounted) return;
    await afterBiteShared(context, ref, shared, say: (text) => showBiteToast(context, text));
  }

  /// The small "View" pill: open the bites friends sent you.
  void _viewWaiting(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final unseen = (ref.read(snapInboxProvider).valueOrNull ?? const []).where((s) => !s.viewed).toList();
    if (unseen.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: AppMotion.medium,
        pageBuilder: (_, _, _) => SnapViewerScreen(snaps: unseen, startAt: 0),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
        ),
      ),
    );
  }

  void _openMessages(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(builder: (_) => const ConversationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(snapInboxProvider).valueOrNull ?? const [];
    final unseen = inbox.where((s) => !s.viewed).toList();
    final data = ref.watch(conversationsProvider).valueOrNull;
    final unread = data?.unreadTotal ?? 0;
    final fromChat = data?.conversations.where((c) => c.unread > 0).toList() ?? const [];
    final bitesFrom = unseen.isEmpty ? null : unseen.first.senderUsername;
    final chatFrom = fromChat.isEmpty ? null : fromChat.first.username;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Expanded(
          child: _Tile(
            key: const ValueKey('home_bites_tile'),
            icon: CupertinoIcons.camera_fill,
            title: tr('Bites'),
            subtitle: bitesLine(unseen.length, bitesFrom),
            count: unseen.length,
            hot: unseen.isNotEmpty,
            onTap: () => _snap(context, ref),
            trailing: unseen.isEmpty ? null : _ViewPill(count: unseen.length, onTap: () => _viewWaiting(context, ref)),
            delay: 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            key: const ValueKey('home_messages_tile'),
            icon: CupertinoIcons.chat_bubble_2_fill,
            title: tr('Messages'),
            subtitle: messagesLine(unread, chatFrom),
            count: unread,
            hot: unread > 0,
            onTap: () => _openMessages(context),
            delay: 90,
          ),
        ),
        ],
      ),
    );
  }
}

/// One tile: a round icon, a title, a line of status and a count when there is
/// something waiting. It pops in with a small bounce, the second a moment after
/// the first, and a waiting tile has a warm gradient outline.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.hot,
    required this.onTap,
    required this.delay,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final bool hot;
  final VoidCallback onTap;
  final int delay;

  /// A second row under the tile with its own tap (the Bites "View" pill).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: Duration(milliseconds: 520 + delay),
      curve: Interval(delay / (520 + delay), 1, curve: AppMotion.spring),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.containerAll,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.containerAll,
            color: TrackerColors.surface,
            border: Border.all(
              color: hot ? TrackerColors.alpha(TrackerColors.accentStart, 0.7) : TrackerColors.border,
              width: hot ? 1.5 : 1,
            ),
            boxShadow: hot ? AppDecor.layeredGlow(TrackerColors.accentStart, opacity: 0.14) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                button: true,
                label: '$title. $subtitle',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hot ? TrackerColors.calorieGradient : null,
                            color: hot ? null : TrackerColors.surfaceElevated,
                          ),
                          child: Icon(icon, size: 20, color: hot ? TrackerColors.onAccent : TrackerColors.textSecondary),
                        ),
                        if (count > 0) Positioned(top: -5, right: -5, child: UnreadCount(count: count)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppType.headline(), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption(color: hot ? TrackerColors.accentStartText : TrackerColors.textTertiary, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(height: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// "View 3": opens the bites friends sent you, without leaving the tile's main
/// job (taking a bite) behind.
class _ViewPill extends StatelessWidget {
  const _ViewPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('View waiting bites'),
      excludeSemantics: true,
      child: Pressable(
        key: const ValueKey('home_view_bites'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: TrackerColors.alpha(TrackerColors.accentStart, 0.14),
            border: Border.all(color: TrackerColors.alpha(TrackerColors.accentStart, 0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            tr('View {n}', {'n': count}),
            style: AppType.caption(color: TrackerColors.accentStartText, size: 13),
          ),
        ),
      ),
    );
  }
}
