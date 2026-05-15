import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Global theme manager. Access via ThemeManager.instance.
///
/// The active theme is derived from the user's gender but can also be
/// manually overridden in Settings. Persisted across restarts with
/// SharedPreferences.
class ThemeManager extends ChangeNotifier {
  ThemeManager._();
  static final ThemeManager instance = ThemeManager._();

  static const _kKey = 'gender_theme';

  GenderTheme _current = GenderTheme.female;

  GenderTheme get current => _current;

  // All three themes are light — kept for future-proofing.
  bool get isDark => themeData.brightness == Brightness.dark;

  Color get primaryColor {
    switch (_current) {
      case GenderTheme.male:
        return const Color(0xFFC89B4F);
      case GenderTheme.other:
        return const Color(0xFF7B3FA0);
      case GenderTheme.female:
        return const Color(0xFF6FCF97);
    }
  }

  ThemeData get themeData => AppTheme.of(_current);

  // ── Set from gender string (called after login) ───────────────────────────

  Future<void> setThemeFromGender(String? gender) async {
    final g = gender?.toLowerCase().trim() ?? '';
    GenderTheme next;
    if (g == 'male' || g == 'm') {
      next = GenderTheme.male;
    } else if (g == 'female' || g == 'f') {
      next = GenderTheme.female;
    } else if (g.isNotEmpty) {
      next = GenderTheme.other;
    } else {
      return; // gender unknown — keep current theme
    }
    await _apply(next);
  }

  // ── Manual override (Settings page) ──────────────────────────────────────

  Future<void> setTheme(GenderTheme theme) => _apply(theme);

  // ── Persist / restore ─────────────────────────────────────────────────────

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey);
    _current = _fromString(saved);
    // No notifyListeners() here — called before first build, so the first
    // build already gets the correct theme via themeData.
  }

  Future<void> _apply(GenderTheme theme) async {
    if (_current == theme) return;
    _current = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, theme.name);
  }

  static GenderTheme _fromString(String? s) {
    switch (s) {
      case 'male':
        return GenderTheme.male;
      case 'other':
        return GenderTheme.other;
      default:
        return GenderTheme.female;
    }
  }
}
