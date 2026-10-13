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

  // --- GRADIENTS ---
  LinearGradient get appGradient => switch (_currentTheme) {
    AppTheme.original => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1976D2), Color(0xFF81D4FA)],
    ),
    AppTheme.royalPurple => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
    ),
    AppTheme.lipGloss => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
    ),
    AppTheme.jadeEdge => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A4334), Color(0xFF2E8B6B)],
    ),
    AppTheme.lavenderHaze => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB39DDB), Color(0xFFE6E6FA)],
    ),
    AppTheme.goldenHour => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF7E5F), Color(0xFFFEB47B)],
    ),
    AppTheme.darkBlue => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    ),
    AppTheme.dark => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.black, Colors.black],
    ),
    AppTheme.electricAmber ||
    AppTheme.cyberPunk ||
    AppTheme.beyondDark => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2D2D2D), Color(0xFF000000)],
    ),
    AppTheme.velvetDust => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2A0845), Color(0xFF170B14)],
    ),
  };

  // Helper to dynamically set text color based on background luminance
  Color get onPrimaryColor {
    final primary = themeData.colorScheme.primary;
    return primary.computeLuminance() > 0.5
        ? const Color(0xDD000000)
        : Colors.white;
  }

  // --- THEME DATA HELPER ---
  ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackgroundColor,
    required Color cardColor,
    required ColorScheme colorScheme,
    double appBarElevation = 0,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        foregroundColor: Colors.white,
        elevation: appBarElevation,
        backgroundColor: Colors.transparent,
      ),
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: isDark
            ? Color.lerp(colorScheme.primary, Colors.white, 0.15)!.withValues(alpha: 0.35)
            : colorScheme.primary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? Colors.white : colorScheme.primary,
            );
          }
          return IconThemeData(
            color: isDark ? Colors.white60 : Colors.black54,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: isDark ? Colors.white60 : Colors.black87,
          );
        }),
      ),
    );
  }

  // --- THEME DATA ---
  ThemeData get themeData => switch (_currentTheme) {
    AppTheme.original => _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFE1F5FE),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.lightBlue,
        secondary: Colors.blueAccent,
        tertiary: Color(0xFF0288D1),
        secondaryContainer: Color(0xFFB3E5FC),
      ),
    ),
    AppTheme.royalPurple => _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      cardColor: Colors.white,
      appBarElevation: 4,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4A00E0),
        secondary: Color(0xFF8E2DE2),
        tertiary: Color(0xFFD500F9),
        secondaryContainer: Color(0xFFE1BEE7),
      ),
    ),
    AppTheme.lipGloss => _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFCE8EF),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFFF6B81),
        secondary: Color(0xFFFF9A9E),
        tertiary: Color(0xFFFF4081),
        secondaryContainer: Color(0xFFFFD1DC),
      ),
    ),
    AppTheme.jadeEdge => _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFE4F7EB),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1C8D6C),
        secondary: Color(0xFF2A594A),
        tertiary: Color(0xFF00BFA5),
        secondaryContainer: Color(0xFFB2DFDB),
      ),
    ),
    AppTheme.lavenderHaze => _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F3FA),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF7B61FF),
        secondary: Color(0xFF9D84FF),
        tertiary: Color(0xFFFFA8E2),
        secondaryContainer: Color(0xFFE6E6FA),
        surfaceTint: Color(0xFF7B61FF),
      ),
    ),
    AppTheme.goldenHour => _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFDF8F5),
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFFF7E5F),
        secondary: Color(0xFFFEB47B),
        tertiary: Color(0xFFFFB74D),
        secondaryContainer: Color(0xFFFFE0B2),
        surfaceTint: Color(0xFFFF7E5F),
      ),
    ),
    AppTheme.darkBlue => _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B1221),
      cardColor: const Color(0xFF15233D),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Colors.blueAccent,
        tertiary: Color(0xFF60A5FA),
        secondaryContainer: Color(0xFF1E3A8A),
      ),
    ),
    AppTheme.dark => _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF7637F3),
        secondary: Colors.grey,
        tertiary: Colors.white,
        secondaryContainer: Color(0xFF121212),
      ),
    ),
    AppTheme.electricAmber => _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFAB00),
        secondary: Colors.orangeAccent,
        tertiary: Color(0xFFFFD740),
        secondaryContainer: Color(0xFF4E342E),
      ),
    ),
    AppTheme.cyberPunk => _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5FF),
        secondary: Color(0xFFFF007F),
        tertiary: Color(0xFF76FF03),
        secondaryContainer: Color(0xFF004D40),
      ),
    ),
    AppTheme.beyondDark => _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      cardColor: const Color(0xFF111111),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFEE0909),
        secondary: Colors.grey,
        tertiary: Color(0xFFFF5252),
        secondaryContainer: Color(0xFF3E2723),
      ),
    ),
    AppTheme.velvetDust => _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF170B14),
      cardColor: const Color(0xFF24111E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF2A7A),
        secondary: Color(0xFFB48EAD),
        tertiary: Color(0xFFFF8AAE),
        secondaryContainer: Color(0xFF4A233C),
        surfaceTint: Color(0xFFFF2A7A),
      ),
    ),
  };

  // --- LOGIC WITH ERROR HANDLING ---
  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themePrefKey, theme.index);
    } catch (e) {
      debugPrint("Failed to save theme to SharedPreferences: $e");
    }
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? savedThemeIndex = prefs.getInt(_themePrefKey);

      if (savedThemeIndex != null &&
          savedThemeIndex >= 0 &&
          savedThemeIndex < AppTheme.values.length) {
        _currentTheme = AppTheme.values[savedThemeIndex];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to load theme from SharedPreferences: $e");
    }
  }
}

// Global instance
final themeProvider = ThemeProvider();
