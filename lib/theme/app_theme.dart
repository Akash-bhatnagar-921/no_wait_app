import 'package:flutter/material.dart';

enum GenderTheme { female, male, other }

/// Three ThemeData variants — one per gender identity.
class AppTheme {
  AppTheme._();

  static ThemeData of(GenderTheme g) {
    switch (g) {
      case GenderTheme.male:
        return _male;
      case GenderTheme.other:
        return _pride;
      case GenderTheme.female:
        return _green;
    }
  }

  // ─── 1. Female — Natural Green ─────────────────────────────────────────────
  // Primary green #6FCF97, clean white background, dark green text.
  static final ThemeData _green = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6FCF97),
      secondary: Color(0xFF2D9248),
      tertiary: Color(0xFF4CAF7C),
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: Color(0xFF1A1A1A),
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.bold,
          fontSize: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6FCF97),
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF6FCF97)),
        foregroundColor: const Color(0xFF6FCF97),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFF6FCF97),
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF6FCF97),
      indicatorColor: Color(0xFF6FCF97),
      unselectedLabelColor: Colors.grey,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFF6FCF97)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? const Color(0xFF6FCF97)
              : null),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    dialogTheme: DialogThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
  );

  // ─── 2. Male — Gold, Black & Cream ────────────────────────────────────────
  // Brand palette:
  //   Primary   #C89B4F  (warm gold)
  //   Secondary #111111  (black)
  //   Background #F7F5F2 (cream — light theme)
  //   Success   #3B8B5E
  //   Warning   #B8892D
  static final ThemeData _male = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFC89B4F),       // gold
      secondary: Color(0xFF111111),     // black
      tertiary: Color(0xFF3B8B5E),      // success green
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: Color(0xFF111111),     // black body text
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F5F2),   // cream
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF111111),   // black bar
      foregroundColor: Color(0xFFC89B4F),   // gold icons/back arrow
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          color: Color(0xFFC89B4F),
          fontWeight: FontWeight.bold,
          fontSize: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC89B4F),   // gold button
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC89B4F)),
        foregroundColor: const Color(0xFFC89B4F),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFFC89B4F),
      unselectedItemColor: Colors.grey,
      backgroundColor: Color(0xFF111111),    // black bar
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFFC89B4F),
      indicatorColor: Color(0xFFC89B4F),
      unselectedLabelColor: Colors.grey,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFFC89B4F)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? const Color(0xFFC89B4F)
              : null),
    ),
    drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF111111)),   // black drawer
    dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    dividerColor: const Color(0xFFE0DDD8),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF111111)),
      bodyMedium: TextStyle(color: Color(0xFF333333)),
      bodySmall: TextStyle(color: Color(0xFF555555)),
    ),
  );

  // ─── 3. Other — Pride Inclusive ───────────────────────────────────────────
  // Clean white base for maximum readability; rainbow accents used only for
  // highlights, borders, and decorations — not as text colour.
  static final ThemeData _pride = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7B3FA0),       // deep purple (AA-contrast on white)
      secondary: Color(0xFFD81B60),     // vivid pink
      tertiary: Color(0xFF0277BD),      // blue
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: Color(0xFF1A1A1A),     // near-black — ALL body text readable
    ),
    scaffoldBackgroundColor: Colors.white,    // pure white — no purple tint
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1A1A),   // dark text, not purple
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontWeight: FontWeight.bold,
          fontSize: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7B3FA0),   // deep purple button
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF7B3FA0)),
        foregroundColor: const Color(0xFF7B3FA0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFF7B3FA0),
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF7B3FA0),
      indicatorColor: Color(0xFF7B3FA0),
      unselectedLabelColor: Colors.grey,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFF7B3FA0)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? const Color(0xFF7B3FA0)
              : null),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    dialogTheme: DialogThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    dividerColor: const Color(0xFFEEEEEE),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
      bodyMedium: TextStyle(color: Color(0xFF333333)),
      bodySmall: TextStyle(color: Color(0xFF666666)),
    ),
  );
}

// ─── Per-theme metadata ───────────────────────────────────────────────────────

extension GenderThemeMeta on GenderTheme {
  String get label {
    switch (this) {
      case GenderTheme.female:
        return 'Natural Green';
      case GenderTheme.male:
        return 'Gold & Black';
      case GenderTheme.other:
        return 'Pride Vibrant';
    }
  }

  String get description {
    switch (this) {
      case GenderTheme.female:
        return 'Fresh, calming and natural.';
      case GenderTheme.male:
        return 'Premium cream, gold & black.';
      case GenderTheme.other:
        return 'Vibrant, colorful and inclusive.';
    }
  }

  List<Color> get swatchColors {
    switch (this) {
      case GenderTheme.female:
        return [
          const Color(0xFF6FCF97),
          const Color(0xFF2D9248),
          Colors.white,
        ];
      case GenderTheme.male:
        return [
          const Color(0xFFC89B4F),   // gold
          const Color(0xFF111111),   // black
          const Color(0xFFF7F5F2),   // cream
        ];
      case GenderTheme.other:
        return [
          const Color(0xFFE53935),   // red
          const Color(0xFFFF9800),   // orange
          const Color(0xFF7B3FA0),   // purple
          const Color(0xFF0277BD),   // blue
        ];
    }
  }

  String get emoji {
    switch (this) {
      case GenderTheme.female:
        return '🌿';
      case GenderTheme.male:
        return '✨';
      case GenderTheme.other:
        return '🌈';
    }
  }
}
