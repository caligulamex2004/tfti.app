import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/services/contact_service.dart';
import 'package:tftiapp/services/contact_resolver.dart';

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

    test(
      'pickPhone skips null and empty/whitespace strings instead of clobbering valid fallback phone numbers',
      () {
        expect(
          ContactHelper.pickPhone([null, '', '   ', '+15551234567']),
          '+15551234567',
        );
        expect(
          ContactHelper.pickPhone(['', null, '   ']),
          '',
        );
      },
    );
  });

  group('ContactResolver Tests', () {
    test('resolveName returns null for empty or null inputs', () {
      expect(ContactResolver.instance.resolveName(null), isNull);
      expect(ContactResolver.instance.resolveName(''), isNull);
      expect(ContactResolver.instance.resolveName('   '), isNull);
    });

    test('resolveName returns null for unknown phone numbers', () {
      expect(ContactResolver.instance.resolveName('+19999999999'), isNull);
      expect(ContactResolver.instance.resolveName('999-999-9999'), isNull);
    });

    test('ContactHelper.extractFirstName handles single, multi-word, comma-separated, and empty names', () {
      expect(ContactHelper.extractFirstName(null), equals(''));
      expect(ContactHelper.extractFirstName(''), equals(''));
      expect(ContactHelper.extractFirstName('   '), equals(''));
      expect(ContactHelper.extractFirstName('Adam'), equals('Adam'));
      expect(ContactHelper.extractFirstName('Adam Smith'), equals('Adam'));
      expect(ContactHelper.extractFirstName('Mary Jane Watson'), equals('Mary'));
      expect(ContactHelper.extractFirstName('Smith, John'), equals('John'));
      expect(ContactHelper.extractFirstName('Watson, Mary Jane'), equals('Mary'));
      expect(ContactHelper.extractFirstName('Solo,'), equals('Solo'));
    });

    test('resolveFirstName returns contact first name or fallback', () {
      ContactResolver.instance.clearForTest();
      ContactResolver.instance.seedForTest({
        '+15551112222': 'Alexander Hamilton',
        '+15553334444': 'Elizabeth Schuyler',
      });

      // Matches local contact
      expect(
        ContactResolver.instance.resolveFirstName('+15551112222'),
        equals('Alexander'),
      );
      expect(
        ContactResolver.instance.resolveFirstName('555-333-4444'),
        equals('Elizabeth'),
      );

      // Unknown phone falls back to fallbackName
      expect(
        ContactResolver.instance.resolveFirstName(
          '+15559990000',
          fallbackName: 'Aaron Burr',
        ),
        equals('Aaron'),
      );

      // Unknown phone with no fallback returns null
      expect(
        ContactResolver.instance.resolveFirstName('+15559990000'),
        isNull,
      );

      // Null phone with fallback returns fallback first name
      expect(
        ContactResolver.instance.resolveFirstName(
          null,
          fallbackName: 'Thomas Jefferson',
        ),
        equals('Thomas'),
      );

      ContactResolver.instance.clearForTest();
    });

    test('cache property is unmodifiable', () {
      final cache = ContactResolver.instance.cache;
      expect(() => cache['+15551234567'] = 'Test', throwsUnsupportedError);
    });

    test('ignores current user phone number from resolving to contact name', () {
      ContactResolver.instance.clearForTest();
      ContactResolver.instance.setCurrentUserPhone('+15550001111');

      ContactResolver.instance.seedForTest({
        '+15550001111': 'User A', // Current user's phone saved under User A
        '+15552223333': 'Bob Friend',
      }, currentUserPhone: '+15550001111');

      // The user's own phone number must return null
      expect(ContactResolver.instance.resolveName('+15550001111'), isNull);
      expect(ContactResolver.instance.resolveName('555-000-1111'), isNull);

      // Other contacts must resolve normally
      expect(ContactResolver.instance.resolveName('+15552223333'), 'Bob Friend');
      expect(ContactResolver.instance.resolveName('555-222-3333'), 'Bob Friend');

      // Cleanup
      ContactResolver.instance.clearForTest();
    });
  });
}
