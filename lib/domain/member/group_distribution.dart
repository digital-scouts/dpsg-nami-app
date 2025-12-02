import 'stufe.dart';
import 'taetigkeit.dart';

/// Verteilung für eine einzelne Stufe: Anzahl Leitende und Mitglieder.
class GroupDistribution {
  const GroupDistribution({
    required this.stufe,
    required this.leitungCount,
    required this.mitgliedCount,
  });
  final Stufe stufe;
  final int leitungCount;
  final int mitgliedCount;
  int get total => leitungCount + mitgliedCount;
  static const empty = GroupDistribution(
    stufe: Stufe.biber,
    leitungCount: 0,
    mitgliedCount: 0,
  ); // Platzhalter
}

/// Berechnet die Verteilung für alle Stufen (ohne die reine "Leitung" Stufe als eigene Säule).
/// Leitende werden durch `TaetigkeitsArt.leitung` identifiziert und der jeweiligen Stufe zugerechnet.
List<GroupDistribution> computeGroupDistributions(
  List<Taetigkeit> taetigkeiten, {
  bool nurAktive = true,
}) {
  if (taetigkeiten.isEmpty) return const [];
  final byStufe = <Stufe, Map<TaetigkeitsArt, int>>{};
  for (final t in taetigkeiten) {
    if (nurAktive && !t.istAktiv) continue;
    // Die Stufe.leitung (generische Leitungs-Stufe) wird hier ignoriert, da Leitende einer Stufe
    // anhand ihrer Tätigkeit (art == leitung) und der Ziel-Stufe gezählt werden sollen.
    if (t.stufe == Stufe.leitung) continue;
    final map = byStufe.putIfAbsent(t.stufe, () => {});
    map.update(t.art, (v) => v + 1, ifAbsent: () => 1);
  }
  if (byStufe.isEmpty) return const [];
  final result = <GroupDistribution>[
    for (final entry in byStufe.entries)
      GroupDistribution(
        stufe: entry.key,
        leitungCount: entry.value[TaetigkeitsArt.leitung] ?? 0,
        mitgliedCount: entry.value[TaetigkeitsArt.mitglied] ?? 0,
      ),
  ]..sort((a, b) => a.stufe.order.compareTo(b.stufe.order));
  return result;
}

/// Berechnet nur für eine spezifische Stufe.
GroupDistribution computeGroupDistributionForStufe(
  Stufe stufe,
  List<Taetigkeit> taetigkeiten, {
  bool nurAktive = true,
}) {
  int leitung = 0;
  int mitglied = 0;
  for (final t in taetigkeiten) {
    if (t.stufe != stufe) continue;
    if (nurAktive && !t.istAktiv) continue;
    switch (t.art) {
      case TaetigkeitsArt.leitung:
        leitung++;
      case TaetigkeitsArt.mitglied:
        mitglied++;
      case TaetigkeitsArt.sonstiges:
        // ignorieren
        break;
    }
  }
  return GroupDistribution(
    stufe: stufe,
    leitungCount: leitung,
    mitgliedCount: mitglied,
  );
}
