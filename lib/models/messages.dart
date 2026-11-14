/// Where a message is on its way to the server.
enum SendState { sent, sending, failed }

/// The longest message the server accepts.
const int maxMessageChars = 1000;

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.state = SendState.sent,
    this.error,
  });

  final String id;
  final bool mine;
  final String body;
  final DateTime createdAt;

  /// For messages I sent: when they opened the conversation ("Seen").
  final DateTime? readAt;
  final SendState state;

  /// Why a failed message failed, shown under it.
  final String? error;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        mine: json['mine'] as bool,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String).toLocal(),
      );

  ChatMessage copyWith({SendState? state, String? error, bool clearError = false}) => ChatMessage(
        id: id,
        mine: mine,
        body: body,
        createdAt: createdAt,
        readAt: readAt,
        state: state ?? this.state,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatThread {
  const ChatThread({required this.messages, required this.hasMore});

  /// Oldest first.
  final List<ChatMessage> messages;
  final bool hasMore;

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
        messages: ((json['messages'] as List?) ?? const [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['has_more'] as bool? ?? false,
      );
}

class Conversation {
  const Conversation({
    required this.userId,
    required this.username,
    required this.lastBody,
    required this.lastMine,
    required this.lastAt,
    required this.unread,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final String lastBody;
  final bool lastMine;
  final DateTime lastAt;
  final int unread;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        lastBody: json['last_body'] as String,
        lastMine: json['last_mine'] as bool,
        lastAt: DateTime.parse(json['last_at'] as String).toLocal(),
        unread: (json['unread'] as num?)?.toInt() ?? 0,
      );

  Conversation copyWith({int? unread}) => Conversation(
        userId: userId,
        username: username,
        avatarUrl: avatarUrl,
        lastBody: lastBody,
        lastMine: lastMine,
        lastAt: lastAt,
        unread: unread ?? this.unread,
      );
}

class ConversationsData {
  const ConversationsData(this.conversations);

  /// Newest first.
  final List<Conversation> conversations;

  int get unreadTotal => conversations.fold(0, (sum, c) => sum + c.unread);

  Conversation? forUser(String userId) {
    for (final c in conversations) {
      if (c.userId == userId) return c;
    }
    return null;
  }

  factory ConversationsData.fromJson(Map<String, dynamic> json) => ConversationsData(
        ((json['conversations'] as List?) ?? const [])
            .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// "14:05" today, "Yesterday 14:05", "Mon 14:05" within the week, otherwise
/// "12 Nov 14:05". For the small time lines in a conversation.
String chatTimeLabel(DateTime at, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(at.hour)}:${two(at.minute)}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return time;
  if (diff == 1) return 'Yesterday $time';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (diff > 1 && diff < 7) return '${weekdays[at.weekday - 1]} $time';
  return '${at.day} ${months[at.month - 1]} $time';
}

/// The short time for the conversation list: the time today, otherwise the day.
String conversationTimeLabel(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return chatTimeLabel(at, now);
  if (diff == 1) return 'Yesterday';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  if (diff > 1 && diff < 7) return weekdays[at.weekday - 1];
  return '${at.day} ${months[at.month - 1]}';
}
