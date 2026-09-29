import 'package:flutter/cupertino.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/tracker_colors.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'library_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _screens = const [DashboardScreen(), InsightsScreen(), LibraryScreen()];

  static const _tabs = [
    (icon: CupertinoIcons.square_list, label: 'Log'),
    (icon: CupertinoIcons.chart_bar, label: 'Insights'),
    (icon: CupertinoIcons.book, label: 'Recipes'),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      backgroundColor: TrackerColors.background,
      tabBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        height: 58,
        iconSize: 22,
        backgroundColor: TrackerColors.navFill,
        activeColor: TrackerColors.accentStart,
        inactiveColor: TrackerColors.textTertiary,
        border: const Border(
          top: BorderSide(color: TrackerColors.border, width: 1),
        ),
        items: [
          for (var i = 0; i < _tabs.length; i++)
            BottomNavigationBarItem(
              icon: _TabIcon(
                icon: _tabs[i].icon,
                active: i == _index,
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
    required this.icon,
    required this.active,
  });

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.spring,
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
      child: Icon(
        icon,
        size: 20,
        color: active ? TrackerColors.accentStart : TrackerColors.textTertiary,
      ),
    );
  }
}
