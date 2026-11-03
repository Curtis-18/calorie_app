import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:calorie_app/models/progress.dart';
import 'package:calorie_app/models/share_card.dart';
import 'package:calorie_app/models/weight.dart';
import 'package:calorie_app/providers/progress_provider.dart';
import 'package:calorie_app/providers/weight_provider.dart';
import 'package:calorie_app/services/weight_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/share/share_card.dart';
import 'package:calorie_app/widgets/share/share_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

AchievementInfo _badge(String id, {bool unlocked = true, String? on}) => AchievementInfo(
  id: id,
  title: id,
  description: 'desc $id',
  unlocked: unlocked,
  unlockedOn: on == null ? null : DateTime.parse(on),
  progress: unlocked ? 1 : 0,
  goal: 1,
);

ProgressData _progress({int streak = 12, int best = 20, List<AchievementInfo>? badges}) => ProgressData(
  date: DateTime(2026, 11, 3),
  streak: StreakInfo(
    current: streak,
    best: best,
    tier: streak >= 7 ? FlameTier.flame : FlameTier.spark,
    freezes: 1,
    maxFreezes: 2,
    loggedToday: true,
  ),
  level: const LevelInfo(level: 4, xp: 720, levelXp: 600, nextLevelXp: 1000),
  today: const TodayInfo(xp: 40, perfectDay: false),
  achievements:
      badges ??
      [
        _badge('first_bite', on: '2026-10-01'),
        _badge('on_fire', on: '2026-10-20'),
        _badge('snapshot', on: '2026-10-05'),
        _badge('centurion', unlocked: false),
      ],
);

Map<String, dynamic> _historyJson(List<(String, double, double)> p) => {
  'entries': [
    for (final (d, w, t) in p) {'date': d, 'weight_kg': w, 'trend_kg': t},
  ],
  'summary': p.isEmpty
      ? null
      : {
          'start_kg': p.first.$2,
          'start_date': p.first.$1,
          'current_kg': p.last.$2,
          'trend_kg': p.last.$3,
          'change_kg': double.parse((p.last.$3 - p.first.$2).toStringAsFixed(1)),
          'lowest_kg': p.map((e) => e.$2).reduce((a, b) => a < b ? a : b),
          'count': p.length,
          'days_since_last': 1,
        },
};

const _twoWeighIns = [('2026-09-01', 82.0, 82.0), ('2026-10-31', 79.0, 79.6)];

WeightHistory _history(List<(String, double, double)> p) => WeightHistory.fromJson(_historyJson(p));

