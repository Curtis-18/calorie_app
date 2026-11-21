import 'package:calorie_app/models/messages.dart';
import 'package:calorie_app/models/snaps.dart';
import 'package:calorie_app/providers/display_prefs_provider.dart';
import 'package:calorie_app/providers/messages_provider.dart';
import 'package:calorie_app/providers/shell_provider.dart';
import 'package:calorie_app/providers/snaps_provider.dart';
import 'package:calorie_app/screens/conversations_screen.dart';
import 'package:calorie_app/theme/app_theme.dart';
import 'package:calorie_app/widgets/home_social_tiles.dart';
import 'package:calorie_app/widgets/meals_fold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

class FakeInbox extends SnapInboxNotifier {
  FakeInbox(List<InboxSnap> snaps) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    state = AsyncValue.data(snaps);
  }
}

class FakeConversations extends ConversationsNotifier {
  FakeConversations(List<Conversation> list) : super(currentUserId: () => null, userIdChanges: const Stream.empty()) {
    state = AsyncValue.data(ConversationsData(list));
  }
}

InboxSnap snap(String id, String from, {bool viewed = false}) => InboxSnap(
      id: id,
      senderId: 'u_$from',
      senderUsername: from,
      caption: null,
      createdAt: DateTime(2026, 11, 21, 12),
      expiresAt: DateTime(2026, 11, 22, 12),
      viewed: viewed,
      reaction: null,
      imageUrl: 'https://example.com/$id.jpg',
    );

Conversation chat(String from, int unread) => Conversation(
      userId: 'u_$from',
      username: from,
      lastBody: 'hi',
      lastMine: false,
      lastAt: DateTime(2026, 11, 21, 12),
      unread: unread,
    );

