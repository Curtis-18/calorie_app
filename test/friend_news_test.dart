import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/friend_news.dart';
import 'package:calorie_app/models/snaps.dart';
import 'package:calorie_app/models/stories.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 22, 12);

InboxSnap _snap(String from, {bool viewed = false, Duration age = const Duration(hours: 1), Duration left = const Duration(hours: 23)}) =>
    InboxSnap(
      id: '$from-$age',
      senderId: 'u-$from',
      senderUsername: from,
      caption: null,
      createdAt: _now.subtract(age),
      expiresAt: _now.add(left),
      viewed: viewed,
      reaction: null,
      imageUrl: null,
    );

Story _story({bool viewed = false, Duration age = const Duration(hours: 1), Duration left = const Duration(hours: 23)}) => Story(
      id: 's-$age',
      caption: null,
      createdAt: _now.subtract(age),
      expiresAt: _now.add(left),
      imageUrl: null,
      viewed: viewed,
    );

StoryFeed _feed(String who, List<Story> stories) =>
    StoryFeed(friends: [FriendStories(userId: 'u-$who', username: who, stories: stories)]);

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('what is new from a friend', () {
    test('nothing unseen means no mark at all', () {
      expect(friendNews('u-sam', [], null, now: _now), isNull);
      expect(friendNews('u-sam', [_snap('sam', viewed: true)], _feed('sam', [_story(viewed: true)]), now: _now), isNull);
    });

    test('an unseen bite from that friend counts, a bite from someone else does not', () {
      final n = friendNews('u-sam', [_snap('sam'), _snap('bea')], null, now: _now)!;
      expect(n.bite, isTrue);
      expect(n.story, isFalse);
      expect(n.label, 'New bite');
      expect(friendNews('u-cy', [_snap('sam')], null, now: _now), isNull);
    });

    test('an unseen story counts, and so do both together', () {
      expect(friendNews('u-sam', [], _feed('sam', [_story()]), now: _now)!.label, 'New story');
      expect(friendNews('u-sam', [_snap('sam')], _feed('sam', [_story()]), now: _now)!.label, 'New bite and story');
    });

    test('a story group that is fully seen, or a viewed bite, adds nothing', () {
      final n = friendNews('u-sam', [_snap('sam', viewed: true)], _feed('sam', [_story(viewed: true), _story(age: const Duration(hours: 3))]), now: _now)!;
      expect(n.story, isTrue);
      expect(n.bite, isFalse);
    });

    test('expired items are ignored', () {
      expect(friendNews('u-sam', [_snap('sam', left: const Duration(minutes: -1))], null, now: _now), isNull);
      expect(friendNews('u-sam', [], _feed('sam', [_story(left: Duration.zero)]), now: _now), isNull);
    });

    test('the time is when the newest unseen thing arrived', () {
      final n = friendNews(
        'u-sam',
        [_snap('sam', age: const Duration(hours: 5))],
        _feed('sam', [_story(age: const Duration(hours: 2)), _story(age: const Duration(hours: 9))]),
        now: _now,
      )!;
      expect(n.at, _now.subtract(const Duration(hours: 2)));
    });
  });

  group('how long ago', () {
    test('reads just now, minutes, then hours', () {
      expect(agoLabel(_now.subtract(const Duration(seconds: 20)), now: _now), 'just now');
      expect(agoLabel(_now.subtract(const Duration(minutes: 12)), now: _now), '12 min ago');
      expect(agoLabel(_now.subtract(const Duration(minutes: 59)), now: _now), '59 min ago');
      expect(agoLabel(_now.subtract(const Duration(hours: 3, minutes: 40)), now: _now), '3h ago');
      expect(agoLabel(_now.subtract(const Duration(hours: 23)), now: _now), '23h ago');
    });
  });

  group('the wording', () {
    test('is only ever positive: no "last active", no missing-post state', () {
      final all = ['New bite', 'New story', 'New bite and story', 'just now', '{n} min ago', '{n}h ago'].join(' ').toLowerCase();
      for (final banned in ['last active', 'inactive', 'hasn', 'missed', 'offline']) {
        expect(all.contains(banned), isFalse, reason: banned);
      }
    });

    test('is translated into every language', () {
      for (final lang in ['es', 'fr', 'de', 'pt', 'it']) {
        for (final k in ['New bite', 'New story', 'New bite and story', 'just now', '{n} min ago', '{n}h ago']) {
          expect(translationTables[lang]!.containsKey(k), isTrue, reason: '$lang: $k');
        }
      }
    });
  });
}
