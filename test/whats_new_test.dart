import 'package:calorie_app/l10n/app_strings.dart';
import 'dart:async';

import 'package:calorie_app/models/whats_new.dart';
import 'package:calorie_app/providers/notification_prefs_provider.dart';
import 'package:calorie_app/providers/whats_new_provider.dart';
import 'package:calorie_app/screens/notifications_screen.dart';
import 'package:calorie_app/screens/profile_screen.dart';
import 'package:calorie_app/services/notification_prefs_service.dart';
import 'package:calorie_app/services/whats_new_service.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/dashboard_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void existingUser([Map<String, Object> extra = const {}]) =>
    SharedPreferences.setMockInitialValues({'tour_seen_dashboard': true, ...extra});

void main() {
  group('the release list', () {
    test('has a stable id, and every item says something', () {
      expect(whatsNewReleases, isNotEmpty);
      expect(whatsNewReleases.map((r) => r.id).toSet().length, whatsNewReleases.length);
      for (final r in whatsNewReleases) {
        expect(r.id, isNotEmpty);
        expect(r.items, isNotEmpty);
        for (final i in r.items) {
          expect(i.title.trim(), isNotEmpty);
          expect(i.body.trim().length, greaterThan(20));
        }
      }
    });

    test('every release reads in every language the app offers', () {
      for (final entry in translationTables.entries) {
        for (final r in whatsNewReleases) {
          for (final text in [r.title, for (final i in r.items) ...[i.title, i.body]]) {
            expect(entry.value.containsKey(text), isTrue, reason: '${entry.key}: $text');
          }
        }
      }
    });

    test('is written kindly: no shaming words', () {
      const banned = ['cheat', 'guilt', 'burn off', 'punish', 'fail', 'ruin', 'earn it'];
      for (final r in whatsNewReleases) {
        for (final i in r.items) {
          final text = '${i.title} ${i.body}'.toLowerCase();
          expect(banned.where(text.contains), isEmpty, reason: text);
        }
      }
    });
  });

  group('service', () {
    test('someone who has used the app has an unread release until they open it', () async {
      existingUser();
      expect(await WhatsNewService.hasUnread('ann'), isTrue);
      await WhatsNewService.markSeen('ann');
      expect(await WhatsNewService.hasUnread('ann'), isFalse);
    });

    test('it is kept per person on a shared phone', () async {
      existingUser();
      await WhatsNewService.markSeen('ann');
      expect(await WhatsNewService.hasUnread('ann'), isFalse);
      expect(await WhatsNewService.hasUnread('bob'), isTrue);
    });

    test('a newer release is unread again', () async {
      existingUser();
      await WhatsNewService.markSeen('ann', latestId: 'older');
      expect(await WhatsNewService.hasUnread('ann'), isTrue);
    });

    test('a brand new person (tutorial not seen yet) has nothing new, and stays that way', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WhatsNewService.hasUnread('new'), isFalse);
      // Even after they finish the tutorial, today's release is not "new" to them.
      SharedPreferences.setMockInitialValues({
        'tour_seen_dashboard': true,
        'whats_new_seen:new': latestWhatsNew.id,
      });
      expect(await WhatsNewService.hasUnread('new'), isFalse);
    });
  });

  group('provider', () {
    late StreamController<String?> auth;
    setUp(() => auth = StreamController<String?>.broadcast());
    tearDown(() => auth.close());
    Future<void> wait() => Future<void>.delayed(const Duration(milliseconds: 40));

    test('unread for the signed-in person, cleared by opening, and not carried to the next person', () async {
      existingUser();
      final n = WhatsNewNotifier(currentUserId: () => 'ann', userIdChanges: auth.stream);
      addTearDown(n.dispose);
      await wait();
      expect(n.state, isTrue);
      await n.markSeen();
      expect(n.state, isFalse);

      auth.add('bob');
      await wait();
      expect(n.state, isTrue); // Ann opening it didn't clear it for Bob
      auth.add(null);
      await wait();
      expect(n.state, isFalse);
    });

    test('signed out: no dot', () async {
      existingUser();
      final n = WhatsNewNotifier(currentUserId: () => null, userIdChanges: const Stream.empty());
      addTearDown(n.dispose);
      await wait();
      expect(n.state, isFalse);
    });
  });

  group('screens', () {
    Future<ProviderContainer> pump(WidgetTester tester, Widget home, {required bool unread}) async {
      tester.view.physicalSize = const Size(750, 2600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      existingUser(unread ? {} : {'whats_new_seen:ann': latestWhatsNew.id});
      final container = ProviderContainer(overrides: [
        whatsNewProvider.overrideWith((ref) => WhatsNewNotifier(currentUserId: () => 'ann', userIdChanges: const Stream.empty())),
        notificationPrefsProvider.overrideWith(
          (ref) => NotificationPrefsNotifier(NotificationPrefsService(client: MockClient((_) async => http.Response('{}', 200)), tokenProvider: () => 't')),
        ),
      ]);
      addTearDown(container.dispose);
      // In the app this is already known by the time anyone opens Notifications.
      container.read(whatsNewProvider);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: CupertinoApp(theme: AppTheme.cupertino, home: home)));
      await settle(tester);
      return container;
    }

    testWidgets('Notifications lists what is new, marks it NEW once, and clears the dot', (tester) async {
      final container = await pump(tester, const NotificationsScreen(), unread: true);
      expect(find.text(latestWhatsNew.title), findsOneWidget);
      for (final item in latestWhatsNew.items) {
        expect(find.text(item.title), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('new_pill')), findsOneWidget);
      expect(container.read(whatsNewProvider), isFalse); // opening it counted as reading it
    });

    testWidgets('opened again later, it is not labelled NEW', (tester) async {
      await pump(tester, const NotificationsScreen(), unread: false);
      expect(find.byKey(const ValueKey('new_pill')), findsNothing);
      expect(find.text(latestWhatsNew.title), findsOneWidget);
    });

    testWidgets('the gear opens the notification settings', (tester) async {
      await pump(tester, const NotificationsScreen(), unread: false);
      await tester.tap(find.byKey(const ValueKey('notification_settings')));
      await settle(tester);
      expect(find.byType(NotificationsScreen), findsNothing); // covered by the settings page
    });

    testWidgets('Today shows a bell while there is something new, and it opens Notifications', (tester) async {
      var opened = 0;
      await pump(
        tester,
        CupertinoPageScaffold(
          child: SafeArea(child: DashboardHeader(streakDays: 3, dateLabel: 'Today', hasUnreadNotifications: true, onOpenNotifications: () => opened++)),
        ),
        unread: true,
      );
      expect(find.byKey(const ValueKey('whats_new_bell')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('whats_new_bell')));
      expect(opened, 1);
    });

    testWidgets('the bell stays on Today once everything is read, without the dot', (tester) async {
      var opened = 0;
      await pump(
        tester,
        CupertinoPageScaffold(
          child: SafeArea(child: DashboardHeader(streakDays: 3, dateLabel: 'Today', onOpenNotifications: () => opened++)),
        ),
        unread: false,
      );
      expect(find.byKey(const ValueKey('whats_new_bell')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread_dot')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('whats_new_bell')));
      expect(opened, 1);
    });

    testWidgets('the Profile tab’s Notifications row shows a dot, and opens Notifications', (tester) async {
      await pump(tester, const ProfileView(profile: null, hasUnreadNotifications: true), unread: true);
      expect(find.byKey(const ValueKey('unread_dot')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile_notifications')));
      await settle(tester);
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('no dot on the Profile row once read', (tester) async {
      await pump(tester, const ProfileView(profile: null), unread: false);
      expect(find.byKey(const ValueKey('unread_dot')), findsNothing);
    });
  });
}
