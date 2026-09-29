import 'package:intl/intl.dart';

/// Präsentations-Formatter für deutsche Datumsdarstellung.
/// Nutzung erfordert einmalige Locale-Initialisierung (siehe `main_storybook.dart`).
class DateFormatter {
  /// Formatiert ein Datum im deutschen Langformat, z.B. "24. Dezember 2023"
  static String formatGermanLongDate(DateTime date) =>
      DateFormat('d. MMMM yyyy', 'de').format(date);

  /// Formatiert ein Datum im deutschen Kurzformat, z.B. "24.12.2023"
  static String formatGermanShortDate(DateTime date) =>
      DateFormat('dd.MM.yyyy', 'de').format(date);

  /// Formatiert ein deutsches Datum mit Uhrzeit, z.B. "24.12.2023, 15:30"
  static String formatGermanShortDateTime(DateTime date) =>
      DateFormat('dd.MM.yyyy, HH:mm', 'de').format(date);

  /// Formatiert ein Datum im technischen Kurzformat, z.B. "2023-12-24T15:30:00"
  static String formatTecnicalShortDate(DateTime date) =>
      DateFormat('yyyy-MM-ddTHH:mm:ss', 'de').format(date);
}
