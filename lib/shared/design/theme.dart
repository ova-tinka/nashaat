import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens/app-colors.dart';
import 'tokens/app-typography.dart';

class AppTheme {
  static const _shape = RoundedRectangleBorder();

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.paper,
      primaryContainer: AppColors.acid,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.inkSoft,
      onSecondary: AppColors.paper,
      secondaryContainer: AppColors.signal,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.acidPressed,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.acidMuted,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.error,
      onError: AppColors.paper,
      errorContainer: AppColors.errorMuted,
      onErrorContainer: AppColors.error,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.paperAlt,
      surfaceContainerHigh: AppColors.paperAlt,
      surfaceContainer: AppColors.paperAlt,
      surfaceContainerLow: AppColors.paper,
      surfaceContainerLowest: AppColors.paper,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.paperBorder,
      outlineVariant: AppColors.paperBorder,
      shadow: AppColors.ink,
      scrim: AppColors.ink,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
      inversePrimary: AppColors.acid,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: AppColors.paper,
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.paperAlt,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.heading,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(bottom: BorderSide(color: AppColors.paperBorder, width: 1)),
        iconTheme: const IconThemeData(color: AppColors.ink),
        actionsIconTheme: const IconThemeData(color: AppColors.ink),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.paper,
        shape: _shape,
        margin: EdgeInsets.zero,
      ),

      // Elevated button → primary action (ink bg, acid on press)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          elevation: 0,
          shape: _shape,
          textStyle: AppTypography.label.copyWith(fontSize: 14),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        ),
      ),

      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.paperBorder;
            if (states.contains(WidgetState.pressed)) return AppColors.inkSoft;
            return AppColors.ink;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.inkMuted;
            return AppColors.paper;
          }),
          elevation: const WidgetStatePropertyAll(0),
          shape: const WidgetStatePropertyAll(_shape),
          textStyle: WidgetStatePropertyAll(AppTypography.label.copyWith(fontSize: 14)),
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 1),
          shape: _shape,
          elevation: 0,
          textStyle: AppTypography.label.copyWith(fontSize: 14),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          shape: _shape,
          textStyle: AppTypography.label.copyWith(fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.acid,
        foregroundColor: AppColors.ink,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: _shape,
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.paperBorder, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.paperBorder, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.ink, width: 1.5),
          borderRadius: BorderRadius.zero,
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1),
          borderRadius: BorderRadius.zero,
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
          borderRadius: BorderRadius.zero,
        ),
        labelStyle: AppTypography.labelMuted,
        hintStyle: AppTypography.labelMuted,
        errorStyle: AppTypography.label.copyWith(color: AppColors.error, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.paperBorder,
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.ink,
        disabledColor: AppColors.paperAlt,
        labelStyle: AppTypography.label.copyWith(fontSize: 13),
        side: const BorderSide(color: AppColors.ink, width: 1),
        shape: _shape,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        elevation: 0,
        selectedShadowColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // Bottom navigation
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        indicatorColor: AppColors.acid,
        indicatorShape: _shape,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.label.copyWith(fontSize: 11);
          }
          return AppTypography.labelMuted.copyWith(fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.ink);
          }
          return const IconThemeData(color: AppColors.inkMuted);
        }),
        overlayColor: WidgetStatePropertyAll(AppColors.paperAlt),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),

      // Tab bar
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: AppTypography.label.copyWith(fontSize: 13),
        unselectedLabelStyle: AppTypography.label.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.inkMuted,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.ink, width: 2),
        ),
        dividerColor: AppColors.paperBorder,
        overlayColor: WidgetStatePropertyAll(AppColors.paperAlt),
      ),

      // Dialog
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.paper,
        elevation: 0,
        shape: _shape,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        elevation: 0,
        shape: _shape,
        modalBackgroundColor: AppColors.paper,
        modalElevation: 0,
        dragHandleColor: AppColors.paperBorder,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.body.copyWith(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: _shape,
        elevation: 0,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.paperBorder,
        circularTrackColor: AppColors.paperBorder,
        linearMinHeight: 2,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.paper;
          return AppColors.inkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ink;
          return AppColors.paperBorder;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ink;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.paper),
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        shape: const RoundedRectangleBorder(),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ink;
          return AppColors.inkMuted;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.ink,
        inactiveTrackColor: AppColors.paperBorder,
        thumbColor: AppColors.ink,
        overlayColor: AppColors.ink.withValues(alpha: 0.08),
        valueIndicatorColor: AppColors.ink,
        valueIndicatorTextStyle: AppTypography.monoStrong.copyWith(color: AppColors.paper),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 2,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: AppColors.paper,
        shape: _shape,
        titleTextStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: AppTypography.labelMuted,
        iconColor: AppColors.ink,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.paper,
        elevation: 2,
        shape: _shape,
        textStyle: AppTypography.body,
        shadowColor: AppColors.ink.withValues(alpha: 0.12),
      ),
    );
  }

  // Dark variant intentionally mirrors light with inverted ink/paper
  static ThemeData get dark => light;
}
