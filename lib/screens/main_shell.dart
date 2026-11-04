import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/friends_provider.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/tracker_colors.dart';
import 'dashboard_screen.dart';
import 'friends_screen.dart';
import 'insights_screen.dart';
import 'library_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  /// Tour target key for the Insights tab icon. Exposed statically so that
  /// DashboardScreen can reference it without constructor coupling.
  static final insightsTabKey = GlobalKey(debugLabel: 'tourInsightsTab');

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  final _screens = const [DashboardScreen(), InsightsScreen(), FriendsScreen(), LibraryScreen()];

  static const _tabs = [
    (icon: CupertinoIcons.square_list, label: 'Log'),
    (icon: CupertinoIcons.chart_bar, label: 'Insights'),
    (icon: CupertinoIcons.person_2, label: 'Friends'),
    (icon: CupertinoIcons.book, label: 'Recipes'),
  ];

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(pendingRequestCountProvider);
    return CupertinoTabScaffold(
      backgroundColor: TrackerColors.background,
      tabBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
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
              icon: _TabIcon(
                key: i == 1 ? MainShell.insightsTabKey : null,
                icon: _tabs[i].icon,
                active: i == _index,
                badge: i == 2 && waiting > 0,
              ),
              label: _tabs[i].label,
            ),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(builder: (_) => _screens[index]),
    );
  }
}

/// Floating glass pill behind the active tab icon.
class _TabIcon extends StatelessWidget {
  const _TabIcon({
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
      width: active ? 56 : 40,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? TrackerColors.alpha(TrackerColors.accentStart, 0.16)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? TrackerColors.alpha(TrackerColors.accentStart, 0.28) : const Color(0x00000000),
          width: 1,
        ),
        boxShadow: active
            ? AppDecor.glow(TrackerColors.accentStart, blur: 14, opacity: 0.3)
            : null,
      ),
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
