/// Entfernt personenbezogene Werte aus Texten, bevor sie ins App-Log oder an
/// den Feedback-Dienst gehen. Fehlertexte von Hitobito oder aus Exceptions
/// koennen Feldwerte wie E-Mail-Adressen oder Telefonnummern enthalten.
class LogSanitizer {
  const LogSanitizer._();

  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  /// Zugangsdaten in Kopfzeilen oder Query-Parametern.
  static final RegExp _token = RegExp(
    r'(Bearer\s+|(?:access_token|refresh_token|id_token|code)=)[^\s&"]+',
    caseSensitive: false,
  );

  static final RegExp _iban = RegExp(
    r'\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,4})?\b',
  );

  /// Nummern mit `+`, `00` oder `0` vorne und mindestens sieben Ziffern.
  /// Datumsangaben, Uhrzeiten und IDs beginnen anders und bleiben stehen.
  static final RegExp _telefon = RegExp(
    r'(?<![\w.:/-])(?:\+|0)\d[\d /()-]{5,}\d(?![\w])',
  );

  /// Ersetzt E-Mail-Adressen, Zugangsdaten, IBANs und Telefonnummern durch
  /// Platzhalter. Mit [maxLength] wird der Text danach gekuerzt.
  static String text(String value, {int? maxLength}) {
    var bereinigt = value
        .replaceAllMapped(_token, (match) => '${match.group(1)}<token>')
        .replaceAll(_email, '<email>')
        .replaceAll(_iban, '<iban>')
        .replaceAll(_telefon, '<telefon>');
    if (maxLength != null && bereinigt.length > maxLength) {
      bereinigt = '${bereinigt.substring(0, maxLength - 3)}...';
    }
    return bereinigt;
  }

  /// Typ und bereinigte erste Zeile eines Fehlers.
  static String fehler(Object error, {int maxLength = 300}) {
    final ersteZeile = error.toString().split('\n').first;
    return '${error.runtimeType}: ${text(ersteZeile, maxLength: maxLength)}';
  }
}
