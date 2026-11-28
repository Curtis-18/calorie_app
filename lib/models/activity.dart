/// One line of the Notifications list. Only bites and reactions from friends:
/// messages and friend requests have their own places and are never here.
enum ActivityKind { bite, reaction }

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.username,
    required this.createdAt,
    required this.seen,
    this.emoji,
    this.snapId,
  });

  final String id;
  final ActivityKind kind;
  final String username;
  final DateTime createdAt;
  final bool seen;

  /// The reaction, for a reaction.
  final String? emoji;

  /// The bite a "bite" line is about, so tapping it can open that bite. Null
  /// for reactions, and from a backend older than 28 Nov 2026 (tapping then
  /// opens Friends, as before).
  final String? snapId;

  /// Null for a kind this version doesn't know, so a newer server never breaks the list.
  static ActivityItem? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final kind = switch (raw['kind']) {
      'bite' => ActivityKind.bite,
      'reaction' => ActivityKind.reaction,
      _ => null,
    };
    final id = raw['id'];
    final at = DateTime.tryParse('${raw['created_at']}');
    if (kind == null || id is! String || at == null) return null;
    final name = raw['username'];
    return ActivityItem(
      id: id,
      kind: kind,
      username: name is String ? name : '',
      createdAt: at.toLocal(),
      seen: raw['seen'] == true,
      emoji: raw['emoji'] is String ? raw['emoji'] as String : null,
      snapId: raw['snap_id'] is String && (raw['snap_id'] as String).isNotEmpty ? raw['snap_id'] as String : null,
    );
  }

  ActivityItem asSeen() => ActivityItem(id: id, kind: kind, username: username, createdAt: createdAt, seen: true, emoji: emoji, snapId: snapId);
}

class ActivityData {
  const ActivityData({this.items = const [], this.unread = 0});

  final List<ActivityItem> items;
  final int unread;

  factory ActivityData.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final unread = json['unread'];
    return ActivityData(
      items: [
        if (raw is List)
          for (final r in raw) ?ActivityItem.fromJson(r),
      ],
      unread: unread is int && unread > 0 ? unread : 0,
    );
  }
}

/// "now", "5m", "2h", "3d": short enough for the end of a row.
String shortAgo(DateTime now, DateTime then, {required String justNow}) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return justNow;
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}
