/// Status einer Qualifikation.
///
/// `abgelaufen` und `fehlt` erfordern dieselbe Aktion (erneute Vorlage),
/// werden aber getrennt gefuehrt, damit die Anzeige „Abgelaufen am …“ von
/// „Keines hinterlegt“ unterscheiden kann.
enum QualifikationsStatus { fehlt, abgelaufen, baldAblaufend, gueltig }

const _standardWarnschwelle = Duration(days: 90);

/// Ermittelt den [QualifikationsStatus] aus einem (ggf. fehlenden)
/// Gueltig-bis-Datum. `fehlt`, wenn kein Datum vorhanden ist, `abgelaufen`,
/// wenn es in der Vergangenheit liegt.
QualifikationsStatus berechneStatus({
  required DateTime? gueltigBis,
  required DateTime heute,
  Duration warnschwelle = _standardWarnschwelle,
}) {
  if (gueltigBis == null) {
    return QualifikationsStatus.fehlt;
  }
  if (gueltigBis.isBefore(heute)) {
    return QualifikationsStatus.abgelaufen;
  }

  final warnschwelleAb = gueltigBis.subtract(warnschwelle);
  if (!heute.isBefore(warnschwelleAb)) {
    return QualifikationsStatus.baldAblaufend;
  }

  return QualifikationsStatus.gueltig;
}
