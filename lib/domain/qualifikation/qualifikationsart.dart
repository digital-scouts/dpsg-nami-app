/// Beschreibt eine Art von Qualifikation/Eignungsnachweis, die in der
/// Qualifikationen-Uebersicht angezeigt und gefiltert werden kann.
///
/// Bewusst app-seitig konfiguriert (kein API-Feld): NAMI kennt fuer EFZ keine
/// `qualification_kind`, daher ist `istPflicht` und `gueltigkeitsjahre` hier
/// als App-Parameter hinterlegt statt aus der API gelesen zu werden.
///
/// Die Gueltigkeitsdauer ist bewusst in ganzen Kalenderjahren modelliert
/// (nicht als Tage-`Duration`): "5 Jahre ab Ausstellungsdatum" bedeutet
/// dasselbe Datum 5 Jahre spaeter, unabhaengig von dazwischenliegenden
/// Schaltjahren.
class Qualifikationsart {
  const Qualifikationsart({
    required this.key,
    required this.label,
    required this.istPflicht,
    required this.gueltigkeitsjahre,
  });

  final String key;
  final String label;
  final bool istPflicht;
  final int gueltigkeitsjahre;
}

const efzQualifikationsart = Qualifikationsart(
  key: 'efz',
  label: 'Erweitertes Führungszeugnis',
  istPflicht: true,
  gueltigkeitsjahre: 5,
);

/// Registrierung aller unterstuetzten Qualifikationsarten. Aktuell nur EFZ;
/// spaeter sollen hier echte NAMI-`qualification_kinds` (z.B.
/// Praeventionsschulung) ergaenzt werden koennen.
const alleQualifikationsarten = <Qualifikationsart>[efzQualifikationsart];