void main() {
  group('ShareCardData', () {
    test('weight stays off the card unless the user opts in', () {
      final data = ShareCardData.from(progress: _progress(), weight: _history(_twoWeighIns));
      expect(data.showsWeight, isFalse);
      expect(data.weightChange, isNull);
    });

    test('opted-in weight is a change only, in the chosen unit', () {
      final kg = ShareCardData.from(progress: _progress(), weight: _history(_twoWeighIns), includeWeight: true);
      expect(kg.weightChange, '–2.4 kg');
      expect(kg.weightSince, 'since Sep 1');

      final lb = ShareCardData.from(
        progress: _progress(),
        weight: _history(_twoWeighIns),
        includeWeight: true,
        unit: WeightUnit.lb,
      );
      expect(lb.weightChange, '–5.3 lb');
    });

    test('a single weigh-in has no change to share', () {
      final one = _history([('2026-10-31', 79.0, 79.0)]);
      expect(ShareCardData.canShareWeight(one), isFalse);
      expect(ShareCardData.canShareWeight(null), isFalse);
      expect(ShareCardData.from(progress: _progress(), weight: one, includeWeight: true).showsWeight, isFalse);
    });

    test('badges: unlocked only, newest first, capped', () {
      final data = ShareCardData.from(progress: _progress());
      expect(data.badges.map((b) => b.id), ['on_fire', 'snapshot', 'first_bite']);
      expect(data.badgeCount, 3);
      expect(data.badgeTotal, 4);

      final many = ShareCardData.from(
        progress: _progress(badges: [for (var i = 0; i < 9; i++) _badge('b$i', on: '2026-10-${10 + i}')]),
      );
      expect(many.badges, hasLength(ShareCardData.maxBadges));
      expect(many.badges.first.id, 'b8');
      expect(many.badgeCount, 9);
    });

    test('share text has no calorie or weight numbers', () {
      final withStreak = ShareCardData.from(progress: _progress(), weight: _history(_twoWeighIns), includeWeight: true);
      expect(withStreak.shareText, contains('12-day streak'));
      expect(withStreak.shareText, isNot(contains('kg')));
      expect(withStreak.shareText, isNot(contains('kcal')));

      final none = ShareCardData.from(progress: _progress(streak: 0));
      expect(none.hasStreak, isFalse);
      expect(none.shareText, "I'm level 4 on Calorie Tracker 🔥");
    });
  });

  group('share sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // Apple platforms use the system font, so the card doesn't try to fetch
    // Nunito Sans over the (blocked) test network.
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

    Future<void> pumpSheet(
      WidgetTester tester, {
      required List<(String, double, double)> weighIns,
      bool includeWeight = false,
      required ShareHandler share,
    }) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final service = WeightService(
        client: MockClient((_) async => http.Response(jsonEncode(_historyJson(weighIns)), 200)),
        tokenProvider: () => 'token',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressProvider.overrideWith(
              (ref) => ProgressNotifier(
                fetch: () async => _progress(),
                currentUserId: () => 'user-a',
                userIdChanges: const Stream.empty(),
              ),
            ),
            weightProvider.overrideWith(
              (ref) =>
                  WeightNotifier(service: service, currentUserId: () => 'user-a', userIdChanges: const Stream.empty()),
            ),
          ],
          child: CupertinoApp(
            theme: AppTheme.cupertino,
            home: CupertinoPageScaffold(
              child: SingleChildScrollView(
                child: ShareProgressSheet(initialIncludeWeight: includeWeight, share: share),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('weight toggle is opt-in and shows only the change', (tester) async {
      await pumpSheet(
        tester,
        weighIns: _twoWeighIns,
        share: (_) async => const ShareResult('', ShareResultStatus.success),
      );

      expect(find.byType(ProgressShareCard), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Include weight change'), findsOneWidget);
      expect(find.text('WEIGHT TREND'), findsNothing);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('WEIGHT TREND'), findsOneWidget);
      expect(find.text('–2.4 kg'), findsOneWidget);
      // Absolute weights never appear on the card.
      expect(find.textContaining('79.0'), findsNothing);
      expect(find.textContaining('82.0'), findsNothing);
    }, variant: ios);

    testWidgets('no toggle without two weigh-ins', (tester) async {
      await pumpSheet(
        tester,
        weighIns: [('2026-10-31', 79.0, 79.0)],
        includeWeight: true,
        share: (_) async => const ShareResult('', ShareResultStatus.success),
      );
      expect(find.text('Include weight change'), findsNothing);
      expect(find.text('WEIGHT TREND'), findsNothing);
    }, variant: ios);

    testWidgets('shares a 1080×1920 PNG with the text', (tester) async {
      ShareParams? shared;
      await pumpSheet(
        tester,
        weighIns: _twoWeighIns,
        share: (params) async {
          shared = params;
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Share'));
        for (var i = 0; i < 40 && shared == null; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });

      expect(shared, isNotNull);
      expect(shared!.text, contains('12-day streak'));
      final file = shared!.files!.single;
      expect(file.mimeType, 'image/png');
      final bytes = await tester.runAsync(file.readAsBytes);
      // PNG signature, then the IHDR width and height.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final header = ByteData.sublistView(bytes, 16, 24);
      expect(header.getUint32(0), 1080);
      expect(header.getUint32(4), 1920);
    }, variant: ios);
  });
}
