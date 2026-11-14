import 'package:calorie_app/models/progress.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/snaps/flame.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: CupertinoApp(theme: AppTheme.cupertino, home: CupertinoPageScaffold(child: Center(child: child))),
    );

void main() {
  test('a shared streak burns hotter the longer it is', () {
    expect(flameTierForDays(1), FlameTier.spark);
    expect(flameTierForDays(3), FlameTier.ember);
    expect(flameTierForDays(7), FlameTier.flame);
    expect(flameTierForDays(14), FlameTier.blaze);
    expect(flameTierForDays(30), FlameTier.inferno);
    expect(flameTierForDays(400), FlameTier.inferno);
  });

  testWidgets('the badge shows the count and says whether the streak is kept today', (tester) async {
    await tester.pumpWidget(_host(const StreakBadge(count: 9, lit: true)));
    expect(find.text('9'), findsOneWidget);
    expect(find.bySemanticsLabel('9 day streak'), findsOneWidget);

    await tester.pumpWidget(_host(const StreakBadge(count: 9, lit: false)));
    expect(find.bySemanticsLabel('9 day streak, not kept yet today'), findsOneWidget);
  });

  testWidgets('a lit flame flickers, an unlit one stays still', (tester) async {
    await tester.pumpWidget(_host(const FlameMark(tier: FlameTier.flame, lit: true)));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_host(const FlameMark(tier: FlameTier.flame, lit: false)));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion keeps even a lit flame still', (tester) async {
    await tester.pumpWidget(_host(const FlameMark(tier: FlameTier.inferno, lit: true), reduceMotion: true));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('higher tiers draw a bigger flame', (tester) async {
    await tester.pumpWidget(_host(const FlameMark(tier: FlameTier.spark, lit: false)));
    final small = tester.getSize(find.byType(FlameMark)).height;
    await tester.pumpWidget(_host(const FlameMark(tier: FlameTier.inferno, lit: false)));
    expect(tester.getSize(find.byType(FlameMark)).height, greaterThan(small));
  });
}
