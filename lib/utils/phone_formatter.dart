class PhoneFormatter {
  /// Takes a raw database phone string (e.g. +14205556969) and returns a
  /// beautifully formatted UI string (e.g. (420) 555-6969).
  static String beautify(String rawPhone) {
    if (rawPhone.isEmpty) return rawPhone;

    // Check if it is a standard US/Canada 10-digit number
    if (rawPhone.startsWith('+1') && rawPhone.length == 12) {
      final areaCode = rawPhone.substring(2, 5);
      final prefix = rawPhone.substring(5, 8);
      final line = rawPhone.substring(8, 12);
      // Drops the +1 for a clean local look
      return "($areaCode) $prefix-$line";
    }

    // For other international numbers, separate the country code with a space for readability
    if (rawPhone.startsWith('+')) {
      // Rough formatting: Just add a space after the likely country code
      // (assuming standard +XX lengths) to make it easier to read.
      if (rawPhone.length > 3) {
        return "${rawPhone.substring(0, 3)} ${rawPhone.substring(3)}";
      }
    }

    // Fallback
    return rawPhone;
  }
}