Future<ProviderContainer> showTiles(WidgetTester tester, {List<InboxSnap> snaps = const [], List<Conversation> chats = const []}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    snapInboxProvider.overrideWith((ref) => FakeInbox(snaps)),
    conversationsProvider.overrideWith((ref) => FakeConversations(chats)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: CupertinoApp(
      theme: AppTheme.cupertino,
      home: const CupertinoPageScaffold(child: SafeArea(child: Padding(padding: EdgeInsets.all(24), child: HomeSocialTiles()))),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the Bites and Messages tiles', () {
    test('what the lines say', () {
      expect(HomeSocialTiles.bitesLine(0, null), 'Send one to a friend');
      expect(HomeSocialTiles.bitesLine(1, 'mia'), 'From mia');
      expect(HomeSocialTiles.bitesLine(3, 'mia'), '3 new, latest from mia');
      expect(HomeSocialTiles.messagesLine(0, null), 'All caught up');
      expect(HomeSocialTiles.messagesLine(1, 'leo'), 'From leo');
      expect(HomeSocialTiles.messagesLine(4, 'leo'), '4 new, latest from leo');
      expect(HomeSocialTiles.messagesLine(2, null), '2 new');
    });

    testWidgets('with nothing waiting both tiles are calm', (tester) async {
      await showTiles(tester);
      expect(find.text('Bites'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Send one to a friend'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
    }, variant: ios);

    testWidgets('waiting bites and messages show who they are from', (tester) async {
      await showTiles(
        tester,
        snaps: [snap('1', 'mia'), snap('2', 'mia'), snap('3', 'old', viewed: true)],
        chats: [chat('leo', 1)],
      );
      expect(find.text('2 new, latest from mia'), findsOneWidget);
      expect(find.text('From leo'), findsOneWidget);
    }, variant: ios);

    testWidgets('a viewed bite does not count as waiting', (tester) async {
      await showTiles(tester, snaps: [snap('1', 'mia', viewed: true)]);
      expect(find.text('Send one to a friend'), findsOneWidget);
    }, variant: ios);

    testWidgets('with no bite waiting, the Bites tile takes you to Friends', (tester) async {
      final container = await showTiles(tester);
      expect(container.read(shellTabProvider), ShellTab.today);
      await tester.tap(find.byKey(const ValueKey('home_bites_tile')));
      await tester.pump();
      expect(container.read(shellTabProvider), ShellTab.friends);
    }, variant: ios);

    testWidgets('the Messages tile opens the conversations', (tester) async {
      await showTiles(tester, chats: [chat('leo', 2)]);
      await tester.tap(find.byKey(const ValueKey('home_messages_tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(ConversationsScreen), findsOneWidget);
    }, variant: ios);

    testWidgets('each tile is announced as a button with its status', (tester) async {
      final handle = tester.ensureSemantics();
      await showTiles(tester, chats: [chat('leo', 1)]);
      expect(find.bySemanticsLabel('Messages. From leo'), findsOneWidget);
      expect(find.bySemanticsLabel('Bites. Send one to a friend'), findsOneWidget);
      handle.dispose();
    }, variant: ios);
  });

  group('the meals fold', () {
    final totals = [
      const MealTotal(title: 'Breakfast', calories: 320, icon: CupertinoIcons.sunrise_fill),
      const MealTotal(title: 'Lunch', calories: 0, icon: CupertinoIcons.sun_max_fill),
      const MealTotal(title: 'Dinner', calories: 610, icon: CupertinoIcons.moon_stars_fill),
    ];

    Future<void> mount(WidgetTester tester, {required bool open, VoidCallback? onToggle, List<MealTotal>? list}) async {
      await tester.pumpWidget(CupertinoApp(
        theme: AppTheme.cupertino,
        home: CupertinoPageScaffold(
          child: SafeArea(
            child: SingleChildScrollView(
              child: MealsFold(
                label: "Today's meals",
                countLabel: '3 items',
                open: open,
                onToggle: onToggle ?? () {},
                totals: list ?? totals,
                child: const Text('the meal cards', key: ValueKey('cards')),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('open shows the cards and no chips', (tester) async {
      await mount(tester, open: true);
      expect(find.byKey(const ValueKey('cards')), findsOneWidget);
      expect(find.byKey(const ValueKey('meals_folded')), findsNothing);
    }, variant: ios);

    testWidgets('folded shows one chip per meal that has food, with its calories', (tester) async {
      await mount(tester, open: false);
      expect(find.byKey(const ValueKey('cards')), findsNothing);
      expect(find.byKey(const ValueKey('chip_Breakfast')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_Dinner')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_Lunch')), findsNothing, reason: 'an empty meal has no chip');
      expect(find.text('320'), findsOneWidget);
      expect(find.text('610'), findsOneWidget);
    }, variant: ios);

    testWidgets('folded with nothing logged invites you to open it', (tester) async {
      await mount(tester, open: false, list: const []);
      expect(find.text('Nothing logged yet. Tap to open your meals.'), findsOneWidget);
    }, variant: ios);

    testWidgets('tapping the header, or a chip, toggles', (tester) async {
      var toggles = 0;
      await mount(tester, open: false, onToggle: () => toggles++);
      await tester.tap(find.byKey(const ValueKey('meals_fold_header')));
      await tester.pump();
      expect(toggles, 1);
      await tester.tap(find.byKey(const ValueKey('chip_Breakfast')));
      await tester.pump();
      expect(toggles, 2);
    }, variant: ios);

    testWidgets('folding and unfolding animates without errors and ends in the right state', (tester) async {
      await mount(tester, open: true);
      await mount(tester, open: false);
      expect(find.byKey(const ValueKey('cards')), findsNothing);
      await mount(tester, open: true);
      expect(find.byKey(const ValueKey('cards')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: ios);

    testWidgets('the header is announced with its expanded state', (tester) async {
      final handle = tester.ensureSemantics();
      await mount(tester, open: true);
      final node = tester.getSemantics(find.byKey(const ValueKey('meals_fold_header')));
      expect(node.label, contains("Today's meals"));
      handle.dispose();
    }, variant: ios);
  });

  group('the remembered fold', () {
    test('open by default', () {
      expect(const DisplayPrefs().mealsOpen, isTrue);
    });

    test('folding is remembered and survives a restart', () async {
      final a = DisplayPrefsNotifier();
      await Future<void>.delayed(Duration.zero);
      await a.setMealsOpen(false);
      expect(a.state.mealsOpen, isFalse);
      final b = DisplayPrefsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.state.mealsOpen, isFalse);
      await b.setMealsOpen(true);
      final c = DisplayPrefsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.state.mealsOpen, isTrue);
    });

    test('the other choices are untouched by it', () async {
      final a = DisplayPrefsNotifier();
      await Future<void>.delayed(Duration.zero);
      await a.setShowMacros(false);
      await a.setMealsOpen(false);
      expect(a.state.showMacros, isFalse);
      expect(a.state.showNutrients, isTrue);
    });
  });
}
