import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tftiapp/components/shared/tcg_profile_card.dart';
import 'package:tftiapp/components/shared/user_profile_sheet.dart';
import 'package:tftiapp/services/contact_resolver.dart';
import 'package:tftiapp/services/contact_service.dart';

void main() {
  group('TcgProfileCard Tests', () {
    testWidgets('renders monogram when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'Gamer One',
                username: 'gamer1',
                statusText: 'Ready to play',
                hp: 150,
                mana: 80,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarColor: Colors.deepPurple,
              ),
            ),
          ),
        ),
      );

      expect(find.text('G'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('renders loading spinner when isUploadingAvatar is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'Gamer One',
                username: 'gamer1',
                statusText: 'Ready to play',
                hp: 150,
                mana: 80,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarColor: Colors.deepPurple,
                isUploadingAvatar: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('G'), findsNothing);
    });

    testWidgets('builds CachedNetworkImage on mobile without superimposing monogram on loaded image', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'Hero Zara',
                username: 'zara_hero',
                statusText: 'Questing',
                hp: 200,
                mana: 100,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarUrl: 'https://example.com/avatar.jpg',
                avatarColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      final cachedImageFinder = find.byType(CachedNetworkImage);
      expect(cachedImageFinder, findsOneWidget);

      final cachedImage = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImage.imageUrl, 'https://example.com/avatar.jpg');
      expect(cachedImage.fit, BoxFit.cover);

      // Verify placeholder renders the monogram
      final context = tester.element(cachedImageFinder);
      final placeholder = cachedImage.placeholder!(context, 'https://example.com/avatar.jpg');
      expect(placeholder, isA<Center>());
    });

    testWidgets('triggers onAvatarTap when avatar is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'Hero Zara',
                username: 'zara_hero',
                statusText: 'Questing',
                hp: 200,
                mana: 100,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarColor: Colors.blue,
                onAvatarTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      // Tap camera icon or avatar container
      await tester.tap(find.byIcon(Icons.camera_alt));
      expect(tapped, isTrue);
    });

    testWidgets('renders VIP star icon when isGoated is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'Hero VIP',
                username: 'vip_hero',
                statusText: 'VIP Member',
                hp: 200,
                mana: 100,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarColor: Colors.blue,
                isGoated: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Symbols.star), findsOneWidget);
    });

    testWidgets('renders contactName when isSelf is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'User C',
                username: 'user_c',
                statusText: 'Chilling',
                hp: 100,
                mana: 50,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarColor: Colors.blue,
                contactName: 'User A',
                isSelf: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('User A'), findsOneWidget);
      expect(find.textContaining('User C'), findsOneWidget);
      expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
    });

    testWidgets('ignores contactName and shows displayName when isSelf is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TcgProfileCard(
                displayName: 'User C',
                username: 'user_c',
                statusText: 'Chilling',
                hp: 100,
                mana: 50,
                originDate: 'Joined Oct 2026',
                showPhone: false,
                displayPhone: '',
                avatarColor: Colors.blue,
                contactName: 'User A',
                isSelf: true,
              ),
            ),
          ),
        ),
      );

      // Should display User C in the title RichText and not display User A or the contacts icon
      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('User C'),
      );
      expect(richTextFinder, findsOneWidget);
      expect(find.text('User A'), findsNothing);
      expect(find.byIcon(Icons.contact_phone_outlined), findsNothing);
    });

    testWidgets(
      'isSelf: true (AccountPage Profile Preview) never alters displayName regardless of fullProfileFormat',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        ContactResolver.instance.clearForTest();
        await ContactResolver.instance.setFullProfileFormat(
          DisplayNameFormat.firstName,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TcgProfileCard(
                  displayName: 'Alex Michael Sanchez',
                  username: 'alex_s',
                  statusText: 'Building',
                  hp: 100,
                  mana: 50,
                  originDate: 'Joined Oct 2026',
                  showPhone: false,
                  displayPhone: '',
                  avatarColor: Colors.blue,
                  isSelf: true,
                ),
              ),
            ),
          ),
        );

        final richTextFinder = find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Alex Michael Sanchez'),
        );
        expect(richTextFinder, findsOneWidget);
        ContactResolver.instance.clearForTest();
      },
    );

    testWidgets(
      'UserProfileSheet applies fullProfileFormat to other users and updates reactively',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        ContactResolver.instance.clearForTest();
        ContactResolver.instance.seedForTest({
          '+15551112222': 'Robert Michael Yen',
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserProfileSheet(
                userData: const {
                  'uid': 'user-2',
                  'displayName': 'BobbyY',
                  'username': 'bobby_y',
                  'phoneNumber': '+15551112222',
                },
                currentUserId: 'user-1',
              ),
            ),
          ),
        );

        // Default fullProfileFormat is fullName
        expect(find.text('Robert Michael Yen'), findsOneWidget);
        expect(find.text('~ BobbyY (@bobby_y)'), findsOneWidget);

        // Switch to First Name Last Initial
        await ContactResolver.instance.setFullProfileFormat(
          DisplayNameFormat.firstNameLastInitial,
        );
        await tester.pump();
        expect(find.text('Robert Y.'), findsOneWidget);

        // Switch to Given Name (First + Middle)
        await ContactResolver.instance.setFullProfileFormat(
          DisplayNameFormat.givenName,
        );
        await tester.pump();
        expect(find.text('Robert Michael'), findsOneWidget);

        ContactResolver.instance.clearForTest();
      },
    );
  });
}
