import 'dart:convert';

import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/models/workouts.dart';
import 'package:calorie_app/providers/house_recipes_provider.dart';
import 'package:calorie_app/providers/workouts_provider.dart';
import 'package:calorie_app/screens/workout_player_screen.dart';
import 'package:calorie_app/screens/workouts_screen.dart';
import 'package:calorie_app/services/workouts_service.dart';
import 'package:calorie_app/services/screen_awake.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> card(String id, String name, int minutes, String slice, {String level = 'easy'}) => {
      'id': id, 'name': name, 'minutes': minutes, 'focus': 'Focus', 'slice': slice,
      'level': level, 'level_label': level == 'easy' ? 'Easy' : 'Steady', 'summary': 'About $name',
    };

Map<String, dynamic> step(String mode, String name, {int? seconds, int? reps, int? side, String section = 'main'}) => {
      'mode': mode, 'name': name, 'cue': 'Cue for $name', 'amount': reps != null ? '$reps reps' : '$seconds seconds',
      'section': section, 'seconds': seconds, 'reps': reps, 'side': side, 'round': null,
    };

Map<String, dynamic> detailFor(Map<String, dynamic> c, List<Map<String, dynamic>> play) => {
      ...c,
      'safety': 'Stop if anything hurts.', 'rounds': 1, 'play': play,
      'sections': [
        {'title': 'Warm-up', 'repeat': null, 'steps': [{'name': 'March', 'amount': '30 seconds', 'cue': ''}]},
      ],
    };

class Server {
  final cards = [
    card('desk_2', '2-minute desk break', 2, 'mobility'),
    card('dance_3', '3-minute dance break', 3, 'fun'),
    card('walk_10', '10-minute walk', 10, 'cardio'),
    card('reset_5', '5-minute reset', 5, 'mobility'),
    card('strength_20', '20-minute strength', 20, 'strength', level: 'steady'),
  ];
  Map<String, dynamic> week = {
    'minutes': 80, 'sessions': 3, 'active_days': 2, 'moved_days': [true, false, true, false, false, false, false],
    'today_index': 2, 'strength_days': 1, 'today_minutes': 20, 'today_sessions': 1, 'goal_minutes': 150,
    'strength_days_goal': 2, 'week_moved': true, 'streak': 3,
    'by_slice': {
      'strength': {'minutes': 20, 'sessions': 1}, 'cardio': {'minutes': 60, 'sessions': 2},
      'mobility': {'minutes': 0, 'sessions': 0}, 'fun': {'minutes': 0, 'sessions': 0},
    },
  };
  List<Map<String, dynamic>> entries = [
    {'id': 'e1', 'date': '2026-11-23', 'activity': 'walk', 'label': 'Walk', 'slice': 'cardio', 'minutes': 40,
     'intensity': 'easy', 'source': 'manual', 'routine_id': null, 'est_kcal': null},
  ];
  List<Map<String, dynamic>> play = [step('timed', 'Jumping on the spot', seconds: 2)];
  int? estKcal = 90;
  int eatBackPercent = 0;
  int eatBackKcal = 0;
  bool failPrefs = false;
  final posts = <Map<String, dynamic>>[];
  final deletes = <String>[];
  bool failLibrary = false;
  bool failPost = false;

