import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  original,
  royalPurple,
  darkBlue,
  dark,
  lipGloss,
  jadeEdge,
  electricAmber,
  cyberPunk,
  beyondDark,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'selected_theme';

  AppTheme _currentTheme = AppTheme.original;
  AppTheme get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  LinearGradient get appGradient {
    switch (_currentTheme) {
      case AppTheme.original:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF81D4FA)],
        );
      case AppTheme.royalPurple:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
        );
      case AppTheme.darkBlue:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        );
      case AppTheme.dark:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, Colors.black],
        );
      case AppTheme.lipGloss:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
        );
      case AppTheme.jadeEdge:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A4334), Color(0xFF2E8B6B)],
        );
      case AppTheme.electricAmber:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2D2D), Color(0xFF000000)],
        );
      case AppTheme.cyberPunk:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2D2D), Color(0xFF000000)],
        );
      case AppTheme.beyondDark:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2D2D), Color(0xFF000000)],
        );
    }
  }

  Color get onPrimaryColor {
    final primary = themeData.colorScheme.primary;
    return primary.computeLuminance() > 0.5
        ? const Color(0xDD000000)
        : Colors.white;
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      // --- Original Theme ---
      case AppTheme.original:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE1F5FE),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Colors.lightBlue,
            secondary: Colors.blueAccent,
          ),
          useMaterial3: true,
        );

      // --- Royal Purple Theme ---
      case AppTheme.royalPurple:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF0F2F5),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4A00E0),
            secondary: Color(0xFF8E2DE2),
          ),
          useMaterial3: true,
        );

      // --- Dark Blue Theme ---
      case AppTheme.darkBlue:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0B1221),
          cardColor: const Color(0xFF15233D),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            secondary: Colors.blueAccent,
          ),
          useMaterial3: true,
        );

      // --- True Dark Theme ---
      case AppTheme.dark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000),
          cardColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4A00E0),
            secondary: Colors.grey,
          ),
          useMaterial3: true,
        );

      // --- Lip Gloss Theme ---
      case AppTheme.lipGloss:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFCE8EF),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF6B81),
            secondary: Color(0xFFFF9A9E),
          ),
          useMaterial3: true,
        );

      // --- Jade Edge Theme ---
      case AppTheme.jadeEdge:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE4F7EB),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1C8D6C),
            secondary: Color(0xFF2A594A),
          ),
          useMaterial3: true,
        );

      // --- Electric Amber Theme ---
      case AppTheme.electricAmber:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFAB00),
            secondary: Colors.orangeAccent,
          ),
          useMaterial3: true,
        );

      // --- Cyber Punk Theme ---
      case AppTheme.cyberPunk:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            secondary: Colors.grey,
          ),
          useMaterial3: true,
        );

      // --- Beyond Dark Theme ---
      case AppTheme.beyondDark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFEE0909),
            secondary: Colors.grey,
          ),
          useMaterial3: true,
        );
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, theme.index);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeIndex = prefs.getInt(_themePrefKey);
    if (savedThemeIndex != null) {
      _currentTheme = AppTheme.values[savedThemeIndex];
      notifyListeners();
    }
  }
}

final themeProvider = ThemeProvider();
