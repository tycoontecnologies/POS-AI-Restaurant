import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.onAccent,
      error: AppColors.error,
      onError: AppColors.onError,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.grey900,
      surfaceVariant: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.grey700,
      background: AppColors.backgroundLight,
      onBackground: AppColors.grey900,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: AppSpacing.elevation2,
      shadowColor: AppColors.grey200,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      toolbarHeight: AppSpacing.appBarHeight,
    ),

    cardTheme: CardThemeData(
      elevation: AppSpacing.elevation2,
      shadowColor: AppColors.grey200,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      margin: const EdgeInsets.all(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.disabledLight,
        disabledForegroundColor: AppColors.onDisabledLight,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, AppSpacing.buttonHeight),
        elevation: AppSpacing.elevation2,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.onDisabledLight,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, AppSpacing.buttonHeight),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.onDisabledLight,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, AppSpacing.buttonHeight),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.outlineLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.outlineLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.disabledLight),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      filled: true,
      fillColor: AppColors.grey50,
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey500),
      labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.grey700),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.grey100,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.disabledLight,
      labelStyle: AppTypography.labelMedium,
      secondaryLabelStyle: AppTypography.labelMedium.copyWith(
        color: AppColors.onPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.grey50),
      headingTextStyle: AppTypography.labelLarge.copyWith(
        color: AppColors.grey700,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: AppTypography.bodyMedium,
      columnSpacing: AppSpacing.lg,
      horizontalMargin: AppSpacing.md,
      dividerThickness: 1,
      headingRowHeight: AppSpacing.listItemHeight,
      dataRowMinHeight: AppSpacing.buttonHeight,
      dataRowMaxHeight: AppSpacing.listItemHeight,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      minVerticalPadding: AppSpacing.sm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSm)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      elevation: AppSpacing.elevation8,
      titleTextStyle: AppTypography.h5.copyWith(color: AppColors.grey900),
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.grey700,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: AppSpacing.elevation6,
      shape: CircleBorder(),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.grey500,
      type: BottomNavigationBarType.fixed,
      elevation: AppSpacing.elevation8,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: AppTypography.fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      onPrimary: AppColors.grey900,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.grey900,
      tertiary: AppColors.accentLight,
      onTertiary: AppColors.grey900,
      error: AppColors.errorLight,
      onError: AppColors.grey900,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.grey100,
      surfaceVariant: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.grey300,
      background: AppColors.backgroundDark,
      onBackground: AppColors.grey100,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.white,
      elevation: AppSpacing.elevation2,
      shadowColor: AppColors.black,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      toolbarHeight: AppSpacing.appBarHeight,
    ),

    cardTheme: CardThemeData(
      elevation: AppSpacing.elevation2,
      shadowColor: AppColors.black.withOpacity(0.5),
      color: AppColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      margin: const EdgeInsets.all(AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.grey900,
        disabledBackgroundColor: AppColors.disabledDark,
        disabledForegroundColor: AppColors.onDisabledDark,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, AppSpacing.buttonHeight),
        elevation: AppSpacing.elevation2,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        disabledForegroundColor: AppColors.onDisabledDark,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, AppSpacing.buttonHeight),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        disabledForegroundColor: AppColors.onDisabledDark,
        textStyle: AppTypography.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, AppSpacing.buttonHeight),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.outlineDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.outlineDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.errorLight),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.errorLight, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: const BorderSide(color: AppColors.disabledDark),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      filled: true,
      fillColor: AppColors.grey800,
      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.grey400),
      labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.grey300),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.grey800,
      selectedColor: AppColors.primaryLight,
      disabledColor: AppColors.disabledDark,
      labelStyle: AppTypography.labelMedium.copyWith(color: AppColors.grey200),
      secondaryLabelStyle: AppTypography.labelMedium.copyWith(
        color: AppColors.grey900,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.grey800),
      headingTextStyle: AppTypography.labelLarge.copyWith(
        color: AppColors.grey200,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.grey300,
      ),
      columnSpacing: AppSpacing.lg,
      horizontalMargin: AppSpacing.md,
      dividerThickness: 1,
      headingRowHeight: AppSpacing.listItemHeight,
      dataRowMinHeight: AppSpacing.buttonHeight,
      dataRowMaxHeight: AppSpacing.listItemHeight,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      minVerticalPadding: AppSpacing.sm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSm)),
      ),
      textColor: AppColors.grey200,
      iconColor: AppColors.grey300,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      elevation: AppSpacing.elevation8,
      titleTextStyle: AppTypography.h5.copyWith(color: AppColors.grey100),
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.grey300,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.grey900,
      elevation: AppSpacing.elevation6,
      shape: CircleBorder(),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.grey500,
      type: BottomNavigationBarType.fixed,
      elevation: AppSpacing.elevation8,
    ),
  );
}
