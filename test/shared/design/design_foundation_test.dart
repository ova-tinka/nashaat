import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nashaat/app/appearance-provider.dart';
import 'package:nashaat/shared/design/atoms/app-button.dart';
import 'package:nashaat/shared/design/atoms/app-sadu-band.dart';
import 'package:nashaat/shared/design/atoms/app-status-pill.dart';
import 'package:nashaat/shared/design/atoms/app-wasm-badge.dart';
import 'package:nashaat/shared/design/molecules/app-dotted-slider.dart';
import 'package:nashaat/shared/design/molecules/app-streak-loom.dart';
import 'package:nashaat/shared/design/theme.dart';
import 'package:nashaat/shared/design/tokens/app-colors.dart';
import 'package:nashaat/shared/design/tokens/app-radii.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget themed(
    Widget child, {
    NashaatPalette palette = NashaatPalette.majlisNight,
  }) {
    return MaterialApp(
      theme: AppTheme.buildTheme(palette),
      home: Scaffold(body: child),
    );
  }

  test('palette presets expose the prototype semantic roles', () {
    expect(NashaatPalette.values, hasLength(4));
    expect(NashaatPalette.majlisNight.background, const Color(0xFF15110E));
    expect(NashaatPalette.majlisNight.accent, const Color(0xFF2BC4B0));
    expect(NashaatPalette.pearlDay.background, const Color(0xFFF6EFE3));
    expect(
      NashaatPalette.forId(NashaatPaletteId.nakheelDay),
      same(NashaatPalette.nakheelDay),
    );
    expect(
      NashaatPalette.idFromStorage('unknown'),
      NashaatPaletteId.majlisNight,
    );
  });

  test(
    'appearance provider restores and persists the selected palette',
    () async {
      SharedPreferences.setMockInitialValues({'app_palette': 'pearlDay'});
      final provider = AppearanceProvider();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.paletteId, NashaatPaletteId.pearlDay);

      await provider.setPalette(NashaatPaletteId.adaamNight);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('app_palette'), 'adaamNight');
      provider.dispose();
    },
  );

  testWidgets('theme maps the active palette and uses the new type ramp', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const SizedBox(), palette: NashaatPalette.nakheelDay),
    );

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.scaffoldBackgroundColor, NashaatPalette.nakheelDay.background);
    expect(theme.colorScheme.primary, NashaatPalette.nakheelDay.accent);
    expect(theme.extension<NashaatPalette>(), same(NashaatPalette.nakheelDay));
    expect(theme.textTheme.headlineMedium?.fontFamily, startsWith('Changa'));
    expect(theme.textTheme.bodyMedium?.fontFamily, contains('Readex'));
  });

  testWidgets('primary button uses the 52px accent treatment', (tester) async {
    await tester.pumpWidget(
      themed(AppButton.primary('Start workout', onPressed: () {})),
    );

    final button = tester.getSize(find.byType(AppButton));
    expect(button.height, 52);
    expect(find.text('Start workout'), findsOneWidget);
    expect(AppRadii.button, isNot(AppRadii.sharp));
  });

  testWidgets('dotted slider selects only discrete values', (tester) async {
    var value = 1;
    await tester.pumpWidget(
      themed(
        SizedBox(
          width: 300,
          child: AppDottedSlider(
            values: const [1, 2, 3],
            value: value,
            semanticLabel: 'Phone hours',
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(AppDottedSlider));
    await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
    expect(value, 3);
  });

  testWidgets('identity kit renders all eight streak bands and status states', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const Column(
          children: [
            AppStatusPill(
              label: 'Needs attention',
              tone: AppStatusTone.attention,
            ),
            AppSaduBand(),
            AppStreakLoom(completedBands: 2, currentProgress: 0.5),
            AppWasmBadge(label: 'M'),
          ],
        ),
      ),
    );

    expect(find.byType(AppSaduBand), findsNWidgets(9));
    expect(find.byType(AppWasmBadge), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
