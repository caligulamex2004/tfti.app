import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/components/dialogs/mobile_waitlist_dialog.dart';
import 'package:tftiapp/services/waitlist_service.dart';

class MockWaitlistService extends WaitlistService {
  String? submittedEmail;
  String? submittedPlatform;
  String? submittedSource;
  bool shouldThrow = false;

  @override
  Future<void> joinWaitlist({
    required String email,
    String platform = 'both',
    String source = 'web_login',
  }) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    submittedEmail = email;
    submittedPlatform = platform;
    submittedSource = source;
  }
}

void main() {
  group('MobileWaitlistDialog Tests', () {
    testWidgets('renders initial platform and form elements correctly', (tester) async {
      final mockService = MockWaitlistService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileWaitlistDialog(
              initialPlatform: 'ios',
              waitlistService: mockService,
            ),
          ),
        ),
      );

      expect(find.text('Mobile App Waitlist'), findsOneWidget);
      expect(find.text('iOS'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.text('Notify Me at Launch'), findsOneWidget);
    });

    testWidgets('shows validation error when email is empty on submit', (tester) async {
      final mockService = MockWaitlistService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileWaitlistDialog(
              waitlistService: mockService,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Notify Me at Launch'));
      await tester.pump();

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(mockService.submittedEmail, isNull);
    });

    testWidgets('shows validation error when email is invalid', (tester) async {
      final mockService = MockWaitlistService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileWaitlistDialog(
              waitlistService: mockService,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Notify Me at Launch'));
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(mockService.submittedEmail, isNull);
    });

    testWidgets('successfully submits valid email and transitions to success view', (tester) async {
      final mockService = MockWaitlistService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileWaitlistDialog(
              initialPlatform: 'android',
              waitlistService: mockService,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'tester@example.com');
      await tester.tap(find.text('Notify Me at Launch'));
      await tester.pumpAndSettle();

      expect(mockService.submittedEmail, 'tester@example.com');
      expect(mockService.submittedPlatform, 'android');
      expect(find.textContaining("You're on the list!"), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows error message if service throws an error', (tester) async {
      final mockService = MockWaitlistService()..shouldThrow = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileWaitlistDialog(
              waitlistService: mockService,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'tester@example.com');
      await tester.tap(find.text('Notify Me at Launch'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.text("You're on the list!"), findsNothing);
    });
  });
}
