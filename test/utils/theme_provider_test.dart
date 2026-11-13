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
    test('All 16 AppTheme enum values are defined and partitioned into 8 light and 8 dark', () {
      expect(AppTheme.values.length, 16);

      const lightThemes = [
        AppTheme.original,
        AppTheme.royalPurple,
        AppTheme.lipGloss,
        AppTheme.jadeEdge,
        AppTheme.lavenderHaze,
        AppTheme.goldenHour,
        AppTheme.ePluribus,
        AppTheme.lycheeLily,
      ];

      const darkThemes = [
        AppTheme.darkBlue,
        AppTheme.dark,
        AppTheme.electricAmber,
        AppTheme.cyberPunk,
        AppTheme.beyondDark,
        AppTheme.velvetDust,
        AppTheme.elGrito,
        AppTheme.yellowjacket,
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

      // CyberPunk, Electric Amber & Yellowjacket use dark text on bright/gold primary colors
      for (final theme in [
        AppTheme.cyberPunk,
        AppTheme.electricAmber,
        AppTheme.yellowjacket,
      ]) {
        provider.setTheme(theme);
        expect(provider.onPrimaryColor, const Color(0xDD000000));
        expect(provider.pillTextColor, const Color(0xDD000000));
        expect(provider.themeData.colorScheme.onPrimary, const Color(0xDD000000));
      }

      // All other 13 themes use white text on primary colors
      final whiteTextThemes = AppTheme.values.where(
        (t) =>
            t != AppTheme.cyberPunk &&
            t != AppTheme.electricAmber &&
            t != AppTheme.yellowjacket,
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
        expect(
          provider.themeData.chipTheme.checkmarkColor,
          provider.themeData.colorScheme.onPrimary,
          reason: '$theme chipTheme.checkmarkColor should match colorScheme.onPrimary',
        );

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

    test('secondaryColor matches colorScheme.secondary across all themes', () {
      final provider = ThemeProvider();

      for (final theme in AppTheme.values) {
        provider.setTheme(theme);
        expect(provider.secondaryColor, provider.themeData.colorScheme.secondary);
      }
    });

    test('El Grito and E Pluribus gradients follow correct tricolor flows', () {
      final provider = ThemeProvider();

      provider.setTheme(AppTheme.elGrito);
      final elGritoGradient = provider.appGradient;
      expect(elGritoGradient.colors.length, 3);
      expect(elGritoGradient.colors[0], const Color(0xFF1B553D)); // Agave emerald
      expect(elGritoGradient.colors[1], const Color(0xFFEDE8DD)); // Warm ivory
      expect(elGritoGradient.colors[2], const Color(0xFF9E2A38)); // Carmine red

      provider.setTheme(AppTheme.ePluribus);
      final ePluribusGradient = provider.appGradient;
      expect(ePluribusGradient.colors.length, 3);
      expect(ePluribusGradient.colors[0], const Color(0xFF9E2C38)); // Vintage crimson
      expect(ePluribusGradient.colors[1], const Color(0xFFEDF2F7)); // Parchment white
      expect(ePluribusGradient.colors[2], const Color(0xFF1E3A63)); // Constitutional navy
    });

    test('Royal is distinctly configured with Tyrian Imperial Purple and Antique Gold, differentiated from Lavender Haze', () {
      final provider = ThemeProvider();

      // Royal theme verification
      provider.setTheme(AppTheme.royalPurple);
      final royalGradient = provider.appGradient;
      expect(royalGradient.colors, const [Color(0xFF2E1065), Color(0xFF581C87)]);
      expect(provider.themeData.colorScheme.primary, const Color(0xFF2E1065));
      expect(provider.themeData.colorScheme.secondary, const Color(0xFFD4AF37));
      expect(provider.themeData.colorScheme.tertiary, const Color(0xFFF59E0B));
      expect(provider.themeData.colorScheme.secondaryContainer, const Color(0xFFFEF3C7));
      expect(provider.themeData.scaffoldBackgroundColor, const Color(0xFFFAF8F5));
      expect(provider.onPrimaryColor, Colors.white);
      expect(provider.pillTextColor, Colors.white);
      expect(provider.onGradientColor, Colors.white);

      // Verify clear differentiation from Lavender Haze
      provider.setTheme(AppTheme.lavenderHaze);
      expect(provider.themeData.colorScheme.primary, const Color(0xFF7B61FF));
      expect(provider.themeData.colorScheme.secondary, const Color(0xFF9D84FF));
      expect(provider.themeData.colorScheme.secondaryContainer, const Color(0xFFE6E6FA));
      expect(provider.themeData.scaffoldBackgroundColor, const Color(0xFFF5F3FA));
    });

    test('Lychee Lily is correctly configured with coral pink, peach, and soft lavender', () {
      final provider = ThemeProvider();

      provider.setTheme(AppTheme.lycheeLily);
      final gradient = provider.appGradient;
      expect(gradient.colors.length, 3);
      expect(gradient.colors[0], const Color(0xFFFF6584)); // Coral pink
      expect(gradient.colors[1], const Color(0xFFFFB094)); // Juicy peach
      expect(gradient.colors[2], const Color(0xFF9E86F0)); // Soft lilac / lavender
      expect(gradient.stops, const [0.0, 0.5, 1.0]);

      expect(provider.themeData.brightness, Brightness.light);
      expect(provider.themeData.colorScheme.primary, const Color(0xFF8F75E8)); // Royal lilac
      expect(provider.themeData.colorScheme.secondary, const Color(0xFFFF6584)); // Coral pink pop
      expect(provider.themeData.colorScheme.tertiary, const Color(0xFFFFB094)); // Warm peach
      expect(provider.themeData.colorScheme.secondaryContainer, const Color(0xFFFFE8E0));
      expect(provider.themeData.scaffoldBackgroundColor, const Color(0xFFFFF7F4));
      expect(provider.onPrimaryColor, Colors.white);
      expect(provider.pillTextColor, Colors.white);
      expect(provider.onGradientColor, Colors.white);
      expect(provider.chipUnselectedBackgroundColor, Colors.white);
      expect(provider.chipUnselectedTextColor, Colors.black87);
    });

    test('Yellowjacket is configured with pure black surfaces and deep wasp gold accents', () {
      final provider = ThemeProvider();

      provider.setTheme(AppTheme.yellowjacket);
      final gradient = provider.appGradient;
      expect(gradient.colors, const [
        Color(0xFF0A0A0B),
        Color(0xFF2B2100),
        Color(0xFF080809),
      ]);
      expect(gradient.stops, const [0.0, 0.5, 1.0]);

      expect(provider.themeData.brightness, Brightness.dark);
      expect(provider.themeData.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(provider.themeData.cardColor, const Color(0xFF111113));
      expect(provider.themeData.colorScheme.primary, const Color(0xFFEAB308));
      expect(provider.themeData.colorScheme.secondary, const Color(0xFFFACC15));
      expect(provider.themeData.colorScheme.tertiary, const Color(0xFFFDE047));
      expect(provider.themeData.colorScheme.secondaryContainer, const Color(0xFF2B2305));
      expect(provider.onPrimaryColor, const Color(0xDD000000));
      expect(provider.pillTextColor, const Color(0xDD000000));
      expect(provider.onGradientColor, Colors.white);
      expect(provider.chipUnselectedBackgroundColor, const Color(0xFF1C1C1F));
      expect(provider.chipUnselectedTextColor, Colors.white);
    });

    test('Electric Amber is configured with smoked bronze surfaces and electric tangerine accents distinct from Yellowjacket', () {
      final provider = ThemeProvider();

      provider.setTheme(AppTheme.electricAmber);
      final gradient = provider.appGradient;
      expect(gradient.colors, const [
        Color(0xFF1A0B02),
        Color(0xFF4A1E04),
        Color(0xFF120802),
      ]);
      expect(gradient.stops, const [0.0, 0.5, 1.0]);

      expect(provider.themeData.brightness, Brightness.dark);
      expect(provider.themeData.scaffoldBackgroundColor, const Color(0xFF140D07));
      expect(provider.themeData.cardColor, const Color(0xFF1F150D));
      expect(provider.themeData.colorScheme.primary, const Color(0xFFFF6D00));
      expect(provider.themeData.colorScheme.secondary, const Color(0xFFFF9100));
      expect(provider.themeData.colorScheme.tertiary, const Color(0xFFFF9E40));
      expect(provider.themeData.colorScheme.secondaryContainer, const Color(0xFF3D1E08));
      expect(provider.onPrimaryColor, const Color(0xDD000000));
      expect(provider.pillTextColor, const Color(0xDD000000));
      expect(provider.onGradientColor, Colors.white);
      expect(provider.chipUnselectedBackgroundColor, const Color(0xFF281B11));
      expect(provider.chipUnselectedTextColor, Colors.white);
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

      await provider.setTheme(AppTheme.lycheeLily);
      expect(provider.currentTheme, AppTheme.lycheeLily);
      expect(prefs.getInt('selected_theme'), AppTheme.lycheeLily.index);

      await provider.setTheme(AppTheme.yellowjacket);
      expect(provider.currentTheme, AppTheme.yellowjacket);
      expect(prefs.getInt('selected_theme'), AppTheme.yellowjacket.index);
    });
  });
}
