import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design/atoms/app-nav-icon.dart';
import '../../../shared/design/atoms/app-sadu-band.dart';
import '../../../shared/design/molecules/app-bottom-nav.dart';
import '../../../shared/design/organisms/app-scaffold.dart';
import '../../blocking/view/focus-screen.dart';
import '../../dashboard/view/dashboard-screen.dart';
import '../../social/view/leaderboard-screen.dart';
import '../../settings/view/settings-screen.dart';
import '../../workout/view/workout-hub-screen.dart';

enum AppShellTab { home, workouts, focus, majlis, profile }

class AppShellTabDefinition {
  final AppShellTab tab;
  final String label;
  final AppNavGlyph glyph;
  final AppSaduMotif motif;

  const AppShellTabDefinition({
    required this.tab,
    required this.label,
    required this.glyph,
    required this.motif,
  });

  AppBottomNavItem navItem({String wasmLabel = 'N'}) => AppBottomNavItem(
    label: label,
    glyph: glyph,
    motif: motif,
    wasmLabel: wasmLabel,
  );
}

class AppShellNavigation {
  static List<AppShellTabDefinition> tabsFor(TargetPlatform platform) {
    final tabs = <AppShellTabDefinition>[
      const AppShellTabDefinition(
        tab: AppShellTab.home,
        label: 'Home',
        glyph: AppNavGlyph.qasr,
        motif: AppSaduMotif.diamonds,
      ),
      const AppShellTabDefinition(
        tab: AppShellTab.workouts,
        label: 'Workouts',
        glyph: AppNavGlyph.crossedOars,
        motif: AppSaduMotif.chevrons,
      ),
      const AppShellTabDefinition(
        tab: AppShellTab.majlis,
        label: 'Majlis',
        glyph: AppNavGlyph.tent,
        motif: AppSaduMotif.stars,
      ),
      const AppShellTabDefinition(
        tab: AppShellTab.profile,
        label: 'Profile',
        glyph: AppNavGlyph.wasm,
        motif: AppSaduMotif.steps,
      ),
    ];

    if (platform == TargetPlatform.iOS) {
      tabs.insert(
        2,
        const AppShellTabDefinition(
          tab: AppShellTab.focus,
          label: 'Focus',
          glyph: AppNavGlyph.fanar,
          motif: AppSaduMotif.waves,
        ),
      );
    }

    return List.unmodifiable(tabs);
  }
}

class AppShellScreen extends StatefulWidget {
  final TargetPlatform? platform;

  const AppShellScreen({super.key, this.platform});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform ?? defaultTargetPlatform;
    final tabs = AppShellNavigation.tabsFor(platform);
    final isIOS = platform == TargetPlatform.iOS;
    final selectedIndex = _tabIndex.clamp(0, tabs.length - 1).toInt();
    final majlisIndex = tabs.indexWhere((tab) => tab.tab == AppShellTab.majlis);
    final wasmLabel = _currentWasmLabel();

    final pages = <Widget>[
      DashboardScreen(isActive: selectedIndex == 0),
      const WorkoutHubScreen(),
    ];
    if (isIOS) pages.add(const FocusScreen());
    pages.add(LeaderboardScreen(isActive: selectedIndex == majlisIndex));
    pages.add(const SettingsScreen());

    return AppScaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: selectedIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: tabs
            .map((tab) => tab.navItem(wasmLabel: wasmLabel))
            .toList(growable: false),
      ),
    );
  }

  String _currentWasmLabel() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final value = metadata['username'] ?? metadata['name'] ?? user?.email;
    if (value is! String || value.trim().isEmpty) return 'N';
    return String.fromCharCode(value.trim().runes.first).toUpperCase();
  }
}
