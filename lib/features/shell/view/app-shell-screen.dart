import 'package:flutter/material.dart';

import '../../blocking/view/focus-screen.dart';
import '../../dashboard/view/dashboard-screen.dart';
import '../../social/view/leaderboard-screen.dart';
import '../../settings/view/settings-screen.dart';
import '../../workout/view/workout-hub-screen.dart';

/// Root scaffold for the authenticated experience.
/// Holds the bottom navigation and lazily initialises each tab.
class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _TabDef(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    _TabDef(
        icon: Icons.fitness_center_outlined,
        selectedIcon: Icons.fitness_center,
        label: 'Workout'),
    _TabDef(
        icon: Icons.phone_android_outlined,
        selectedIcon: Icons.phone_android,
        label: 'Focus'),
    _TabDef(
        icon: Icons.leaderboard_outlined,
        selectedIcon: Icons.leaderboard,
        label: 'Social'),
    _TabDef(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const DashboardScreen(),
          const WorkoutHubScreen(),
          const FocusScreen(),
          const LeaderboardScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _TabDef(
      {required this.icon,
      required this.selectedIcon,
      required this.label});
}
