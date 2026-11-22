import 'package:calorie_app/l10n/app_strings.dart';
import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/screens/profile_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppStrings.active = 'en');

  testWidgets('both "calories burned" lines on the Body card follow the language', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    AppStrings.active = 'de';
    await tester.pumpWidget(CupertinoApp(
      theme: AppTheme.cupertino,
      home: ProfileView(
        profile: UserProfile(
          weightKg: 70,
          heightCm: 175,
          dateOfBirth: DateTime(1995, 5, 5),
          gender: Gender.male,
          activityLevel: ActivityLevel.sedentary,
          goal: Goal.maintain,
        ),
        onOpenSettings: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('calories burned'), findsNothing, reason: 'one of the two lines was left in English');
    expect(find.text('verbrannte Kalorien'), findsNWidgets(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
