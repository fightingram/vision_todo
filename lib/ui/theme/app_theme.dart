import 'package:flutter/material.dart';
import 'design_tokens.dart';

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: DT.brandPrimary,
    onPrimary: DT.textInverse,
    secondary: DT.stateSuccess,
    onSecondary: DT.textInverse,
    error: DT.stateDanger,
    onError: DT.textInverse,
    background: DT.bgBase,
    onBackground: DT.textPrimary,
    surface: DT.bgSurface,
    onSurface: DT.textPrimary,
    outline: DT.borderStrong,
    outlineVariant: DT.borderSubtle,
    surfaceTint: Colors.transparent,
    // Material 3 extended roles
    primaryContainer: DT.brandPrimaryHover,
    onPrimaryContainer: DT.textInverse,
    secondaryContainer: DT.bgTint,
    onSecondaryContainer: DT.textPrimary,
    surfaceContainerHighest: DT.bgSurface,
    surfaceContainerHigh: DT.bgSurface,
    surfaceContainer: DT.bgSurface,
    surfaceContainerLow: DT.bgSurface,
    surfaceContainerLowest: DT.bgSurface,
    inverseSurface: DT.textPrimary,
    inversePrimary: DT.brandPrimaryPressed,
    scrim: Colors.black.withOpacity(0.32),
    shadow: Colors.black.withOpacity(0.08),
    tertiary: DT.stateWarning,
    onTertiary: DT.textInverse,
    tertiaryContainer: DT.stateWarning,
    onTertiaryContainer: DT.textInverse,
  );

  final textTheme = const TextTheme(
    displayLarge: TextStyle(fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w600, color: DT.textPrimary),
    titleLarge: TextStyle(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w600, color: DT.textPrimary),
    titleMedium: TextStyle(fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w600, color: DT.textPrimary),
    bodyMedium: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w400, color: DT.textPrimary),
    bodySmall: TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: DT.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: DT.bgBase,
    fontFamily: null, // use platform default
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: DT.bgBase, // match scaffold background
      foregroundColor: DT.textPrimary,
    ),
    cardTheme: CardTheme(
      color: DT.bgSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusL)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusM)),
      labelStyle: textTheme.bodySmall!,
      side: const BorderSide(color: DT.borderSubtle),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      selectedColor: DT.bgTint,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: DT.borderStrong),
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? DT.brandPrimary : DT.borderStrong),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderSide: BorderSide(color: DT.borderSubtle), borderRadius: BorderRadius.all(Radius.circular(DT.radiusM))),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: DT.borderSubtle), borderRadius: BorderRadius.all(Radius.circular(DT.radiusM))),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: DT.borderFocus, width: 2), borderRadius: BorderRadius.all(Radius.circular(DT.radiusM))),
      labelStyle: TextStyle(color: DT.textSecondary),
      hintStyle: TextStyle(color: DT.textSecondary),
      contentPadding: EdgeInsets.symmetric(horizontal: DT.spaceMD, vertical: 12),
    ),
    dividerColor: DT.borderSubtle,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(DT.brandPrimary),
        foregroundColor: const WidgetStatePropertyAll(DT.textInverse),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.radiusL)),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: DT.spaceLG, vertical: 14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(foregroundColor: const WidgetStatePropertyAll(DT.textLink)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: DT.brandPrimary,
      foregroundColor: DT.textInverse,
      elevation: 3,
      shape: CircleBorder(),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: DT.bgSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: DT.brandPrimary,
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: DT.textSecondary)),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(color: DT.textSecondary)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: DT.textSecondary,
      textColor: DT.textPrimary,
    ),
  );
}