  MockClient get client => MockClient((req) async {
        final path = req.url.path;
        http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: _json);
        if (req.method == 'GET' && path == '/workouts') {
          return failLibrary ? http.Response('no', 500) : ok({'routines': cards, 'slices': ['strength', 'cardio', 'mobility', 'fun']});
        }
        if (req.method == 'GET' && path.startsWith('/workouts/')) {
          final id = path.split('/').last;
          return ok(detailFor(cards.firstWhere((c) => c['id'] == id), play));
        }
        if (req.method == 'POST' && path == '/movement/prefs') {
          if (failPrefs) return http.Response('no', 503);
          eatBackPercent = (jsonDecode(req.body) as Map<String, dynamic>)['eat_back_percent'] as int;
          eatBackKcal = eatBackPercent == 0 ? 0 : 30;
          return ok({'eat_back_percent': eatBackPercent});
        }
        if (req.method == 'GET' && path == '/movement/week') return ok({...week, 'eat_back_percent': eatBackPercent, 'eat_back_kcal': eatBackKcal});
        if (req.method == 'GET' && path == '/movement/choices') {
          return ok({'activities': [
            {'key': 'walk', 'label': 'Walk', 'slice': 'cardio'},
            {'key': 'dance', 'label': 'Dance', 'slice': 'fun'},
          ], 'intensities': ['easy', 'moderate', 'hard']});
        }
        if (req.method == 'GET' && path == '/movement') return ok(entries);
        if (req.method == 'POST' && path == '/movement') {
          if (failPost) return http.Response('no', 500);
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          posts.add(body);
          final routine = body['routine_id'] as String?;
          return ok({
            'id': body['id'], 'date': '2026-11-25', 'activity': routine == null ? body['activity'] : 'session_cardio',
            'label': routine == null ? 'Walk' : 'Cardio session', 'slice': 'cardio', 'minutes': body['minutes'],
            'intensity': body['intensity'] ?? 'moderate', 'source': routine == null ? 'manual' : 'session',
            'routine_id': routine, 'est_kcal': estKcal,
          });
        }
        if (req.method == 'DELETE') {
          deletes.add(path.split('/').last);
          entries.removeWhere((e) => e['id'] == path.split('/').last);
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      });
}

class _FakeRecipes extends HouseRecipesNotifier {
  _FakeRecipes(List<HouseRecipe> recipes) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    state = HouseRecipesState(recipes: recipes, loading: false);
  }
}

HouseRecipe own(String id, String title, int kcal, double protein) => HouseRecipe(
      id: id, title: title, servings: 1, calories: kcal, proteinG: protein, carbsG: 20, fatG: 10, estimated: false,
    );

/// Records when the screen was asked to stay awake and when it was let go.
class FakeAwake implements ScreenAwake {
  final calls = <String>[];
  @override
  Future<void> keepOn() async => calls.add('on');
  @override
  Future<void> release() async => calls.add('off');
}

