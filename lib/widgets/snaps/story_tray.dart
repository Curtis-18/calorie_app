import 'package:flutter/cupertino.dart';

import '../../models/stories.dart';
import '../../screens/friends_screen.dart' show FriendAvatar;
import '../../theme/app_shapes.dart';
import '../../theme/app_typography.dart';
import '../../theme/tracker_colors.dart';
import '../pressable.dart';
import 'flame.dart';

/// The row of stories at the top of Friends: yours first, then each friend
/// who has posted in the last 24 hours. A glowing ring means something new.
class StoryTray extends StatelessWidget {
  const StoryTray({
    super.key,
    required this.feed,
    required this.myUsername,
    required this.onMine,
    required this.onFriend,
    this.myAvatarUrl,
    this.streakLit,
  });

  final StoryFeed feed;
  final String myUsername;
  final String? myAvatarUrl;

  /// Your own bubble: opens your story, or the camera if it is empty.
  final VoidCallback onMine;
  final void Function(int index) onFriend;

  /// Whether you have both sent a bite today to this friend (their flame burns
  /// rather than being greyed out). Unknown counts as not yet.
  final bool Function(String userId)? streakLit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: feed.friends.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _Bubble(
              key: const ValueKey('my_story'),
              username: myUsername,
              avatarUrl: myAvatarUrl,
              label: 'Your story',
              ring: feed.mine.isEmpty ? _Ring.none : _Ring.seen,
              add: feed.mine.isEmpty,
              onTap: onMine,
            );
          }
          final group = feed.friends[i - 1];
          return _Bubble(
            key: ValueKey('story_${group.userId}'),
            username: group.username,
            avatarUrl: group.avatarUrl,
            label: group.username,
            ring: group.allSeen ? _Ring.seen : _Ring.fresh,
            dim: group.allSeen,
            streak: group.streak,
            streakLit: streakLit?.call(group.userId) ?? false,
            onTap: () => onFriend(i - 1),
          );
        },
      ),
    );
  }
}

enum _Ring { none, seen, fresh }

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.username,
    required this.label,
    required this.ring,
    required this.onTap,
    this.avatarUrl,
    this.add = false,
    this.dim = false,
    this.streak = 0,
    this.streakLit = false,
  });

  final String username;
  final String? avatarUrl;
  final String label;
  final _Ring ring;
  final bool add;
  final bool dim;
  final int streak;
  final bool streakLit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fresh = ring == _Ring.fresh;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: fresh ? TrackerColors.calorieGradient : null,
                    border: fresh
                        ? null
                        : Border.all(
                            color: ring == _Ring.none ? const Color(0x00000000) : TrackerColors.borderStrong,
                            width: 2,
                          ),
                    boxShadow: fresh ? AppDecor.glow(TrackerColors.accentStart, blur: 14, opacity: 0.35) : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: TrackerColors.background),
                    child: FriendAvatar(username: username, size: 56, imageUrl: avatarUrl),
                  ),
                ),
                if (streak > 0)
                  Positioned(
                    right: -6,
                    bottom: -4,
                    child: StreakBadge(compact: true, count: streak, lit: streakLit),
                  ),
                if (add)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: TrackerColors.calorieGradient,
                        border: Border.all(color: TrackerColors.background, width: 2),
                      ),
                      child: Icon(CupertinoIcons.add, size: 13, color: TrackerColors.onAccent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption(
                color: dim ? TrackerColors.textTertiary : TrackerColors.textPrimary,
                size: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
