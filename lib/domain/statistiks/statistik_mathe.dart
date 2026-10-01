// Robuste Rechenhilfen für Statistiken: keine Division durch null, keine
// NaN- oder Unendlich-Werte, auch bei leeren oder krummen Daten.

/// Anteil von [wert] an [summe] zwischen 0 und 1; 0 bei leerer Summe.
double anteil(num wert, num summe) {
  if (summe <= 0 || wert <= 0) return 0;
  final ergebnis = wert / summe;
  if (!ergebnis.isFinite) return 0;
  return ergebnis.clamp(0, 1).toDouble();
}

/// Median der Werte; `null`, wenn keine endlichen Werte vorhanden sind.
double? median(Iterable<double> werte) {
  final sortiert = werte.where((w) => w.isFinite).toList()..sort();
  if (sortiert.isEmpty) return null;
  final mitte = sortiert.length ~/ 2;
  if (sortiert.length.isOdd) return sortiert[mitte];
  return (sortiert[mitte - 1] + sortiert[mitte]) / 2;
}

/// [wert], falls endlich, sonst [ersatz].
double endlich(double wert, [double ersatz = 0]) =>
    wert.isFinite ? wert : ersatz;

/// Jahre zwischen [von] und [bis] als Kommazahl; nie negativ.
double jahreZwischen(DateTime von, DateTime bis) {
  final tage = bis.difference(von).inHours / 24;
  if (!tage.isFinite || tage <= 0) return 0;
  return tage / 365.25;
}
