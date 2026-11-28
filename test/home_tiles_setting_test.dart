import 'package:calorie_app/providers/budget_provider.dart';
import 'package:calorie_app/providers/display_prefs_provider.dart';
import 'package:calorie_app/providers/friends_provider.dart';
import 'package:calorie_app/providers/user_provider.dart';
import 'package:calorie_app/screens/settings_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Settings switch that hides the Bites and Messages tiles on Today
/// (owner's pick, 28 Nov 2026). Today shows the tiles only while it is on.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings has a switch for the Bites and Messages tiles, on by default, and turning it off is kept', (tester) async {
    tester.view.physicalSize = const Size(750, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    final c = ProviderContainer(overrides: [
      userProfileProvider.overrideWith((ref) => UserProfileNotifier(currentUserId: () => null, authToken: () => null, userIdChanges: const Stream.empty())),
      friendsProvider.overrideWith((ref) => FriendsNotifier(currentUserId: () => null, userIdChanges: const Stream.empty())),
      budgetProvider.overrideWith((ref) => BudgetNotifier(currentUserId: () => null, userIdChanges: const Stream.empty())),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: CupertinoApp(theme: AppTheme.cupertino, home: const SettingsScreen()),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final row = find.byKey(const ValueKey('toggle_home_tiles'));
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Bites and messages'), findsOneWidget);
    expect(find.text('Two shortcuts under the calorie ring'), findsOneWidget);
    expect(c.read(displayPrefsProvider).showHomeTiles, isTrue);
    await tester.tap(find.descendant(of: row, matching: find.byType(CupertinoSwitch)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(displayPrefsProvider).showHomeTiles, isFalse);
    expect((await SharedPreferences.getInstance()).getBool(DisplayPrefsNotifier.homeTilesKey), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
