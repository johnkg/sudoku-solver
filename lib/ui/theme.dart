import 'package:flutter/material.dart';

import 'layout.dart';

/// The brand colour of the app, a cobalt blue.
const _cobalt = Color(0xFF2A4BFF);

/// The marker yellow: it picks out the answer cell on the board and anything
/// else the app wants the player to look at.
const _marker = Color(0xFFFFD84A);
const _onMarker = Color(0xFF2A2200);

/// Colours of the ink-on-paper look: a cool paper background and deep navy
/// text in light mode, deep navy and pale blue-white in dark mode.
ColorScheme _scheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: _cobalt, brightness: brightness);
  return base.copyWith(
    primary: dark ? const Color(0xFF7F95FF) : _cobalt,
    onPrimary: dark ? const Color(0xFF0B1225) : Colors.white,
    primaryContainer: dark ? const Color(0xFF223062) : const Color(0xFFDFE6FF),
    onPrimaryContainer: dark
        ? const Color(0xFFEAF0FF)
        : const Color(0xFF101C3A),
    tertiaryContainer: _marker,
    onTertiaryContainer: _onMarker,
    surface: dark ? const Color(0xFF0B1225) : const Color(0xFFEEF1F7),
    onSurface: dark ? const Color(0xFFEAF0FF) : const Color(0xFF101C3A),
    onSurfaceVariant: dark ? const Color(0xFF9AA9CF) : const Color(0xFF4A587A),
    surfaceContainerLowest: dark
        ? const Color(0xFF141D36)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: dark
        ? const Color(0xFF141D36)
        : const Color(0xFFFFFFFF),
    surfaceContainer: dark ? const Color(0xFF1C2745) : const Color(0xFFE4E9F3),
    surfaceContainerHigh: dark
        ? const Color(0xFF1C2745)
        : const Color(0xFFE4E9F3),
    outlineVariant: dark ? const Color(0xFF2B3858) : const Color(0xFFCBD3E4),
    error: dark ? const Color(0xFFFF7479) : const Color(0xFFE5484D),
  );
}

const _appBarTitleFontSize = 20.0;
const _navigationLabelFontSize = 12.0;

ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(cardRadius),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: _appBarTitleFontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(shape: shape),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: _navigationLabelFontSize,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, minTapHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: Typography.material2021().black
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          titleLarge: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
  );
}
