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

    test('onPrimaryColor computes high-contrast text color based on primary luminance', () {
      final provider = ThemeProvider();

      // CyberPunk has bright cyan (#00E5FF) -> luminance > 0.5 -> dark text
      provider.setTheme(AppTheme.cyberPunk);
      expect(provider.themeData.colorScheme.primary.computeLuminance(), greaterThan(0.5));
      expect(provider.onPrimaryColor, const Color(0xDD000000));

      // Royal Purple has dark purple (#4A00E0) -> luminance < 0.5 -> white text
      provider.setTheme(AppTheme.royalPurple);
      expect(provider.themeData.colorScheme.primary.computeLuminance(), lessThan(0.5));
      expect(provider.onPrimaryColor, Colors.white);
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
