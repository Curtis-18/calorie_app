import 'package:calorie_app/models/workouts.dart';
import 'package:calorie_app/screens/workout_player_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_screen_test.dart' show FakeAwake, Server, card, containerFor, detailFor, ignoreOverflow, settle, step;

WorkoutDetail _walk([int moves = 1]) => WorkoutDetail.fromJson(
      detailFor(card('walk_10', '10-minute walk', 10, 'cardio'), [for (var i = 0; i < moves; i++) step('timed', 'Walk $i', seconds: 60)]),
    )!;

void main() {
  late FakeAwake awake;

  Future<void> open(WidgetTester tester, {int moves = 1}) async {
    ignoreOverflow();
    awake = FakeAwake();
    final c = containerFor(Server(), awake: awake);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: CupertinoApp(
        theme: AppTheme.cupertino,
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(child: CupertinoButton(child: const Text('go'), onPressed: () => openWorkoutPlayer(context, _walk(moves)))),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  testWidgets('the screen is kept awake while a workout is on, and let go when it is left', (tester) async {
    await open(tester);
    expect(awake.calls, ['on']);
    await tester.tap(find.byKey(const ValueKey('player_close'))); // under a minute in: leaves without asking
    await settle(tester, 15);
    expect(find.byKey(const ValueKey('player_close')), findsNothing, reason: 'the player closed');
    expect(awake.calls, ['on', 'off']);
  });

  testWidgets('"Don\'t save" after a few minutes lets it go once', (tester) async {
    await open(tester, moves: 3);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 65));
    await tester.tap(find.byKey(const ValueKey('player_close')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('stop_discard')));
    await settle(tester, 15);
    expect(find.byKey(const ValueKey('player_close')), findsNothing);
    expect(awake.calls, ['on', 'off']);
  });

  testWidgets('it is let go the moment the workout finishes, before the summary is closed', (tester) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 3)); // get ready
    await tester.pump(const Duration(seconds: 60)); // the one move
    await settle(tester, 5);
    expect(awake.calls, ['on', 'off']);
  });

  testWidgets('Save and finish lets it go too, and leaving afterwards does not release twice', (tester) async {
    await open(tester, moves: 3);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 65));
    await tester.tap(find.byKey(const ValueKey('player_close')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('stop_save')));
    await settle(tester, 10);
    expect(awake.calls, ['on', 'off']);
    // Now close the summary.
    expect(find.byKey(const ValueKey('summary_done')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('summary_done')));
    await settle(tester, 15);
    expect(find.byKey(const ValueKey('summary_done')), findsNothing);
    expect(awake.calls, ['on', 'off']);
  });

  testWidgets('keeping going after the stop question keeps it awake', (tester) async {
    await open(tester, moves: 3);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 65));
    await tester.tap(find.byKey(const ValueKey('player_close')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('stop_keep')));
    await settle(tester);
    expect(awake.calls, ['on']);
  });
}
