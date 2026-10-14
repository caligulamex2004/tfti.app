import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/services/contact_service.dart';

void main() {
  group('ContactHelper Tests', () {
    test(
      'normalizePhone normalizes 10-digit US phone numbers with various formats',
      () {
        expect(ContactHelper.normalizePhone('(555) 123-4567'), '+15551234567');
        expect(ContactHelper.normalizePhone('555-123-4567'), '+15551234567');
        expect(ContactHelper.normalizePhone('555.123.4567'), '+15551234567');
        expect(ContactHelper.normalizePhone('5551234567'), '+15551234567');
      },
    );

    test(
      'normalizePhone normalizes 11-digit US phone numbers with country code',
      () {
        expect(
          ContactHelper.normalizePhone('1 (555) 123-4567'),
          '+15551234567',
        );
        expect(ContactHelper.normalizePhone('+1 555 123 4567'), '+15551234567');
        expect(ContactHelper.normalizePhone('15551234567'), '+15551234567');
      },
    );

    test(
      'normalizePhone preserves international phone numbers greater than 10 digits',
      () {
        expect(
          ContactHelper.normalizePhone('+44 7911 123456'),
          '+447911123456',
        );
        expect(
          ContactHelper.normalizePhone('+33 6 12 34 56 78'),
          '+33612345678',
        );
        expect(
          ContactHelper.normalizePhone('+52 1 55 1234 5678'),
          '+5215512345678',
        );
      },
    );

    test(
      'normalizePhone returns null for invalid, incomplete, or empty inputs',
      () {
        expect(ContactHelper.normalizePhone(''), isNull);
        expect(ContactHelper.normalizePhone('   '), isNull);
        expect(ContactHelper.normalizePhone('123'), isNull);
        expect(ContactHelper.normalizePhone('555-123'), isNull);
        expect(ContactHelper.normalizePhone('no-digits-here'), isNull);
      },
    );

    test(
      'getContacts safely returns null in headless/unsupported environments without crashing',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final contacts = await ContactHelper.getContacts();
        expect(contacts, isNull);
      },
    );
  });
}
