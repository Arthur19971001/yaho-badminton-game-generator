import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistent desktop navigation rail wrapping the top-level "회원 관리",
/// "세션", "급수 관리" and "설정" sections. Pushed routes (attendance/setup/results) render outside
/// of this shell via the root navigator so they get their own back button.
class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('회원 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: Text('세션'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.military_tech_outlined),
                selectedIcon: Icon(Icons.military_tech),
                label: Text('급수 관리'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('설정'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
