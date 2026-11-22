import '../l10n/app_strings.dart';

/// One-tap replies to a friend's bite. They arrive as an ordinary chat message
/// from you, so the friend answers them like any other message. Kept warm and
/// food-flavoured; nothing that polices what a friend eats or drinks.
class QuickReply {
  const QuickReply(this.id, this._text);

  /// Stable name for keys and tests.
  final String id;
  final String _text;

  /// The words, in the sender's own language.
  String get text => tr(_text);
}

const quickReplies = [
  QuickReply('looks_great', 'Looks great'),
  QuickReply('save_plate', 'Save me a plate'),
  QuickReply('drop_recipe', 'Drop the recipe'),
];