ProviderContainer containerFor(Server s, {List<HouseRecipe> recipes = const [], ScreenAwake? awake}) {
  final service = WorkoutsService(client: s.client, tokenProvider: () => 't', now: () => DateTime(2026, 11, 25, 9));
  final c = ProviderContainer(overrides: [
    workoutsServiceProvider.overrideWithValue(service),
    screenAwakeProvider.overrideWithValue(awake ?? FakeAwake()),
    houseRecipesProvider.overrideWith((ref) => _FakeRecipes(recipes)),
    moveProvider.overrideWith((ref) => MoveNotifier(service: service, currentUserId: () => 'ann', userIdChanges: const Stream.empty())),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The test font is wider than the real one; layout overflow is not what these tests are about.
void ignoreOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Widget app(ProviderContainer c, Widget home) => UncontrolledProviderScope(
      container: c,
      child: CupertinoApp(theme: AppTheme.cupertino, home: home),
    );

void main() {
  tearDown(() => AppStrings.active = 'en');

  group('the Workouts home', () {
    testWidgets('shows the week, the four slices, bites and the library', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);

      expect(find.byKey(const ValueKey('week_minutes')), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('80 of 150 min'), findsOneWidget);
      expect(find.text('1 of 2 strength days'), findsOneWidget);
      expect(find.text('3 moved weeks'), findsOneWidget);
      for (final slice in ['strength', 'cardio', 'mobility', 'fun']) {
        expect(find.byKey(ValueKey('slice_$slice')), findsWidgets);
      }
      // Something nothing was done in yet is offered as a friendly idea.
      expect(find.byKey(const ValueKey('week_nudge')), findsOneWidget);
      // Bites are the short ones only.
      expect(find.byKey(const ValueKey('bite_desk_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('bite_walk_10')), findsNothing);
      // The whole library, shortest first.
      expect(find.byKey(const ValueKey('workout_strength_20')), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget); // the recent entry
    });

    testWidgets('a length chip hides the longer ones and the shorter ones stay', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(containerFor(Server()), const WorkoutsScreen()));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('length_5')));
      await tester.pump();
      expect(find.byKey(const ValueKey('workout_strength_20')), findsNothing);
      expect(find.byKey(const ValueKey('workout_walk_10')), findsNothing);
      expect(find.byKey(const ValueKey('workout_desk_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('workout_reset_5')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('length_0')));
      await tester.pump();
      expect(find.byKey(const ValueKey('workout_strength_20')), findsOneWidget);
    });

    testWidgets('a kind chip filters, and nothing matching says so kindly', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(containerFor(Server()), const WorkoutsScreen()));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('slice_strength')).last);
      await tester.pump();
      expect(find.byKey(const ValueKey('workout_walk_10')), findsNothing);
      expect(find.byKey(const ValueKey('workout_strength_20')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('length_5')));
      await tester.pump();
      expect(find.byKey(const ValueKey('library_none')), findsOneWidget);
    });

    testWidgets('a feeling shows a few ideas, and tapping it again hides them', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(containerFor(Server()), const WorkoutsScreen()));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('feeling_tired')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pick_reset_5')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick_strength_20')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('feeling_tired')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pick_reset_5')), findsNothing);
    });

    testWidgets('an empty week is quiet: no streak, no nudge', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server()
        ..entries = []
        ..week = {...Server().week, 'minutes': 0, 'streak': 0, 'sessions': 0, 'moved_days': List.filled(7, false), 'by_slice': {}};
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      expect(find.text('0 of 150 min'), findsOneWidget);
      expect(find.byKey(const ValueKey('week_streak')), findsNothing);
      expect(find.byKey(const ValueKey('week_nudge')), findsNothing);
      expect(find.byKey(const ValueKey('entry_e1')), findsNothing);
    });

    testWidgets('a library that will not load shows a retry, not a blank page', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server()..failLibrary = true;
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      expect(find.byKey(const ValueKey('library_error')), findsOneWidget);
      s.failLibrary = false;
      await tester.tap(find.byKey(const ValueKey('library_retry')));
      await settle(tester);
      expect(find.byKey(const ValueKey('workout_strength_20')), findsOneWidget);
    });

    testWidgets('removing something you logged asks first and then deletes it', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('entry_e1')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('entry_remove')));
      await settle(tester);
      expect(s.deletes, ['e1']);
      expect(find.byKey(const ValueKey('entry_e1')), findsNothing);
    });

    testWidgets('words come out in the chosen language', (tester) async {
      ignoreOverflow();
      AppStrings.active = 'es';
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(containerFor(Server()), const WorkoutsScreen()));
      await settle(tester);
      expect(find.text('80 de 150 min'), findsOneWidget);
      expect(find.text('Bocados de movimiento'), findsOneWidget);
    });
  });

  group('adding movement to the calorie plan', () {
    testWidgets('it is off by default, says so plainly, and choosing a share saves it', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      expect(find.byKey(const ValueKey('plan_choice')), findsOneWidget);
      expect(find.textContaining('Off by default'), findsOneWidget);
      expect(find.text('Your daily calories stay exactly the same, whatever you do.'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_added')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('eat_back_25')));
      await settle(tester);
      expect(s.eatBackPercent, 25);
      // The card shows what choosing it would mean, in a worked example.
      expect(find.textContaining('a 30-minute walk is roughly 90 kcal, so about 25 kcal'), findsOneWidget);
      expect(find.textContaining('Never more than 500 kcal a day'), findsOneWidget);
      expect(find.text('+30 kcal added to today’s plan'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('eat_back_50')));
      await settle(tester);
      expect(find.textContaining('so about 45 kcal'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('eat_back_0')));
      await settle(tester);
      expect(s.eatBackPercent, 0);
      expect(find.byKey(const ValueKey('plan_added')), findsNothing);
      expect(find.text('Your daily calories stay exactly the same, whatever you do.'), findsOneWidget);
    });

    test('the example rounds to the nearest 5, half up, like the server', () {
      expect(exampleAddedKcal(0), 0);
      expect(exampleAddedKcal(25), 25); // 22.5 rounds up
      expect(exampleAddedKcal(50), 45);
    });

    testWidgets('a choice that cannot be saved says so', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server()..failPrefs = true;
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('eat_back_50')));
      await settle(tester);
      expect(find.byKey(const ValueKey('plan_failed')), findsOneWidget);
    });

    testWidgets('the finish summary says whether the estimate is added, following the choice', (tester) async {
      ignoreOverflow();
      final s = Server()
        ..eatBackPercent = 25
        ..eatBackKcal = 30;
      final c = containerFor(s);
      c.read(moveProvider.notifier); // loads the week with the choice on
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(app(c, WorkoutPlayerScreen(workout: WorkoutDetail.fromJson(detailFor(card('walk_10', '10-minute walk', 10, 'cardio'), [step('timed', 'Walk', seconds: 60)]))!)));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(find.text('Part of this is added to today’s plan, as you chose.'), findsOneWidget);
      expect(find.text("This isn't added to your daily calories."), findsNothing);
    });

    test('the week reads the choice and the extra, and an older server means off', () {
      final w = MoveWeek.fromJson({'eat_back_percent': 25, 'eat_back_kcal': 120});
      expect((w.eatBackPercent, w.eatBackKcal), (25, 120));
      final old = MoveWeek.fromJson({'minutes': 10});
      expect((old.eatBackPercent, old.eatBackKcal), (0, 0));
      // Never trust a number outside what the server allows.
      final odd = MoveWeek.fromJson({'eat_back_percent': 90, 'eat_back_kcal': 9000});
      expect((odd.eatBackPercent, odd.eatBackKcal), (50, 500));
    });
  });

  group('opening a workout and logging by hand', () {
    testWidgets('a tile opens the sheet with its steps and the safety line', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(containerFor(Server()), const WorkoutsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('workout_walk_10')));
      await settle(tester);
      expect(find.byKey(const ValueKey('detail_name')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail_safety')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail_start')), findsOneWidget);
    });

    testWidgets('logging a walk by hand sends the activity, minutes and how it felt', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('log_other')));
      await settle(tester);

      // Can't save until something is picked.
      await tester.tap(find.byKey(const ValueKey('log_save')));
      await settle(tester, 3);
      expect(s.posts, isEmpty);

      await tester.tap(find.byKey(const ValueKey('activity_walk')));
      await tester.tap(find.byKey(const ValueKey('minutes_45')));
      await tester.tap(find.byKey(const ValueKey('intensity_easy')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('log_save')));
      await settle(tester);

      expect(s.posts, hasLength(1));
      expect(s.posts.single['activity'], 'walk');
      expect(s.posts.single['minutes'], 45);
      expect(s.posts.single['intensity'], 'easy');
      expect(s.posts.single['date'], '2026-11-25');
      expect(s.posts.single.containsKey('routine_id'), isFalse);
      expect((s.posts.single['id'] as String).length, 36);
    });

    testWidgets('a failed save keeps the sheet open and says so', (tester) async {
      ignoreOverflow();
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Server()..failPost = true;
      await tester.pumpWidget(app(containerFor(s), const WorkoutsScreen()));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('log_other')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('activity_dance')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('log_save')));
      await settle(tester);
      expect(find.byKey(const ValueKey('log_failed')), findsOneWidget);
    });
  });

  group('the player', () {
    WorkoutDetail detail(List<Map<String, dynamic>> play) =>
        WorkoutDetail.fromJson(detailFor(card('walk_10', '10-minute walk', 10, 'cardio'), play))!;

    testWidgets('counts 3, 2, 1, then shows the first move, its cue and what is next', (tester) async {
      ignoreOverflow();
      final c = containerFor(Server());
      await tester.pumpWidget(app(c, WorkoutPlayerScreen(workout: detail([
        step('timed', 'March', seconds: 30), step('reps', 'Squat', reps: 10),
      ]))));
      expect(find.byKey(const ValueKey('player_get_ready')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('player_name')), findsOneWidget);
      expect(find.text('March'), findsOneWidget);
      expect(find.text('Cue for March'), findsOneWidget);
      expect(find.text('Next: Squat'), findsOneWidget);
      expect(find.byKey(const ValueKey('player_time')), findsOneWidget);
    });

    testWidgets('a move done on each side says which side', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(app(containerFor(Server()), WorkoutPlayerScreen(workout: detail([
        step('timed', 'Hamstring stretch', seconds: 20, side: 1), step('timed', 'Hamstring stretch', seconds: 20, side: 2),
      ]))));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('First side'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Other side'), findsOneWidget);
    });

    testWidgets('"Easier version" swaps a move, and "Usual version" swaps it back', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(app(containerFor(Server()), WorkoutPlayerScreen(workout: detail([
        {...step('reps', 'Knee push-up', reps: 10), 'easier': {'mode': 'reps', 'name': 'Wall push-up', 'cue': 'Hands on a wall', 'amount': '10 reps', 'reps': 10}},
        step('reps', 'Squat', reps: 8),
      ]))));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Knee push-up'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_easier')));
      await tester.pump();
      expect(find.text('Wall push-up'), findsOneWidget);
      expect(find.text('Hands on a wall'), findsOneWidget);
      expect(find.text('Usual version'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_easier')));
      await tester.pump();
      expect(find.text('Knee push-up'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_done')));
      await tester.pump();
      expect(find.text('Squat'), findsOneWidget);
      expect(find.byKey(const ValueKey('player_easier')), findsNothing, reason: 'no easier version: no button');
    });

    testWidgets('minus and plus set the reps done, "Last time" shows, and the sets are saved with the session', (tester) async {
      ignoreOverflow();
      final s = Server();
      final workout = WorkoutDetail.fromJson({
        ...detailFor(card('strength_20', '20-minute strength', 20, 'strength'), [
          {...step('reps', 'Bodyweight squat', reps: 10), 'move': 'squat'},
          {...step('reps', 'Glute bridge', reps: 12), 'move': 'glute_bridge'},
          step('timed', 'Hamstring stretch', seconds: 60, section: 'cool'),
        ]),
        'last_reps': {'squat': 11},
      })!;
      await tester.pumpWidget(app(containerFor(s), WorkoutPlayerScreen(workout: workout)));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Last time: 11'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_reps_plus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('player_reps_plus')));
      await tester.pump();
      expect(find.text('12'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_done')));
      await tester.pump();
      expect(find.byKey(const ValueKey('player_last')), findsNothing, reason: 'no history for the glute bridge');
      await tester.tap(find.byKey(const ValueKey('player_reps_minus')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('player_done')));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(s.posts, hasLength(1));
      expect(s.posts.single['sets'], [
        {'move': 'squat', 'reps': 12},
        {'move': 'glute_bridge', 'reps': 11},
      ]);
    });

    testWidgets('with an older server (no move ids) nothing extra is sent and no "Last time" shows', (tester) async {
      ignoreOverflow();
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), WorkoutPlayerScreen(workout: detail([
        step('reps', 'Squat', reps: 10), step('timed', 'Walk', seconds: 60),
      ]))));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('player_last')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('player_done')));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(s.posts.single.containsKey('sets'), isFalse);
    });

    testWidgets('a rest counts down, can be made longer and skipped', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(app(containerFor(Server()), WorkoutPlayerScreen(workout: detail([
        step('rest', 'Rest', seconds: 20), step('timed', 'Plank', seconds: 25),
      ]))));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Up next: Plank'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_more_rest')));
      await tester.pump();
      expect(find.text('40'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_skip')));
      await tester.pump();
      expect(find.text('Plank'), findsOneWidget);
    });

    testWidgets('pausing stops the clock', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(app(containerFor(Server()), WorkoutPlayerScreen(workout: detail([step('timed', 'March', seconds: 30)]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('25'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player_pause')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('25'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
    });

    testWidgets('finishing saves the minutes done, shows the estimate as an estimate, and says it is not added to calories', (tester) async {
      ignoreOverflow();
      final s = Server()..estKcal = 90;
      await tester.pumpWidget(app(containerFor(s), WorkoutPlayerScreen(workout: detail([
        step('timed', 'Walk', seconds: 90),
      ]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 90));
      await settle(tester, 5);
      expect(find.byKey(const ValueKey('summary_title')), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget); // 90 s rounds to 2
      expect(s.posts, hasLength(1));
      expect(s.posts.single['routine_id'], 'walk_10');
      expect(s.posts.single['minutes'], 2);
      expect(find.byKey(const ValueKey('summary_saved')), findsOneWidget);
      expect(find.text('About 90 kcal (a rough estimate)'), findsOneWidget);
      expect(find.byKey(const ValueKey('summary_kcal_note')), findsOneWidget);
    });

    testWidgets('no estimate is shown when the server has none, and nothing talks about burning or earning', (tester) async {
      ignoreOverflow();
      final s = Server()..estKcal = null;
      await tester.pumpWidget(app(containerFor(s), WorkoutPlayerScreen(workout: detail([step('timed', 'Walk', seconds: 60)]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(find.byKey(const ValueKey('summary_kcal')), findsNothing);
      final words = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ').toLowerCase();
      for (final banned in ['burn', 'earn', 'cheat', 'punish', 'make up for']) {
        expect(words.contains(banned), isFalse, reason: banned);
      }
    });

    testWidgets('the summary offers the highest-protein own recipes as ideas for the next meal, not sized to the workout', (tester) async {
      ignoreOverflow();
      final c = containerFor(Server(), recipes: [own('a', 'Chicken bowl', 520, 42), own('b', 'Toast', 150, 4), own('c', 'Tuna salad', 300, 31)]);
      await tester.pumpWidget(app(c, WorkoutPlayerScreen(workout: detail([step('timed', 'Walk', seconds: 60)]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(find.text('Ideas for your next meal'), findsOneWidget);
      expect(find.byKey(const ValueKey('refuel_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('refuel_c')), findsOneWidget);
      expect(find.byKey(const ValueKey('refuel_b')), findsNothing);
      expect(find.text('42 g protein'), findsOneWidget);
    });

    testWidgets('no recipes, no ideas section', (tester) async {
      ignoreOverflow();
      await tester.pumpWidget(app(containerFor(Server()), WorkoutPlayerScreen(workout: detail([step('timed', 'Walk', seconds: 60)]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(find.text('Ideas for your next meal'), findsNothing);
    });

    testWidgets('if saving fails, the summary offers to try again and a retry saves it once', (tester) async {
      ignoreOverflow();
      final s = Server()..failPost = true;
      await tester.pumpWidget(app(containerFor(s), WorkoutPlayerScreen(workout: detail([step('timed', 'Walk', seconds: 60)]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 60));
      await settle(tester, 5);
      expect(find.byKey(const ValueKey('summary_retry')), findsOneWidget);
      s.failPost = false;
      await tester.tap(find.byKey(const ValueKey('summary_retry')));
      await settle(tester, 5);
      expect(find.byKey(const ValueKey('summary_saved')), findsOneWidget);
      expect(s.posts, hasLength(1));
    });

    testWidgets('closing early offers to save what was done, keep going, or discard', (tester) async {
      ignoreOverflow();
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), WorkoutPlayerScreen(workout: detail([
        step('reps', 'Squat', reps: 10), step('timed', 'Plank', seconds: 25),
      ]))));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 70)); // squats take a while: still on the rep move
      await tester.tap(find.byKey(const ValueKey('player_close')));
      await settle(tester, 6);
      expect(find.byKey(const ValueKey('stop_save')), findsOneWidget);
      // Paused while deciding.
      await tester.tap(find.byKey(const ValueKey('stop_keep')));
      await settle(tester, 6);
      expect(find.byKey(const ValueKey('player_reps')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('player_close')));
      await settle(tester, 6);
      await tester.tap(find.byKey(const ValueKey('stop_save')));
      await settle(tester, 6);
      expect(s.posts.single['minutes'], 1);
      expect(find.byKey(const ValueKey('summary_title')), findsOneWidget);
    });

    testWidgets('closing before doing anything just closes', (tester) async {
      ignoreOverflow();
      final s = Server();
      await tester.pumpWidget(app(containerFor(s), Builder(
        builder: (context) => CupertinoButton(
          child: const Text('open'),
          onPressed: () => openWorkoutPlayer(context, detail([step('timed', 'March', seconds: 30)])),
        ),
      )));
      await tester.tap(find.text('open'));
      await settle(tester, 6);
      await tester.tap(find.byKey(const ValueKey('player_close')));
      await settle(tester, 15);
      expect(find.byKey(const ValueKey('player_close')), findsNothing);
      expect(s.posts, isEmpty);
    });
  });

  test('a new movement id is a well-formed unique v4 id', () {
    final a = newMovementId();
    final b = newMovementId();
    expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(a, isNot(b));
  });

  test('readers skip lines they cannot understand', () {
    expect(WorkoutLibrary.fromJson({'routines': [card('a', 'A', 3, 'fun'), {'id': 'x'}, 'junk', card('b', 'B', 0, 'fun')]}).routines.map((c) => c.id), ['a']);
    expect(WorkoutDetail.fromJson({'id': 'a', 'slice': 'fun', 'minutes': 3, 'play': []}), isNull);
    expect(PlayStep.fromJson({'mode': 'timed', 'seconds': 0}), isNull);
    expect(PlayStep.fromJson({'mode': 'reps', 'reps': 8, 'name': 'x', 'amount': '8 reps'})?.reps, 8);
    expect(PlayStep.fromJson({'mode': 'reps', 'reps': 8, 'name': 'x', 'amount': '8 reps'})?.easier, isNull, reason: 'an older backend');
  });

  test('steps read their move id, and a workout reads last time\'s reps tolerantly', () {
    final s = PlayStep.fromJson({...step('reps', 'Knee push-up', reps: 10), 'move': 'knee_pushup',
      'easier': {'mode': 'reps', 'name': 'Wall push-up', 'reps': 10, 'move': 'wall_pushup'}})!;
    expect((s.move, s.easier!.move), ('knee_pushup', 'wall_pushup'), reason: 'the copy with its easier version keeps the move');
    expect(PlayStep.fromJson(step('reps', 'Squat', reps: 8))!.move, isNull, reason: 'an older server');
    final d = WorkoutDetail.fromJson({
      ...detailFor(card('strength_20', '20-minute strength', 20, 'strength'), [step('reps', 'Squat', reps: 8)]),
      'last_reps': {'squat': 12, 'odd': 'x', 'zero': 0, 'huge': 9999, 'plank': 30.0},
    })!;
    expect(d.lastReps, {'squat': 12, 'plank': 30});
    expect(WorkoutDetail.fromJson(detailFor(card('a', 'A', 3, 'fun'), [step('timed', 'x', seconds: 5)]))!.lastReps, isEmpty);
  });

  test('a step reads its easier version, which takes the step\'s place in the routine', () {
    final s = PlayStep.fromJson({
      ...step('reps', 'Knee push-up', reps: 10, side: null), 'round': 2,
      'easier': {'mode': 'reps', 'name': 'Wall push-up', 'cue': 'Hands on a wall', 'amount': '10 reps', 'reps': 10, 'seconds': null,
        'easier': {'mode': 'reps', 'name': 'Nested', 'reps': 1}},
    })!;
    expect((s.easier!.name, s.easier!.reps, s.easier!.section, s.easier!.round), ('Wall push-up', 10, 'main', 2));
    expect(s.easier!.easier, isNull, reason: 'an easier version has no easier version of its own');
    final side = PlayStep.fromJson({...step('timed', 'Hip stretch', seconds: 30, side: 2), 'easier': {'mode': 'timed', 'name': 'Hip stretch', 'seconds': 15}})!;
    expect((side.easier!.side, side.easier!.seconds), (2, 15));
    expect(PlayStep.fromJson({...step('reps', 'Squat', reps: 8), 'easier': {'mode': 'rest', 'seconds': 20}})!.easier, isNull);
    expect(PlayStep.fromJson({...step('reps', 'Squat', reps: 8), 'easier': {'mode': 'reps', 'reps': 0}})!.easier, isNull);
    expect(PlayStep.fromJson({...step('reps', 'Squat', reps: 8), 'easier': 'junk'})!.easier, isNull);
    expect(PlayStep.fromJson({...step('rest', 'Rest', seconds: 20), 'easier': {'mode': 'timed', 'name': 'x', 'seconds': 5}})!.easier, isNull);
    expect(MoveWeek.fromJson({'moved_days': [true]}).movedDays, List.filled(7, false));
    expect(MoveWeek.fromJson({'minutes': 200}).progress, 1);
  });
}
