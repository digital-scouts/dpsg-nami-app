/// Status einer Qualifikation aus Sicht der noetigen Aktion.
///
/// Bewusst nur drei Zustaende: ein abgelaufener Nachweis erfordert dieselbe
/// Aktion (erneute Vorlage) wie ein nie eingereichter, daher gibt es keinen
/// eigenen `abgelaufen`-Zustand.
enum QualifikationsStatus { fehlt, baldAblaufend, gueltig }

const _standardWarnschwelle = Duration(days: 90);

/// Ermittelt den [QualifikationsStatus] aus einem (ggf. fehlenden)
/// Gueltig-bis-Datum. `fehlt`, wenn kein Datum vorhanden ist oder es in der
/// Vergangenheit liegt (abgelaufen zaehlt als fehlt).
QualifikationsStatus berechneStatus({
  required DateTime? gueltigBis,
  required DateTime heute,
  Duration warnschwelle = _standardWarnschwelle,
}) {
  if (gueltigBis == null || gueltigBis.isBefore(heute)) {
    return QualifikationsStatus.fehlt;
  }

  final warnschwelleAb = gueltigBis.subtract(warnschwelle);
  if (!heute.isBefore(warnschwelleAb)) {
    return QualifikationsStatus.baldAblaufend;
  }

  return QualifikationsStatus.gueltig;
}
