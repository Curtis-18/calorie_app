import '../l10n/app_strings.dart';
import '../services/food_region_service.dart';
import '../services/web_push_service.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../services/app_shortcut.dart';
import 'conversations_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/activity_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/messages_provider.dart';
import '../services/profile_link.dart';
import '../widgets/profile_link_sheet.dart';
import '../providers/shell_provider.dart';
import '../providers/snaps_provider.dart';
import '../theme/app_motion.dart';
import '../theme/tracker_colors.dart';
import 'dashboard_screen.dart';
import 'friends_screen.dart';
import 'insights_screen.dart' show openInsights;
import 'workouts_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  /// Tour target keys for tab icons. Exposed statically so that
  /// DashboardScreen can reference them without constructor coupling.
  static final workoutsTabKey = GlobalKey(debugLabel: 'tourWorkoutsTab');
  static final friendsTabKey = GlobalKey(debugLabel: 'tourFriendsTab');
  static final profileTabKey = GlobalKey(debugLabel: 'tourProfileTab');

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // A controller, so other screens can move the person to a tab (Settings
  // sends them to Today to replay the tutorial).
  final _controller = CupertinoTabController();
  Timer? _messageTimer;
  late final AppLifecycleListener _lifecycle;
  final _screens = const [
    DashboardScreen(),
    WorkoutsScreen(),
    FriendsScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

  // In ShellTab order.
  static final _tabs = [
    (icon: CupertinoIcons.square_list, label: tr('Today'), key: null),
    (icon: CupertinoIcons.bolt, label: tr('Workouts'), key: MainShell.workoutsTabKey),
    (icon: CupertinoIcons.person_2, label: tr('Friends'), key: MainShell.friendsTabKey),
    (icon: CupertinoIcons.book, label: tr('Recipes'), key: null),
    (icon: CupertinoIcons.person_crop_circle, label: tr('Profile'), key: MainShell.profileTabKey),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
    // New messages show on the Friends tab wherever you are in the app.
    _messageTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshMessages());
    _lifecycle = AppLifecycleListener(onResume: _refreshMessages);
    ProfileLink.pending.addListener(_showLinkedProfile);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLinkedProfile());
    // A fresh shell (after signing in again) starts on Today.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(shellTabProvider.notifier).state = ShellTab.today;
      _openLaunchShortcut();
      // So push notifications are written in the language the app is showing.
      FoodRegionService().saveLanguage(AppStrings.active);
      // A browser that allowed notifications is registered again for whoever is signed in.
      WebPushService().refreshRegistration();
    });
  }

  /// Opened from a long-press shortcut on the Home Screen icon: go straight
  /// to what it names. Only at the first launch, never when coming back to Today.
  static bool _shortcutHandled = false;

  void _openLaunchShortcut({Uri? uri}) {
    if (_shortcutHandled) return;
    _shortcutHandled = true;
    switch (shortcutFromUri(uri ?? Uri.base)) {
      case AppShortcut.bites:
        ref.read(shellTabProvider.notifier).state = ShellTab.friends;
      case AppShortcut.insights:
        openInsights(context);
      case AppShortcut.messages:
        Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(builder: (_) => const ConversationsScreen()));
      case AppShortcut.log:
      case null:
        break; // Today is where logging happens: the camera button is right there.
    }
  }

  /// A friend's profile link was opened: offer to add them, once the app is
  /// settled on the main screen.
  Future<void> _showLinkedProfile() async {
    final name = ProfileLink.pending.value;
    if (name == null || !mounted) return;
    ProfileLink.clear();
    final friends = ref.read(friendsProvider.notifier);
    ref.read(shellTabProvider.notifier).state = ShellTab.friends;
    // Let the first screen finish building before a sheet goes over it.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await showProfileLinkSheet(
      context,
      username: name,
      friends: friends,
      myUsername: ref.read(friendsProvider).valueOrNull?.myUsername,
    );
  }

  void _refreshMessages() {
    if (!mounted) return;
    ref.read(conversationsProvider.notifier).load();
    // The bell's dot (bites and reactions) is kept fresh on the same beat.
    ref.read(activityProvider.notifier).load();
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    final tab = ShellTab.values[_controller.index];
    if (ref.read(shellTabProvider) != tab) ref.read(shellTabProvider.notifier).state = tab;
  }

  @override
  void dispose() {
    ProfileLink.pending.removeListener(_showLinkedProfile);
    _messageTimer?.cancel();
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShellTab>(shellTabProvider, (_, tab) {
      if (_controller.index != tab.index) _controller.index = tab.index;
    });
    final waiting = ref.watch(pendingRequestCountProvider) +
        ref.watch(unseenSnapCountProvider) +
        ref.watch(unreadMessagesProvider);
    final index = _controller.index;
    return CupertinoTabScaffold(
      controller: _controller,
      backgroundColor: TrackerColors.background,
      tabBar: CupertinoTabBar(
        height: 58,
        iconSize: 22,
        backgroundColor: TrackerColors.navFill,
        activeColor: TrackerColors.accentStartText,
        inactiveColor: TrackerColors.textTertiary,
        border: Border(
          top: BorderSide(color: TrackerColors.border, width: 1),
        ),
        items: [
          for (var i = 0; i < _tabs.length; i++)
            BottomNavigationBarItem(
              icon: TabIcon(
                key: _tabs[i].key,
                icon: _tabs[i].icon,
                active: i == index,
                badge: i == ShellTab.friends.index && waiting > 0,
              ),
              label: context.tr(_tabs[i].label),
            ),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(builder: (_) => _screens[index]),
    );
  }
}

/// Tab icon: the active one is tinted and a touch larger (no pill behind it).
@visibleForTesting
class TabIcon extends StatelessWidget {
  const TabIcon({
    super.key,
    required this.icon,
    required this.active,
    this.badge = false,
  });

  final IconData icon;
  final bool active;

  /// A small dot: something is waiting for the user on this tab.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.standard,
      width: 40,
      height: 32,
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(active ? 1.12 : 1.0, active ? 1.12 : 1.0, 1),
      transformAlignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: active ? TrackerColors.accentStartText : TrackerColors.textTertiary,
          ),
          if (badge)
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                key: const ValueKey('friends_badge'),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: TrackerColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: TrackerColors.navFill, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
