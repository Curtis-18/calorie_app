import '../l10n/app_strings.dart';
/// Where a message is on its way to the server.
enum SendState { sent, sending, failed }

/// The longest message the server accepts.
const int maxMessageChars = 1000;

/// A card under a message's text. Only recipes exist so far; anything else the
/// server might add later is ignored, and the text still shows.
class MessageAttachment {
  const MessageAttachment({required this.recipeId, required this.title, required this.calories});

  final String recipeId;
  final String title;
  final int calories;

  static MessageAttachment? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> || raw['kind'] != 'recipe') return null;
    final id = raw['id'];
    final title = raw['title'];
    if (id is! String || title is! String) return null;
    return MessageAttachment(recipeId: id, title: title, calories: ((raw['calories'] as num?) ?? 0).toInt());
  }
}

/// One of the person's own recipes the coach named in its answer. The numbers
/// come from the saved recipe (the server reads them), not from the coach's words.
class CoachSuggestion {
  const CoachSuggestion({required this.recipeId, required this.title, required this.calories});

  final String recipeId;
  final String title;
  final int calories;

  static CoachSuggestion? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['recipe_id'];
    final title = raw['title'];
    if (id is! String || title is! String || title.isEmpty) return null;
    return CoachSuggestion(recipeId: id, title: title, calories: ((raw['calories'] as num?) ?? 0).toInt());
  }
}

class WorkoutStep {
  const WorkoutStep({required this.name, required this.cue, required this.amount});

  final String name;
  final String cue;
  final String amount;
}

class WorkoutSection {
  const WorkoutSection({required this.title, required this.steps, this.repeat});

  final String title;
  final List<WorkoutStep> steps;

  /// "Repeat the main moves 3 times...", only for a section done in rounds.
  final String? repeat;
}

/// A routine from the server's curated library, already written in the
/// person's language. The coach only names it; the moves are fixed text.
class CoachWorkout {
  const CoachWorkout({
    required this.id,
    required this.name,
    required this.duration,
    required this.focus,
    required this.summary,
    required this.sections,
    required this.safety,
  });

  final String id;
  final String name;
  final String duration;
  final String focus;
  final String summary;
  final List<WorkoutSection> sections;
  final String safety;

  static CoachWorkout? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final name = raw['name'];
    final rawSections = raw['sections'];
    if (id is! String || name is! String || name.isEmpty || rawSections is! List) return null;
    final sections = <WorkoutSection>[];
    for (final s in rawSections) {
      if (s is! Map<String, dynamic> || s['title'] is! String || s['steps'] is! List) continue;
      final steps = [
        for (final st in s['steps'] as List)
          if (st is Map<String, dynamic> && st['name'] is String)
            WorkoutStep(name: st['name'] as String, cue: (st['cue'] as String?) ?? '', amount: (st['amount'] as String?) ?? ''),
      ];
      if (steps.isEmpty) continue;
      sections.add(WorkoutSection(title: s['title'] as String, steps: steps, repeat: s['repeat'] as String?));
    }
    if (sections.isEmpty) return null;
    return CoachWorkout(
      id: id,
      name: name,
      duration: (raw['duration'] as String?) ?? '',
      focus: (raw['focus'] as String?) ?? '',
      summary: (raw['summary'] as String?) ?? '',
      sections: sections,
      safety: (raw['safety'] as String?) ?? '',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.state = SendState.sent,
    this.error,
    this.attachment,
    this.suggestions = const [],
    this.workouts = const [],
  });

  final MessageAttachment? attachment;

  /// Recipes the coach just named, shown as tap-to-open cards under its answer.
  /// Only on the live answer: the server does not store them, so a reloaded
  /// thread has the words without the cards.
  final List<CoachSuggestion> suggestions;

  /// The routine the coach just named (at most one), also live-only.
  final List<CoachWorkout> workouts;
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
        attachment: MessageAttachment.fromJson(json['attachment']),
      );

  /// A turn with the AI coach: the person's own turns are `mine`; the coach's
  /// are not. No read receipts, no attachments.
  factory ChatMessage.fromCoachJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        mine: json['role'] == 'user',
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        suggestions: [
          if (json['suggestions'] is List) for (final j in json['suggestions'] as List) ?CoachSuggestion.fromJson(j),
        ],
        workouts: [
          if (json['workouts'] is List) for (final j in json['workouts'] as List) ?CoachWorkout.fromJson(j),
        ],
      );

  ChatMessage copyWith({SendState? state, String? error, bool clearError = false}) => ChatMessage(
        id: id,
        mine: mine,
        body: body,
        createdAt: createdAt,
        readAt: readAt,
        state: state ?? this.state,
        error: clearError ? null : (error ?? this.error),
        attachment: attachment,
        suggestions: suggestions,
        workouts: workouts,
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
  ConversationsData(this.conversations);

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
        ((json['conversations'] as List?) ?? [])
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
  if (diff == 1) return tr('Yesterday {time}', {'time': time});
  final weekdays = [tr('Mon'), tr('Tue'), tr('Wed'), tr('Thu'), tr('Fri'), tr('Sat'), tr('Sun')];
  final months = [tr('Jan'), tr('Feb'), tr('Mar'), tr('Apr'), tr('May'), tr('Jun'), tr('Jul'), tr('Aug'), tr('Sep'), tr('Oct'), tr('Nov'), tr('Dec')];
  if (diff > 1 && diff < 7) return '${weekdays[at.weekday - 1]} $time';
  return '${at.day} ${months[at.month - 1]} $time';
}

/// The short time for the conversation list: the time today, otherwise the day.
String conversationTimeLabel(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return chatTimeLabel(at, now);
  if (diff == 1) return tr('Yesterday');
  final weekdays = [tr('Mon'), tr('Tue'), tr('Wed'), tr('Thu'), tr('Fri'), tr('Sat'), tr('Sun')];
  final months = [tr('Jan'), tr('Feb'), tr('Mar'), tr('Apr'), tr('May'), tr('Jun'), tr('Jul'), tr('Aug'), tr('Sep'), tr('Oct'), tr('Nov'), tr('Dec')];
  if (diff > 1 && diff < 7) return weekdays[at.weekday - 1];
  return '${at.day} ${months[at.month - 1]}';
}
