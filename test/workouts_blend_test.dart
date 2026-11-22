import 'package:calorie_app/models/house_recipe.dart';
import 'package:calorie_app/providers/workouts_provider.dart';
import 'package:calorie_app/screens/main_shell.dart';
import 'package:calorie_app/services/refuel_picks.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/moved_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HouseRecipe recipe(String id, String title, int kcal, double protein, {bool mine = true}) => HouseRecipe(
      id: id, title: title, servings: 1, calories: kcal, proteinG: protein, carbsG: 20, fatG: 10, estimated: false, mine: mine,
    );

void main() {
  group('next-meal ideas after a session', () {
    test('the highest-protein own recipes come first, three at most', () {
      final ideas = refuelIdeas([
        recipe('a', 'Oats', 300, 12),
        recipe('b', 'Chicken bowl', 520, 42),
        recipe('c', 'Lentil stew', 410, 28),
        recipe('d', 'Egg wrap', 350, 24),
        recipe('e', 'Tuna salad', 300, 31),
      ]);
      expect(ideas.map((r) => r.id), ['b', 'e', 'c']);
    });

    test('recipes under the protein bar, with no calories, or from friends are never offered', () {
      expect(refuelIdeas([recipe('a', 'Toast', 150, 4), recipe('b', 'Water', 0, 40), recipe('c', 'Friend dish', 400, 40, mine: false)]), isEmpty);
    });

    test('ties are alphabetical so the order does not jump around', () {
      expect(refuelIdeas([recipe('b', 'Beans', 300, 20), recipe('a', 'apples and cheese', 300, 20)]).map((r) => r.id), ['a', 'b']);
    });

    test('no recipes, no ideas', () {
      expect(refuelIdeas(const []), isEmpty);
    });
  });

  group('Moved today on Today', () {
    testWidgets('shows the minutes and opens the Workouts tab when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CupertinoPageScaffold(child: Center(child: MovedRow(minutes: 25, onTap: () => taps++))),
      ));
      expect(find.text('Moved today'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('moved_row')));
      expect(taps, 1);
    });

    test('the providers can be created without a signed-in person and start empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(moveProvider).loaded, isFalse);
      expect(container.read(moveProvider).week.todayMinutes, 0);
      expect(MainShell.workoutsTabKey, isA<GlobalKey>());
    });
  });
}
