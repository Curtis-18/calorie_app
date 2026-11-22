import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/quick_replies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppStrings.active = 'en');

  test('the three replies, in order', () {
    expect(quickReplies.map((r) => r.text), ['Looks great', 'Save me a plate', 'Drop the recipe']);
    expect({for (final r in quickReplies) r.id}.length, 3);
  });

  test('warm and food-flavoured: nothing that polices what a friend eats or drinks', () {
    final all = quickReplies.map((r) => r.text).join(' ').toLowerCase();
    for (final banned in ['water', 'calorie', 'too much', 'healthy', 'diet', 'cheat', 'treat', 'lazy']) {
      expect(all.contains(banned), isFalse, reason: banned);
    }
  });

  test('every language has them', () {
    for (final lang in ['es', 'fr', 'de', 'pt', 'it']) {
      for (final k in ['Looks great', 'Save me a plate', 'Drop the recipe', 'Sent to {name}']) {
        expect(translationTables[lang]!.containsKey(k), isTrue, reason: '$lang: $k');
      }
    }
  });
}
