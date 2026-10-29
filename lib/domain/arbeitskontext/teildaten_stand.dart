/// Ladezustand eines Teildatensatzes im Arbeitskontext, der getrennt von
/// Personen geladen wird (z. B. EFZ-Einsichtnahmen, Qualifikationen).
enum TeildatenStand {
  /// Noch nie synchronisiert, etwa nach einem Update aus einer aelteren
  /// Version.
  unbekannt,
  geladen,

  /// Die API hat den Abruf mit 403 abgelehnt; das ist kein Sync-Fehler.
  keineBerechtigung,
  fehlgeschlagen,

  /// Der letzte Abruf schlug fehl; der Bestand stammt vom letzten Erfolg
  /// (auf die Personen des Kontexts gefiltert, hoechstens `maxDataAge` alt).
  veraltet;

  /// Es gibt Eintraege zum Anzeigen, aktuell oder vom letzten Erfolg.
  bool get hatDaten => this == geladen || this == veraltet;

  static TeildatenStand ausName(Object? name) {
    for (final stand in values) {
      if (stand.name == name) {
        return stand;
      }
    }
    return unbekannt;
  }
}
