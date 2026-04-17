import 'package:flutter/material.dart';

import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../../blocking/view/focus-screen.dart';
import '../../dashboard/view/dashboard-screen.dart';
import '../../social/view/leaderboard-screen.dart';
import '../../settings/view/settings-screen.dart';
import '../../workout/view/workout-hub-screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    _TabDef(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    _TabDef(icon: Icons.fitness_center_outlined, selectedIcon: Icons.fitness_center, label: 'Workout'),
    _TabDef(icon: Icons.phone_android_outlined, selectedIcon: Icons.phone_android, label: 'Focus'),
    _TabDef(icon: Icons.leaderboard_outlined, selectedIcon: Icons.leaderboard, label: 'Social'),
    _TabDef(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          DashboardScreen(),
          WorkoutHubScreen(),
          FocusScreen(),
          LeaderboardScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _AppBottomNav(
        selectedIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        tabs: _tabs,
      ),
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_TabDef> tabs;

  const _AppBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.paperBorder, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.acid : AppColors.paper,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? tab.selectedIcon : tab.icon,
                          size: 20,
                          color: selected ? AppColors.ink : AppColors.inkMuted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: AppTypography.labelMuted.copyWith(
                            fontSize: 10,
                            color: selected ? AppColors.ink : AppColors.inkMuted,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _TabDef({required this.icon, required this.selectedIcon, required this.label});
}
