import 'package:calorie_app/main.dart';
import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/screens/onboarding_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile() => UserProfile(
  weightKg: 70,
  heightCm: 175,
  dateOfBirth: DateTime(1995, 5, 5),
  gender: Gender.male,
  activityLevel: ActivityLevel.sedentary,
  goal: Goal.maintain,
);

/// Mirrors `MyApp`: a `CupertinoApp` carrying only the delegates the app
/// itself installs. Adding a delegate here would hide the regression this
/// exists to catch.
Widget _appUnderTest({UserProfile? profile, String? welcomeName}) => ProviderScope(
  child: CupertinoApp(
    localizationsDelegates: appLocalizationsDelegates,
    home: OnboardingScreen(existingProfile: profile, welcomeName: welcomeName),
  ),
);

void main() {
  void bigScreen(WidgetTester tester, {Locale locale = const Locale('en', 'GB')}) {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.localeTestValue = locale; // decides the default units
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  }

  // The welcome scene builds up over a few seconds and then waits for "Let's
  // go", so let it finish, tap the button, and let the form rise into place.
  // (It breathes forever, so it can only be settled once it has gone.)
  Future<void> skipWelcome(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.byKey(const ValueKey('welcome_go')));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  group('onboarding renders under the app root', () {
    testWidgets('body step is not a grey error box', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // The regression: every TextField here resolves MaterialLocalizations
      // while building, so without the delegate this step threw and Flutter
      // substituted an empty grey box for the whole card.
      expect(tester.takeException(), isNull);
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Your body'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('all four steps build with plain-language copy', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text("Let's get to know you"), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4'), findsOneWidget);
      // An existing profile fills in its weight and height.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('How active are you?'), findsOneWidget);
      for (final title in ['Mostly sitting', 'Lightly active', 'Moderately active', 'Very active', 'Athlete level']) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text("What's your goal?"), findsOneWidget);
      for (final title in ['Lose weight', 'Stay the same', 'Gain weight']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Build my plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('no jargon or ALL-CAPS enum names anywhere', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();

      const banned = [
        'SEDENTARY',
        'MAINTAIN',
        'MALE',
        'FEMALE',
        'LOSE',
        'GAIN',
        'VERY ACTIVE',
        'Sedentary',
        'Maintain',
      ];
      for (var step = 0; step < 4; step++) {
        for (final word in banned) {
          expect(find.text(word), findsNothing, reason: '"$word" on step ${step + 1}');
        }
        if (step < 3) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('the welcome greets the new person by their username', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(welcomeName: 'sam_1'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      final letters = find.descendant(of: find.byKey(const ValueKey('welcome_hello')), matching: find.byType(Text));
      final text = tester.widgetList<Text>(letters).map((t) => (t.data ?? '').replaceAll('\u00A0', ' ')).join();
      expect(text, 'Hello, sam_1!');
      expect(find.byKey(const ValueKey('welcome_go')), findsOneWidget);
    });

    testWidgets('the welcome waits for "Let\'s go" and then the form appears', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(welcomeName: 'sam'));
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('Step 1 of 4'), findsNothing, reason: 'still on the welcome, however long it takes');
      await tester.tap(find.byKey(const ValueKey('welcome_go')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });

    testWidgets('the birthday is chosen in the new picker and shown on the field', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest());
      await skipWelcome(tester);

      await tester.tap(find.text('Tap to choose').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('birthday_readout')), findsOneWidget);
      expect(find.text('You need to be 18 or older.'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('birthday_done')));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^[A-Z][a-z]{2} \d{1,2}, \d{4}$')), findsOneWidget, reason: 'the chosen date is on the field');
      expect(find.byKey(const ValueKey('birthday_readout')), findsNothing, reason: 'the sheet closed');
    });

    testWidgets('going forward and back between steps ends on the right card', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choices are required, with a friendly nudge', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest());
      await skipWelcome(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('When were you born?'), findsWidgets);
      expect(find.text('Please choose your date of birth.'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
    });

    testWidgets('weight and height are checked in plain words', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Clear what the profile filled in.
      for (final field in find.byType(TextFormField).evaluate().toList()) {
        await tester.enterText(find.byWidget(field.widget), '');
      }
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a weight between'), findsOneWidget);
      expect(find.textContaining('Enter a height between'), findsOneWidget);
      expect(find.text('Step 2 of 4'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '72,5'); // comma decimals
      await tester.enterText(find.byType(TextFormField).at(1), '172');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 4'), findsOneWidget);
    });

    testWidgets('defaults to pounds and feet in the US, kilograms and cm elsewhere', (tester) async {
      bigScreen(tester, locale: const Locale('en', 'US'));
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // Weight, feet and inches; the profile's 70 kg shows as 154.3 lb.
      final us = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(us, hasLength(3));
      expect(us[0].controller!.text, '154.3');
      expect(us[1].controller!.text, '5');
      expect(us[2].controller!.text, '8.9');
    });

    testWidgets('height unit switch carries the typed value over', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Metric by default here: weight, then one height field in cm.
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).at(1), '175.3');
      await tester.tap(find.text('ft / in'));
      await tester.pumpAndSettle();
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
      expect(fields[1].controller!.text, '5');
      expect(fields[2].controller!.text, '9');
    });

    // Pins the mechanism, so the delegate above cannot be deleted as
    // "redundant": a bare CupertinoApp resolves no MaterialLocalizations, and
    // the step's TextFields null-assert on it while building.
    testWidgets('a bare CupertinoApp cannot render these inputs', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: CupertinoApp(home: OnboardingScreen(existingProfile: _profile())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNotNull);
    });
  });
}
