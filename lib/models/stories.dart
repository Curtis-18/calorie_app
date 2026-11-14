/// One photo in a friend's story, as you see it.
class Story {
  const Story({
    required this.id,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.imageUrl,
    this.viewed = false,
    this.reaction,
  });

  final String id;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? imageUrl;
  final bool viewed;

  /// Your reaction to it, if you sent one.
  final String? reaction;

  factory Story.fromJson(Map<String, dynamic> json) => Story(
        id: json['story_id'] as String,
        caption: json['caption'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        imageUrl: json['image_url'] as String?,
        viewed: json['viewed'] as bool? ?? false,
        reaction: json['reaction'] as String?,
      );

  Story copyWith({bool? viewed, String? reaction}) => Story(
        id: id,
        caption: caption,
        createdAt: createdAt,
        expiresAt: expiresAt,
        imageUrl: imageUrl,
        viewed: viewed ?? this.viewed,
        reaction: reaction ?? this.reaction,
      );
}

/// A friend who has looked at one of your stories.
class StoryViewer {
  const StoryViewer({required this.userId, required this.username, this.avatarUrl, this.reaction});

  final String userId;
  final String username;
  final String? avatarUrl;
  final String? reaction;

  factory StoryViewer.fromJson(Map<String, dynamic> json) => StoryViewer(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        reaction: json['reaction'] as String?,
      );
}

/// One photo in your own story, with who has seen it.
class MyStory {
  const MyStory({
    required this.id,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.imageUrl,
    required this.viewers,
  });

  final String id;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? imageUrl;
  final List<StoryViewer> viewers;

  factory MyStory.fromJson(Map<String, dynamic> json) => MyStory(
        id: json['story_id'] as String,
        caption: json['caption'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        imageUrl: json['image_url'] as String?,
        viewers: ((json['viewers'] as List?) ?? const [])
            .map((e) => StoryViewer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A friend and the photos on their story right now, oldest first.
class FriendStories {
  const FriendStories({
    required this.userId,
    required this.username,
    required this.stories,
    this.avatarUrl,
    this.streak = 0,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final int streak;
  final List<Story> stories;

  bool get allSeen => stories.every((s) => s.viewed);

  /// Where to start playing: the first photo you haven't seen.
  int get firstUnseen {
    final i = stories.indexWhere((s) => !s.viewed);
    return i < 0 ? 0 : i;
  }

  factory FriendStories.fromJson(Map<String, dynamic> json) => FriendStories(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        stories: ((json['stories'] as List?) ?? const [])
            .map((e) => Story.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  FriendStories withStories(List<Story> stories) =>
      FriendStories(userId: userId, username: username, avatarUrl: avatarUrl, streak: streak, stories: stories);
}

class StoryFeed {
  const StoryFeed({this.mine = const [], this.friends = const []});

  final List<MyStory> mine;
  final List<FriendStories> friends;

  factory StoryFeed.fromJson(Map<String, dynamic> json) => StoryFeed(
        mine: ((json['mine'] as List?) ?? const []).map((e) => MyStory.fromJson(e as Map<String, dynamic>)).toList(),
        friends: ((json['friends'] as List?) ?? const [])
            .map((e) => FriendStories.fromJson(e as Map<String, dynamic>))
            .where((g) => g.stories.isNotEmpty)
            .toList(),
      );
}
