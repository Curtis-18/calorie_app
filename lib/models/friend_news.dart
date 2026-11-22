import '../l10n/app_strings.dart';
import 'snaps.dart';
import 'stories.dart';

/// Something from a friend that is waiting to be opened: a bite they sent that
/// you have not viewed, and/or story photos you have not seen. Only ever the
/// good news: no "last active", and a friend with nothing new has no mark.
class FriendNews {
  const FriendNews({required this.bite, required this.story, required this.at});

  final bool bite;
  final bool story;

  /// When the newest unseen thing arrived.
  final DateTime at;

  /// "New bite", "New story" or "New bite and story".
  String get label => bite && story
      ? tr('New bite and story')
      : bite
          ? tr('New bite')
          : tr('New story');
}

/// What is new from [userId], or null when there is nothing unseen. Expired
/// items are ignored (the server drops them anyway; this just keeps a stale
/// copy on screen from showing a mark for something that can no longer open).
FriendNews? friendNews(String userId, List<InboxSnap> inbox, StoryFeed? feed, {DateTime? now}) {
  final t = (now ?? DateTime.now()).toUtc();
  final bites = inbox.where((s) => s.senderId == userId && !s.viewed && s.expiresAt.toUtc().isAfter(t)).toList();
  final stories = [
    for (final g in feed?.friends ?? const <FriendStories>[])
      if (g.userId == userId)
        for (final s in g.stories)
          if (!s.viewed && s.expiresAt.toUtc().isAfter(t)) s,
  ];
  if (bites.isEmpty && stories.isEmpty) return null;
  final times = [for (final b in bites) b.createdAt, for (final s in stories) s.createdAt];
  times.sort();
  return FriendNews(bite: bites.isNotEmpty, story: stories.isNotEmpty, at: times.last);
}

/// "just now", "12 min ago", "3h ago". Nothing is older than a day (bites and
/// stories expire after 24 hours), so there is no "days ago".
String agoLabel(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).toUtc().difference(at.toUtc());
  if (d.inMinutes < 1) return tr('just now');
  if (d.inMinutes < 60) return tr('{n} min ago', {'n': '${d.inMinutes}'});
  return tr('{n}h ago', {'n': '${d.inHours}'});
}
