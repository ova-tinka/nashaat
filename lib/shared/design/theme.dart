import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens/app-colors.dart';
import 'tokens/app-radii.dart';
import 'tokens/app-typography.dart';

class AppTheme {
  static ThemeData buildTheme(NashaatPalette palette, {Locale? locale}) {
    final textTheme = AppTypography.getTextTheme(
      locale: locale,
      palette: palette,
    );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: palette.brightness,
        ).copyWith(
          primary: palette.accent,
          onPrimary: palette.accentInk,
          primaryContainer: palette.raised,
          onPrimaryContainer: palette.textPrimary,
          secondary: palette.reward,
          onSecondary: palette.rewardInk,
          secondaryContainer: palette.card,
          onSecondaryContainer: palette.textPrimary,
          tertiary: palette.calm,
          onTertiary: palette.calmInk,
          tertiaryContainer: palette.well,
          onTertiaryContainer: palette.textPrimary,
          error: palette.danger,
          onError: palette.dangerInk,
          errorContainer: palette.danger.withValues(alpha: 0.18),
          onErrorContainer: palette.dangerText,
          surface: palette.background,
          onSurface: palette.textPrimary,
          surfaceContainerHighest: palette.raised,
          surfaceContainerHigh: palette.raised,
          surfaceContainer: palette.card,
          surfaceContainerLow: palette.well,
          surfaceContainerLowest: palette.background,
          onSurfaceVariant: palette.textSecondary,
          outline: palette.border,
          outlineVariant: palette.border,
          scrim: palette.scrim,
          inverseSurface: palette.textPrimary,
          onInverseSurface: palette.background,
          inversePrimary: palette.accentText,
        );

    final cardShape = RoundedRectangleBorder(borderRadius: AppRadii.card);
    final controlShape = RoundedRectangleBorder(borderRadius: AppRadii.control);
    final buttonShape = RoundedRectangleBorder(borderRadius: AppRadii.button);
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: palette.border),
      borderRadius: AppRadii.control,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: palette.raised,

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        systemOverlayStyle: palette.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        shape: Border(bottom: BorderSide(color: palette.border, width: 1)),
        iconTheme: IconThemeData(color: palette.textPrimary),
        actionsIconTheme: IconThemeData(color: palette.textPrimary),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.card,
        shape: cardShape,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.accentInk,
          elevation: 0,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return palette.raised;
            if (states.contains(WidgetState.pressed)) {
              return palette.accentText;
            }
            return palette.accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return palette.textMuted;
            }
            return palette.accentInk;
          }),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          shape: buttonShape,
          elevation: 0,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: palette.accentInk,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: buttonShape,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.well,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.calmText, width: 1.5),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.dangerText, width: 1),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: palette.dangerText, width: 1.5),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: palette.textMuted),
        hintStyle: textTheme.labelMedium?.copyWith(color: palette.textMuted),
        errorStyle: textTheme.labelSmall?.copyWith(color: palette.dangerText),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: palette.selection,
        disabledColor: palette.raised,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.pill),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        elevation: 0,
        selectedShadowColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.background,
        indicatorColor: palette.selection,
        indicatorShape: controlShape,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? palette.textPrimary : palette.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.textPrimary : palette.textMuted,
          );
        }),
        overlayColor: WidgetStatePropertyAll(palette.raised),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: palette.textPrimary,
        unselectedLabelColor: palette.textMuted,
        labelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium?.copyWith(
          color: palette.textMuted,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
        dividerColor: palette.border,
        overlayColor: WidgetStatePropertyAll(palette.raised),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
        surfaceTintColor: Colors.transparent,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        modalBackgroundColor: palette.card,
        modalElevation: 0,
        dragHandleColor: palette.border,
        surfaceTintColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.raised,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        elevation: 0,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.accent,
        linearTrackColor: palette.raised,
        circularTrackColor: palette.raised,
        linearMinHeight: 4,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accentInk;
          return palette.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.raised;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(palette.accentInk),
        side: BorderSide(color: palette.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.xs),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.accent;
          return palette.textMuted;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.raised,
        thumbColor: palette.textPrimary,
        overlayColor: palette.accent.withValues(alpha: 0.12),
        valueIndicatorColor: palette.raised,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: palette.textPrimary,
        ),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        trackHeight: 3,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: palette.card,
        shape: cardShape,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.labelMedium?.copyWith(
          color: palette.textMuted,
        ),
        iconColor: palette.textPrimary,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.control),
        textStyle: textTheme.bodyMedium,
        shadowColor: Colors.black.withValues(alpha: 0.16),
      ),
    );
  }

  // Compatibility getters for code that still references the original theme.
  static ThemeData get light => buildTheme(NashaatPalette.pearlDay);
  static ThemeData get dark => buildTheme(NashaatPalette.majlisNight);
}
