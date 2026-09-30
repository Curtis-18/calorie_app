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
Widget _appUnderTest({UserProfile? profile}) => ProviderScope(
  child: CupertinoApp(
    localizationsDelegates: appLocalizationsDelegates,
    home: OnboardingScreen(existingProfile: profile),
  ),
);

void main() {
  group('onboarding renders under the app root', () {
    testWidgets('body metrics step is not a grey error box', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // The regression: every TextField here resolves MaterialLocalizations
      // while building, so without the delegate this step threw and Flutter
      // substituted an empty grey box for the whole card.
      expect(tester.takeException(), isNull);
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Body Metrics'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('every step builds, and step 3 needs the height fields', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_appUnderTest(profile: _profile()));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Step 2 validates on the way out, and an existing profile only
      // prepopulates weight, so height has to be typed to move on.
      await tester.enterText(find.byType(TextFormField).at(1), '5');
      await tester.enterText(find.byType(TextFormField).at(2), '9');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
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
