import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/welcome_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Future<void> _show(WidgetTester tester, {String? name, VoidCallback? onFinished, bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CupertinoApp(
    theme: AppTheme.cupertino,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: CupertinoPageScaffold(
      child: WelcomeOverlay(name: name, onFinished: onFinished ?? () {}),
    ),
  ));
}

/// The scene breathes forever, so it is stepped, never settled.
Future<void> _play(WidgetTester tester, Duration total) async {
  var left = total;
  while (left > Duration.zero) {
    final step = left > const Duration(milliseconds: 100) ? const Duration(milliseconds: 100) : left;
    await tester.pump(step);
    left -= step;
  }
}

/// The text of a row of animated letters, from the letters themselves.
String _letters(WidgetTester tester, String key) {
  final row = find.byKey(ValueKey(key));
  final texts = find.descendant(of: row, matching: find.byType(Text));
  return tester.widgetList<Text>(texts).map((t) => (t.data ?? '').replaceAll(' ', ' ')).join();
}

double _opacityOfLast(WidgetTester tester, String key) {
  final row = find.byKey(ValueKey(key));
  final last = find.descendant(of: row, matching: find.byType(Opacity)).last;
  return tester.widget<Opacity>(last).opacity;
}

void main() {
  group('the welcome scene', () {
    testWidgets('greets the person by name', (tester) async {
      await _show(tester, name: 'sam_1');
      await _play(tester, const Duration(milliseconds: 6600));
      expect(_letters(tester, 'welcome_hello'), 'Hello, sam_1!');
      expect(_letters(tester, 'welcome_to'), 'Welcome to NuStreak');
      expect(find.text("Let's build your plan in a minute."), findsOneWidget);
    }, variant: ios);

    testWidgets('without a name it stays friendly', (tester) async {
      await _show(tester);
      await _play(tester, const Duration(milliseconds: 6600));
      expect(_letters(tester, 'welcome_hello'), 'Hello, you!');
    }, variant: ios);

    testWidgets('a blank name counts as no name', (tester) async {
      await _show(tester, name: '   ');
      await _play(tester, const Duration(milliseconds: 6600));
      expect(_letters(tester, 'welcome_hello'), 'Hello, you!');
    }, variant: ios);

    testWidgets('a name with accents or emoji is shown whole', (tester) async {
      await _show(tester, name: 'José🔥');
      await _play(tester, const Duration(milliseconds: 6600));
      expect(_letters(tester, 'welcome_hello'), 'Hello, José🔥!');
    }, variant: ios);

    testWidgets('the lines build up one after another, and the button comes last', (tester) async {
      await _show(tester, name: 'sam');
      await _play(tester, const Duration(milliseconds: 300));
      expect(_opacityOfLast(tester, 'welcome_hello'), 0, reason: 'the greeting has not started');
      expect(find.byKey(const ValueKey('welcome_go')), findsOneWidget);
      expect(tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('welcome_go')), matching: find.byType(Opacity)).first).opacity, 0);

      await _play(tester, const Duration(milliseconds: 2900)); // about 3.2 s
      expect(_opacityOfLast(tester, 'welcome_hello'), 1, reason: 'the greeting is complete');
      expect(_opacityOfLast(tester, 'welcome_to'), lessThan(1), reason: 'the welcome line is still coming');

      await _play(tester, const Duration(milliseconds: 3700));
      expect(_opacityOfLast(tester, 'welcome_to'), 1);
      expect(tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('welcome_go')), matching: find.byType(Opacity)).first).opacity, 1);
    }, variant: ios);

    testWidgets('nothing moves on by itself: only the button finishes it', (tester) async {
      var finished = 0;
      await _show(tester, name: 'sam', onFinished: () => finished++);
      await _play(tester, const Duration(seconds: 20));
      expect(finished, 0);
      await tester.tap(find.byKey(const ValueKey('welcome_go')));
      await tester.pump();
      expect(finished, 1);
    }, variant: ios);

    testWidgets("the button cannot be tapped before it has appeared", (tester) async {
      var finished = 0;
      await _show(tester, name: 'sam', onFinished: () => finished++);
      await _play(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('welcome_go')), warnIfMissed: false);
      await tester.pump();
      expect(finished, 0);
    }, variant: ios);

    testWidgets('tapping the scene jumps to the end', (tester) async {
      await _show(tester, name: 'sam');
      await _play(tester, const Duration(milliseconds: 800));
      await tester.tapAt(const Offset(200, 300));
      await _play(tester, const Duration(milliseconds: 900));
      expect(_opacityOfLast(tester, 'welcome_to'), 1);
      expect(tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('welcome_go')), matching: find.byType(Opacity)).first).opacity, 1);
    }, variant: ios);

    testWidgets('with reduce motion on, the finished scene is there at once', (tester) async {
      var finished = 0;
      await _show(tester, name: 'sam', reduceMotion: true, onFinished: () => finished++);
      await tester.pump();
      expect(_opacityOfLast(tester, 'welcome_to'), 1);
      await tester.tap(find.byKey(const ValueKey('welcome_go')));
      await tester.pump();
      expect(finished, 1);
    }, variant: ios);

    testWidgets('it can be removed in the middle of the build-up without errors', (tester) async {
      await _show(tester, name: 'sam');
      await _play(tester, const Duration(milliseconds: 1500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }, variant: ios);
  });
}
