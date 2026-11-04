/// The five reactions a friend can send back, matching the backend.
const snapReactions = ['🔥', '😋', '😮', '❤️', '👏'];

/// A snap a friend sent you that hasn't expired yet.
class InboxSnap {
  const InboxSnap({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.viewed,
    required this.reaction,
    required this.imageUrl,
  });

  final String id;
  final String senderId;
  final String senderUsername;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewed;
  final String? reaction;
  final String? imageUrl;

  factory InboxSnap.fromJson(Map<String, dynamic> json) => InboxSnap(
        id: json['snap_id'] as String,
        senderId: json['sender_id'] as String,
        senderUsername: json['sender_username'] as String,
        caption: json['caption'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        viewed: json['viewed'] as bool? ?? false,
        reaction: json['reaction'] as String?,
        imageUrl: json['image_url'] as String?,
      );

  InboxSnap copyWith({bool? viewed, String? reaction}) => InboxSnap(
        id: id,
        senderId: senderId,
        senderUsername: senderUsername,
        caption: caption,
        createdAt: createdAt,
        expiresAt: expiresAt,
        viewed: viewed ?? this.viewed,
        reaction: reaction ?? this.reaction,
        imageUrl: imageUrl,
      );
}

class SentRecipient {
  const SentRecipient({required this.userId, required this.username, required this.viewed, required this.reaction});

  final String userId;
  final String username;
  final bool viewed;
  final String? reaction;

  factory SentRecipient.fromJson(Map<String, dynamic> json) => SentRecipient(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        viewed: json['viewed'] as bool? ?? false,
        reaction: json['reaction'] as String?,
      );
}

/// A snap you sent, with who opened it and who reacted.
class SentSnap {
  const SentSnap({
    required this.id,
    required this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.imageUrl,
    required this.recipients,
  });

  final String id;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? imageUrl;
  final List<SentRecipient> recipients;

  factory SentSnap.fromJson(Map<String, dynamic> json) => SentSnap(
        id: json['snap_id'] as String,
        caption: json['caption'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        imageUrl: json['image_url'] as String?,
        recipients: ((json['recipients'] as List?) ?? const [])
            .map((e) => SentRecipient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Where a pair streak stands after a send.
class SendOutcome {
  const SendOutcome({required this.userId, required this.username, required this.streak, required this.completedToday});

  final String userId;
  final String username;
  final int streak;

  /// This snap completed today's pair: both of you have now sent. Time for the flame.
  final bool completedToday;

  factory SendOutcome.fromJson(Map<String, dynamic> json) => SendOutcome(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        completedToday: json['completed_today'] as bool? ?? false,
      );
}
