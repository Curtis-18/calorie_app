/// Someone on the other end of a friendship, a request or a block.
class Person {
  const Person({
    required this.userId,
    required this.username,
    required this.since,
    this.friendshipId,
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
  final DateTime since;

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        friendshipId: json['friendship_id'] as String?,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        since: DateTime.parse(json['since'] as String),
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        sentToday: json['sent_today'] as bool? ?? false,
        theySentToday: json['they_sent_today'] as bool? ?? false,
      );
}

class FriendsData {
  const FriendsData({
    required this.friends,
    required this.incoming,
    required this.outgoing,
    required this.limit,
    this.myUsername,
  });

  final List<Person> friends;
  final List<Person> incoming;
  final List<Person> outgoing;
  final int limit;
  final String? myUsername;

  factory FriendsData.fromJson(Map<String, dynamic> json, {String? myUsername}) {
    List<Person> people(String key) =>
        ((json[key] as List?) ?? const []).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
    return FriendsData(
      friends: people('friends'),
      incoming: people('incoming'),
      outgoing: people('outgoing'),
      limit: (json['limit'] as num?)?.toInt() ?? 100,
      myUsername: myUsername,
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
