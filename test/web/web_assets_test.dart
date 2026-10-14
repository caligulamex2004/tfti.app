import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Assets & App Store Compliance Tests', () {
    test(
      'web/manifest.json exists, is valid JSON, and contains TFTI branding',
      () {
        final manifestFile = File('web/manifest.json');
        expect(
          manifestFile.existsSync(),
          isTrue,
          reason: 'web/manifest.json must exist',
        );

        final content = manifestFile.readAsStringSync();
        final Map<String, dynamic> json = jsonDecode(content);

        expect(json['name'], contains('TFTI'));
        expect(json['short_name'], 'TFTI');
        expect(json['theme_color'], '#1D73CB');
        expect(json['background_color'], '#1D73CB');

        final List<dynamic> icons = json['icons'];
        expect(icons, isNotEmpty);
        final iconSrcs = icons.map((e) => e['src']).toList();
        expect(iconSrcs, contains('icons/Icon-192.png'));
        expect(iconSrcs, contains('icons/Icon-512.png'));
      },
    );

    test(
      'web/index.html contains social preview metadata and favicon links',
      () {
        final indexFile = File('web/index.html');
        expect(
          indexFile.existsSync(),
          isTrue,
          reason: 'web/index.html must exist',
        );

        final html = indexFile.readAsStringSync();

        expect(html, contains('<title>TFTI — Thanks For The Invite</title>'));
        expect(html, contains('og:title'));
        expect(html, contains('og:image'));
        expect(html, contains('og:url'));
        expect(html, contains('twitter:card'));
        expect(html, contains('favicon.png'));
        expect(html, contains('favicon.ico'));
      },
    );

    test('web/privacy.html exists and meets store policy requirements', () {
      final file = File('web/privacy.html');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Privacy Policy page must exist',
      );

      final html = file.readAsStringSync();
      expect(html.length, greaterThan(1000));
      expect(html, contains('Privacy Policy'));
      expect(html, contains('Information We Collect'));
      expect(html, contains('Account Deletion'));
      expect(html, contains('/terms'));
      expect(html, contains('/support'));
    });

    test('web/terms.html exists and defines terms of service', () {
      final file = File('web/terms.html');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Terms of Service page must exist',
      );

      final html = file.readAsStringSync();
      expect(html.length, greaterThan(1000));
      expect(html, contains('Terms of Service'));
      expect(html, contains('User Conduct'));
      expect(html, contains('/privacy'));
    });

    test('web/support.html exists and provides help resources', () {
      final file = File('web/support.html');
      expect(file.existsSync(), isTrue, reason: 'Support page must exist');

      final html = file.readAsStringSync();
      expect(html.length, greaterThan(500));
      expect(html, contains('Support & Help'));
      expect(html, contains('Frequently Asked Questions'));
      expect(html, contains('support@tfti.app'));
    });

    test(
      'web/delete-account.html exists and meets Apple App Store Guideline 5.1.1(v)',
      () {
        final file = File('web/delete-account.html');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Account deletion page must exist',
        );

        final html = file.readAsStringSync();
        expect(html.length, greaterThan(1000));
        expect(html, contains('Delete Account'));
        expect(html, contains('Method 1: Delete Directly in the App'));
        expect(html, contains('support@tfti.app'));
      },
    );

    test('Favicon and icon image files exist and are non-empty', () {
      final faviconPng = File('web/favicon.png');
      expect(faviconPng.existsSync(), isTrue);
      expect(faviconPng.lengthSync(), greaterThan(100));

      final faviconIco = File('web/favicon.ico');
      expect(faviconIco.existsSync(), isTrue);
      expect(faviconIco.lengthSync(), greaterThan(100));

      final icon192 = File('web/icons/Icon-192.png');
      expect(icon192.existsSync(), isTrue);
      expect(icon192.lengthSync(), greaterThan(500));

      final icon512 = File('web/icons/Icon-512.png');
      expect(icon512.existsSync(), isTrue);
      expect(icon512.lengthSync(), greaterThan(1000));
    });

    test(
      'cors.json exists, is valid JSON, and configures Firebase Storage CORS headers',
      () {
        final corsFile = File('cors.json');
        expect(
          corsFile.existsSync(),
          isTrue,
          reason: 'cors.json must exist for Firebase Storage web access',
        );

        final content = corsFile.readAsStringSync();
        final List<dynamic> json = jsonDecode(content);
        expect(json, isNotEmpty);

        final entry = json.first as Map<String, dynamic>;
        expect(entry['origin'], contains('*'));
        expect(entry['method'], containsAll(['GET', 'HEAD']));
        expect(entry['responseHeader'], contains('*'));
        expect(entry['maxAgeSeconds'], equals(3600));
      },
    );

    test(
      'firebase.json exists, is valid JSON, and configures Hosting, Firestore, and Platforms',
      () {
        final file = File('firebase.json');
        expect(file.existsSync(), isTrue, reason: 'firebase.json must exist');

        final content = file.readAsStringSync();
        final Map<String, dynamic> json = jsonDecode(content);

        expect(json['firestore'], isNotNull);
        expect(json['firestore']['rules'], equals('firestore.rules'));

        expect(json['hosting'], isNotNull);
        final hosting = json['hosting'] as Map<String, dynamic>;
        expect(hosting['public'], equals('build/web'));
        expect(hosting['cleanUrls'], isTrue);
        expect(hosting['rewrites'], isNotEmpty);

        expect(json['flutter'], isNotNull);
        expect(json['flutter']['platforms'], contains('android'));
        expect(json['flutter']['platforms'], contains('ios'));
        expect(json['flutter']['platforms'], contains('dart'));
      },
    );
  });
}
