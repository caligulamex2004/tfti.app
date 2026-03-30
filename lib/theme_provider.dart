import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  // 6 Light Themes
  original,
  royalPurple,
  lipGloss,
  jadeEdge,
  lavenderHaze,
  goldenHour,

  // 6 Dark Themes
  darkBlue,
  dark,
  electricAmber,
  cyberPunk,
  beyondDark,
  velvetDust,
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
      // Light Gradients
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
      case AppTheme.lavenderHaze:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB39DDB), Color(0xFFE6E6FA)],
        );
      case AppTheme.goldenHour:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
        );

      // Dark Gradients
      case AppTheme.darkBlue:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        );
      case AppTheme.dark:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, Colors.black],
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
      case AppTheme.velvetDust:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A0845), Color(0xFF170B14)],
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
      // ---------------------------------------------------------
      // LIGHT THEMES (6)
      // ---------------------------------------------------------
      case AppTheme.original:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE1F5FE),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Colors.lightBlue,
            secondary: Colors.blueAccent,
            tertiary: Color(0xFF0288D1),
            secondaryContainer: Color(0xFFB3E5FC), // Pill Color
          ),
          useMaterial3: true,
        );

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
            tertiary: Color(0xFFD500F9),
            secondaryContainer: Color(0xFFE1BEE7), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.lipGloss:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFCE8EF),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF6B81),
            secondary: Color(0xFFFF9A9E),
            tertiary: Color(0xFFFF4081),
            secondaryContainer: Color(0xFFFFD1DC), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.jadeEdge:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE4F7EB),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1C8D6C),
            secondary: Color(0xFF2A594A),
            tertiary: Color(0xFF00BFA5),
            secondaryContainer: Color(0xFFB2DFDB), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.lavenderHaze:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF5F3FA),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7B61FF),
            secondary: Color(0xFF9D84FF),
            tertiary: Color(0xFFFFA8E2), // Soft pink accent
            secondaryContainer: Color(0xFFE6E6FA), // Pill Color
            surfaceTint: Color(0xFF7B61FF),
          ),
          useMaterial3: true,
        );

      case AppTheme.goldenHour:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFDF8F5),
          cardColor: Colors.white,
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF7E5F),
            secondary: Color(0xFFFEB47B),
            tertiary: Color(0xFFFFB74D),
            secondaryContainer: Color(0xFFFFE0B2), // Pill Color
            surfaceTint: Color(0xFFFF7E5F),
          ),
          useMaterial3: true,
        );

      // ---------------------------------------------------------
      // DARK THEMES (6)
      // ---------------------------------------------------------
      case AppTheme.darkBlue:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0B1221),
          cardColor: const Color(0xFF15233D),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            secondary: Colors.blueAccent,
            tertiary: Color(0xFF60A5FA),
            secondaryContainer: Color(0xFF1E3A8A), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.dark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF000000), // Pure black card
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF5500FF),
            secondary: Colors.grey,
            tertiary: Colors.white,
            secondaryContainer: Color(0xFF000000), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.electricAmber:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFAB00),
            secondary: Colors.orangeAccent,
            tertiary: Color(0xFFFFD740),
            secondaryContainer: Color(0xFF4E342E), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.cyberPunk:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            secondary: Color(0xFFFF007F), // Neon Pink Secondary
            tertiary: Color(0xFF76FF03), // Neon Green Accent
            secondaryContainer: Color(0xFF004D40), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.beyondDark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000),
          cardColor: const Color(0xFF111111),
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFEE0909),
            secondary: Colors.grey,
            tertiary: Color(0xFFFF5252),
            secondaryContainer: Color(0xFF3E2723), // Pill Color
          ),
          useMaterial3: true,
        );

      case AppTheme.velvetDust:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF170B14), // Deep warm plum
          cardColor: const Color(0xFF24111E), // Slightly lighter plum card
          appBarTheme: const AppBarTheme(foregroundColor: Colors.white),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF2A7A), // Neon Rose
            secondary: Color(0xFFB48EAD), // Dusty purple
            tertiary: Color(0xFFFF8AAE), // Soft pink accent
            secondaryContainer: Color(
              0xFF4A233C,
            ), // Beautiful tinted pill background
            surfaceTint: Color(0xFFFF2A7A), // Gives cards a faint pink glow
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
