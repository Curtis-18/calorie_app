import 'package:calorie_app/models/user_profile.dart';
import 'package:calorie_app/screens/profile_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/profile_link_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

UserProfile profile() => UserProfile(
      weightKg: 70,
      heightCm: 175,
      dateOfBirth: DateTime(1995, 5, 5),
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
      goal: Goal.maintain,
    );

String? copied;

void mockClipboard(WidgetTester tester) {
  copied = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

void main() {
  group('the profile link on the Profile tab', () {
    testWidgets('shows the link small, with a copy icon, on the identity card', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: ProfileView(profile: profile(), username: 'River_Song', photoButton: const SizedBox(width: 60, height: 60)),
      ));
      expect(find.text('calorie-app-ug.vercel.app/u/River_Song'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.doc_on_doc), findsOneWidget);
      // No Share button and no big Copy button any more.
      expect(find.text('Share'), findsNothing);
      expect(find.text('Copy link'), findsNothing);
    }, variant: ios);

    testWidgets('without a username there is no link', (tester) async {
      await tester.pumpWidget(CupertinoApp(theme: AppTheme.cupertino, home: ProfileView(profile: profile())));
      expect(find.byType(ProfileLinkChip), findsNothing);
    }, variant: ios);

    testWidgets('tapping copies the full link and the icon turns into a tick, then back', (tester) async {
      mockClipboard(tester);
      await tester.pumpWidget(CupertinoApp(theme: AppTheme.cupertino, home: const CupertinoPageScaffold(child: Center(child: ProfileLinkChip(username: 'River_Song')))));
      await tester.tap(find.byKey(const ValueKey('copy_profile_link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(copied, 'https://calorie-app-ug.vercel.app/u/River_Song');
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.doc_on_doc), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byIcon(CupertinoIcons.doc_on_doc), findsOneWidget);
    }, variant: ios);

    testWidgets('a long link shrinks instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: const CupertinoPageScaffold(child: Center(child: SizedBox(width: 120, child: ProfileLinkChip(username: 'a_very_long_username')))),
      ));
      expect(tester.takeException(), isNull);
    }, variant: ios);

    testWidgets('it is announced as a button, and says Copied afterwards', (tester) async {
      final handle = tester.ensureSemantics();
      mockClipboard(tester);
      await tester.pumpWidget(CupertinoApp(theme: AppTheme.cupertino, home: const CupertinoPageScaffold(child: Center(child: ProfileLinkChip(username: 'sam')))));
      expect(find.bySemanticsLabel('Copy link'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('copy_profile_link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      handle.dispose();
    }, variant: ios);
  });
}
