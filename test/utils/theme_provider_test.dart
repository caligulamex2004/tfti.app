import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tftiapp/utils/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider Tests', () {
    test('All 12 AppTheme enum values are defined and partitioned into 6 light and 6 dark', () {
      expect(AppTheme.values.length, 12);

      const lightThemes = [
        AppTheme.original,
        AppTheme.royalPurple,
        AppTheme.lipGloss,
        AppTheme.jadeEdge,
        AppTheme.lavenderHaze,
        AppTheme.goldenHour,
      ];

      const darkThemes = [
        AppTheme.darkBlue,
        AppTheme.dark,
        AppTheme.electricAmber,
        AppTheme.cyberPunk,
        AppTheme.beyondDark,
        AppTheme.velvetDust,
      ];

      final provider = ThemeProvider();

      for (final theme in lightThemes) {
        provider.setTheme(theme);
        expect(provider.currentTheme, theme);
        expect(provider.themeData.brightness, Brightness.light,
            reason: '$theme should be light');
      }

      for (final theme in darkThemes) {
        provider.setTheme(theme);
        expect(provider.currentTheme, theme);
        expect(provider.themeData.brightness, Brightness.dark,
            reason: '$theme should be dark');
      }
    });

    test('Each theme produces a valid LinearGradient with colors', () {
      final provider = ThemeProvider();

      for (final theme in AppTheme.values) {
        provider.setTheme(theme);
        final gradient = provider.appGradient;
        expect(gradient.colors.length, greaterThanOrEqualTo(2),
            reason: '$theme gradient must have at least 2 colors');
        expect(gradient.begin, Alignment.topLeft);
        expect(gradient.end, Alignment.bottomRight);
      }
    });

    test('onPrimaryColor and pillTextColor match colorScheme.onPrimary across all themes', () {
      final provider = ThemeProvider();

      // CyberPunk & Electric Amber use dark text on bright primary colors
      for (final theme in [AppTheme.cyberPunk, AppTheme.electricAmber]) {
        provider.setTheme(theme);
        expect(provider.onPrimaryColor, const Color(0xDD000000));
        expect(provider.pillTextColor, const Color(0xDD000000));
        expect(provider.themeData.colorScheme.onPrimary, const Color(0xDD000000));
      }

      // All other 10 themes use white text on primary colors
      final whiteTextThemes = AppTheme.values.where(
        (t) => t != AppTheme.cyberPunk && t != AppTheme.electricAmber,
      );
      for (final theme in whiteTextThemes) {
        provider.setTheme(theme);
        expect(provider.onPrimaryColor, Colors.white, reason: '$theme onPrimaryColor');
        expect(provider.pillTextColor, Colors.white, reason: '$theme pillTextColor');
        expect(provider.themeData.colorScheme.onPrimary, Colors.white,
            reason: '$theme colorScheme.onPrimary');
      }
    });

    test('Standardized pill, chip, and gradient tokens are defined for all themes', () {
      final provider = ThemeProvider();

      for (final theme in AppTheme.values) {
        provider.setTheme(theme);
        final isDark = provider.themeData.brightness == Brightness.dark;

        expect(provider.pillBackgroundColor, provider.themeData.colorScheme.primary);
        expect(provider.pillTextColor, provider.onPrimaryColor);

        if (isDark) {
          expect(provider.chipUnselectedTextColor, Colors.white);
          expect(provider.chipBorderColor, const Color(0xFF424242));
          expect(
            provider.chipUnselectedBackgroundColor,
            isNot(equals(const Color(0xFF000000))),
            reason: '$theme unselected chip background should stand out against pure black',
          );
        } else {
          expect(provider.chipUnselectedBackgroundColor, Colors.white);
          expect(provider.chipUnselectedTextColor, Colors.black87);
          expect(provider.chipBorderColor, const Color(0xFFE0E0E0));
        }

        if (theme == AppTheme.lipGloss) {
          expect(provider.onGradientColor, Colors.black87);
        } else {
          expect(provider.onGradientColor, Colors.white);
        }
      }
    });

    test('setTheme notifies listeners and persists index to SharedPreferences', () async {
      final provider = ThemeProvider();
      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setTheme(AppTheme.goldenHour);
      expect(notified, isTrue);
      expect(provider.currentTheme, AppTheme.goldenHour);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('selected_theme'), AppTheme.goldenHour.index);
    });
  });
}
