import 'package:flutter/cupertino.dart';
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

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.square_list), label: 'Log'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Recipes'),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(builder: (_) => _screens[index]),
    );
  }
}
