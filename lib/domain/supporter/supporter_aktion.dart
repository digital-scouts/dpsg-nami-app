/// Einfuehrungspreis der Design-Pakete. Die Stores liefern fuer Einmalkaeufe
/// keinen Vorher-Preis, deshalb kennt die App Normalpreis und Aktionsende
/// selbst. Ab [ende] muss der Preis in beiden Stores auf [normalpreisEur]
/// stehen.
abstract final class SupporterAktion {
  static const double normalpreisEur = 2.99;

  /// Erster Tag nach der Aktion.
  static final DateTime ende = DateTime(2027, 4);

  /// Letzter Aktionstag fuer die Anzeige „bis 31.3.“.
  static DateTime get letzterTag => ende.subtract(const Duration(days: 1));

  /// Ob der Store-Preis als reduziert angezeigt wird: nur in Euro, nur bis
  /// zum Aktionsende und nur, wenn er unter dem Normalpreis liegt.
  static bool reduziert({
    required String waehrung,
    required double preis,
    required DateTime jetzt,
  }) => waehrung == 'EUR' && preis < normalpreisEur && jetzt.isBefore(ende);
}
