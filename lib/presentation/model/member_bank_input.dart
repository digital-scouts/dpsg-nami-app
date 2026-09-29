/// Eingabehilfen fuer die Bankverbindung einer Person.
///
/// Hitobito (hitobito_pfadi_de) prueft die IBAN serverseitig, erlaubt sie
/// aber leer. Die Zahlart ist dort Pflicht und auf [paymentMethods] begrenzt.
class MemberBankInput {
  const MemberBankInput._();

  static const String paymentMethodInvoice = 'invoice';
  static const String paymentMethodDebit = 'debit';
  static const List<String> paymentMethods = <String>[
    paymentMethodInvoice,
    paymentMethodDebit,
  ];

  /// Laengen der IBAN je Land fuer die im DPSG-Umfeld ueblichen Laender.
  /// Fuer andere Laender gilt nur der allgemeine Rahmen von 15 bis 34 Zeichen.
  static const Map<String, int> _ibanLengthByCountry = <String, int>{
    'AT': 20,
    'BE': 16,
    'CH': 21,
    'CZ': 24,
    'DE': 22,
    'DK': 18,
    'ES': 24,
    'FR': 27,
    'IT': 27,
    'LI': 21,
    'LU': 20,
    'NL': 18,
    'PL': 28,
  };

  static String? normalizeIban(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.toUpperCase();
  }

  static String? normalizeBic(String? value) {
    final normalized = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    return normalized.toUpperCase();
  }

  /// Liefert `true`, wenn [value] leer oder eine formal gueltige IBAN ist.
  static bool isValidIban(String? value) {
    final iban = normalizeIban(value);
    if (iban == null) {
      return true;
    }
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$').hasMatch(iban)) {
      return false;
    }
    final expectedLength = _ibanLengthByCountry[iban.substring(0, 2)];
    if (expectedLength != null && iban.length != expectedLength) {
      return false;
    }
    return _mod97(iban.substring(4) + iban.substring(0, 4)) == 1;
  }

  /// Liefert `true`, wenn [value] leer oder eine formal gueltige BIC ist.
  static bool isValidBic(String? value) {
    final bic = normalizeBic(value);
    if (bic == null) {
      return true;
    }
    return RegExp(r'^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$').hasMatch(bic);
  }

  static int _mod97(String rearranged) {
    var remainder = 0;
    for (final codeUnit in rearranged.codeUnits) {
      final digits = codeUnit >= 65
          ? (codeUnit - 55).toString()
          : String.fromCharCode(codeUnit);
      for (final digit in digits.codeUnits) {
        remainder = (remainder * 10 + (digit - 48)) % 97;
      }
    }
    return remainder;
  }
}
