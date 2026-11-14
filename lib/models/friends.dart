/// Someone on the other end of a friendship, a request or a block.
class Person {
  const Person({
    required this.userId,
    required this.username,
    required this.since,
    this.friendshipId,
    this.avatarUrl,
    this.streak = 0,
    this.sentToday = false,
    this.theySentToday = false,
  });

  /// Days in a row you have both sent each other a snap. Only set on friends.
  final int streak;
  final bool sentToday;
  final bool theySentToday;

  /// What to send back to accept, decline, remove or block. Null for blocks.
  final String? friendshipId;
  final String userId;
  final String username;

  /// Their profile picture, if they set one.
  final String? avatarUrl;
  final DateTime since;

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        friendshipId: json['friendship_id'] as String?,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        since: DateTime.parse(json['since'] as String),
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        sentToday: json['sent_today'] as bool? ?? false,
        theySentToday: json['they_sent_today'] as bool? ?? false,
      );
}

/// The people you have the longest streaks with come first, always; equal
/// streaks go by name. The server sends this order too; doing it here as well
/// means every list in the app agrees whatever the server version.
List<Person> byStreak(List<Person> friends) {
  return [...friends]..sort((a, b) {
      final streak = b.streak.compareTo(a.streak);
      return streak != 0 ? streak : a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });
}

class FriendsData {
  const FriendsData({
    required this.friends,
    required this.incoming,
    required this.outgoing,
    required this.limit,
    this.myUsername,
    this.myAvatarUrl,
  });

  final List<Person> friends;
  final List<Person> incoming;
  final List<Person> outgoing;
  final int limit;
  final String? myUsername;
  final String? myAvatarUrl;

  factory FriendsData.fromJson(Map<String, dynamic> json, {String? myUsername, String? myAvatarUrl}) {
    List<Person> people(String key) =>
        ((json[key] as List?) ?? const []).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
    return FriendsData(
      friends: byStreak(people('friends')),
      incoming: people('incoming'),
      outgoing: people('outgoing'),
      limit: (json['limit'] as num?)?.toInt() ?? 100,
      myUsername: myUsername,
      myAvatarUrl: myAvatarUrl,
    );
  }

  bool get isEmpty => friends.isEmpty && incoming.isEmpty && outgoing.isEmpty;
}

/// What happened when a request was sent.
enum RequestOutcome {
  sent,
  accepted, // they had already asked us
  alreadyFriends,
  alreadySent;

  static RequestOutcome fromApi(String? value) => switch (value) {
        'accepted' => accepted,
        'already_friends' => alreadyFriends,
        'already_sent' => alreadySent,
        _ => sent,
      };
}

class RequestResult {
  const RequestResult(this.outcome, this.username);
  final RequestOutcome outcome;
  final String username;
}
