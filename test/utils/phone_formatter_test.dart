import 'package:flutter_test/flutter_test.dart';
import 'package:tftiapp/utils/phone_formatter.dart';

void main() {
  group('PhoneFormatter Tests', () {
    test('Formats US/Canada 10-digit numbers into standard local format', () {
      expect(PhoneFormatter.beautify('+14205556969'), '(420) 555-6969');
      expect(PhoneFormatter.beautify('+12125550199'), '(212) 555-0199');
      expect(PhoneFormatter.beautify('+18005551234'), '(800) 555-1234');
    });

    test('Formats international numbers by separating country code with a space', () {
      expect(PhoneFormatter.beautify('+447911123456'), '+44 7911123456');
      expect(PhoneFormatter.beautify('+33612345678'), '+33 612345678');
      expect(PhoneFormatter.beautify('+5215512345678'), '+52 15512345678');
    });

    test('Handles null, empty, or whitespace-only strings gracefully', () {
      expect(PhoneFormatter.beautify(null), '');
      expect(PhoneFormatter.beautify(''), '');
    });

    test('Handles short or unusual numbers without throwing exceptions', () {
      // 3 characters or less with +
      expect(PhoneFormatter.beautify('+1'), '+1');
      expect(PhoneFormatter.beautify('+44'), '+44');

      // Numbers without + prefix
      expect(PhoneFormatter.beautify('14205556969'), '14205556969');
      expect(PhoneFormatter.beautify('555-1234'), '555-1234');

      // + with length > 3 formats with space after 3 characters
      expect(PhoneFormatter.beautify('+155512345'), '+15 5512345');
      expect(PhoneFormatter.beautify('+155512345678'), '+15 5512345678');
    });
  });
}
