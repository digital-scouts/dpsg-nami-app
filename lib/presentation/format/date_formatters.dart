import 'package:intl/intl.dart';

/// Präsentations-Formatter für deutsche Datumsdarstellung.
/// Nutzung erfordert einmalige Locale-Initialisierung (siehe `main_storybook.dart`).
class DateFormatter {
  static String formatGermanLongDate(DateTime date) =>
      DateFormat('d. MMMM yyyy', 'de').format(date);

  static String formatGermanShortDate(DateTime date) =>
      DateFormat('dd.MM.yyyy', 'de').format(date);
}
