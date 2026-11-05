import 'dart:convert';

import 'package:calorie_app/providers/notification_prefs_provider.dart';
import 'package:calorie_app/screens/notification_settings_screen.dart';
import 'package:calorie_app/services/notification_prefs_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/dashboard_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('the dashboard header has a bell next to the profile button that opens notifications', (tester) async {
    final client = MockClient((_) async => http.Response(jsonEncode({
          'friend_snaps': true,
          'reactions': true,
          'streak_reminders': true,
          'milestones': true,
          'meal_nudge_hour': null,
          'quiet_start': 22,
          'quiet_end': 8,
          'utc_offset_minutes': 0,
          'paused_until': null,
          'daily_cap': 3,
        }), 200));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationPrefsProvider.overrideWith(
          (ref) => NotificationPrefsNotifier(NotificationPrefsService(client: client, tokenProvider: () => 't')),
        ),
      ],
      child: CupertinoApp(
        theme: AppTheme.cupertino,
        home: const CupertinoPageScaffold(
          child: SafeArea(child: DashboardHeader(streakDays: 3, dateLabel: 'Today')),
        ),
      ),
    ));
    expect(find.byIcon(CupertinoIcons.person_crop_circle), findsOneWidget);
    expect(find.byKey(const ValueKey('header_notifications')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('header_notifications')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });
}
