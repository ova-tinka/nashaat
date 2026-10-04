import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nashaat/features/shell/view/app-shell-screen.dart';
import 'package:nashaat/shared/design/atoms/app-nav-icon.dart';
import 'package:nashaat/shared/design/molecules/app-bottom-nav.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('navigation keeps the prototype order and platform split', () {
    final iosTabs = AppShellNavigation.tabsFor(TargetPlatform.iOS);
    final androidTabs = AppShellNavigation.tabsFor(TargetPlatform.android);

    expect(iosTabs.map((tab) => tab.label), [
      'Home',
      'Workouts',
      'Focus',
      'Majlis',
      'Profile',
    ]);
    expect(androidTabs.map((tab) => tab.label), [
      'Home',
      'Workouts',
      'Majlis',
      'Profile',
    ]);
    expect(iosTabs[0].glyph, AppNavGlyph.qasr);
    expect(iosTabs[1].glyph, AppNavGlyph.crossedOars);
    expect(iosTabs[2].glyph, AppNavGlyph.fanar);
    expect(iosTabs[3].glyph, AppNavGlyph.tent);
    expect(iosTabs[4].glyph, AppNavGlyph.wasm);
  });

  testWidgets('selected tab state follows taps and exposes semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const _NavHarness(
        palette: NashaatPalette.majlisNight,
        platform: TargetPlatform.android,
      ),
    );

    expect(
      tester
              .getSemantics(find.byKey(const ValueKey('app-tab-Home')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isTrue,
    );
    expect(
      tester
              .getSemantics(find.byKey(const ValueKey('app-tab-Majlis')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('app-tab-Majlis')));
    await tester.pump();

    expect(
      tester
              .getSemantics(find.byKey(const ValueKey('app-tab-Home')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isFalse,
    );
    expect(
      tester
              .getSemantics(find.byKey(const ValueKey('app-tab-Majlis')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isTrue,
    );

    semantics.dispose();
  });

  testWidgets('palette remains active while switching tabs', (tester) async {
    await tester.pumpWidget(
      const _NavHarness(
        palette: NashaatPalette.pearlDay,
        platform: TargetPlatform.android,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('app-tab-Workouts')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app-tab-Profile')));
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(AppBottomNav)));
    expect(theme.extension<NashaatPalette>(), same(NashaatPalette.pearlDay));
    expect(
      tester
              .getSemantics(find.byKey(const ValueKey('app-tab-Profile')))
              .flagsCollection
              .isSelected ==
          ui.Tristate.isTrue,
      isTrue,
    );
  });

  testWidgets('RTL keeps logical tab order usable and avoids overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _NavHarness(
        palette: NashaatPalette.majlisNight,
        platform: TargetPlatform.android,
        direction: TextDirection.rtl,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('Majlis'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    final home = tester.getRect(find.text('Home'));
    final profile = tester.getRect(find.text('Profile'));
    expect(home.center.dx, greaterThan(profile.center.dx));
  });
}

class _NavHarness extends StatefulWidget {
  final NashaatPalette palette;
  final TargetPlatform platform;
  final TextDirection direction;

  const _NavHarness({
    required this.palette,
    required this.platform,
    this.direction = TextDirection.ltr,
  });

  @override
  State<_NavHarness> createState() => _NavHarnessState();
}

class _NavHarnessState extends State<_NavHarness> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = AppShellNavigation.tabsFor(widget.platform);
    return MaterialApp(
      theme: AppTheme.buildTheme(widget.palette),
      home: Directionality(
        textDirection: widget.direction,
        child: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: tabs.map((tab) => tab.navItem()).toList(growable: false),
          ),
        ),
      ),
    );
  }
}
