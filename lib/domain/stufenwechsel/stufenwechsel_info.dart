/// Berechnung von Stufenwechsel-Informationen basierend auf Alter am Stichtag.
library;

import 'package:nami/domain/member/member_utils.dart';

import '../member/mitglied.dart';
import '../taetigkeit/stufe.dart';
import '../taetigkeit/taetigkeit.dart';

///
/// Eingabe:
/// - Mitgliederliste
/// - Stichtag (Datum X)
/// - Altersgrenzen pro Stufe (min/max in Jahren)
///
/// Ausgabe:
/// - Objekt je Mitglied: Name/Vorname, ID, Alter zum Stichtag (als Duration),
///   möglicher Wechselzeitraum (Start/Ende Jahr) gemäß Regelwerk.
// Hinweis: Wir nutzen die vorhandenen Domain-Entitäten `Mitglied` und `Stufe`.

class Altersgrenzen {
  final Map<Stufe, AgeRange> grenzen;

  Altersgrenzen(this.grenzen);

  AgeRange operator [](Stufe s) => grenzen[s]!;
}

class AgeRange {
  final int minJahre; // inkl. Mindestalter
  final int maxJahre; // letztes Jahr vor Überschreitung Maximalalter

  const AgeRange({required this.minJahre, required this.maxJahre});
}

class Wechselzeitraum {
  final int? startJahr; // erstes Stufenwechsel-Jahr, in dem Wechsel möglich ist
  final int?
  endJahr; // letztes Stufenwechsel-Jahr (oder Ende Mitgliedschaft bei Rover)

  const Wechselzeitraum({this.startJahr, this.endJahr});
}

class StufenwechselInfo {
  final String id;
  final String vorname;
  final Stufe? stufe;
  final Duration alterZumStichtag;
  final Wechselzeitraum wechselzeitraum;
  final bool shouldWechselNext;

  const StufenwechselInfo({
    required this.id,
    required this.vorname,
    this.stufe,
    required this.alterZumStichtag,
    required this.wechselzeitraum,
    required this.shouldWechselNext,
  });
}

/// Berechnet das Alter als Duration vom Geburtstag bis zum Stichtag.
Duration alterAm(DateTime geburtstag, DateTime stichtag) {
  return stichtag.difference(geburtstag);
}

/// Hilfsfunktion: Ganzzahlige Jahre aus einer Duration (approx, 365 Tage/Jahr).
int jahreAusDuration(Duration d) {
  // Näherung: ein Jahr = 365 Tage; für Genauigkeit könnte man kalendergenau rechnen.
  return (d.inDays / 365).floor();
}

/// Berechnet den möglichen Wechselzeitraum gemäß Regeln:
/// - Für Biber/Wös/Jufis/Pfadis: frühestens zum minAlter der nächsten Stufe,
///   spätestens zum maxAlter der aktuellen Stufe.
/// - Für Rover: Mitgliedschaft endet zum maxAlter (nur max relevant).
Wechselzeitraum berechneWechselzeitraum(
  Mitglied m,
  DateTime stichtag,
  Altersgrenzen grenzen,
) {
  // Bestimme aktuelle Stufe über MemberUtils
  final currentStufe = MemberUtils.aktiveStufe(m);
  if (currentStufe == Stufe.leitung) {
    return const Wechselzeitraum(startJahr: null, endJahr: null);
  }
  final currentRange = grenzen[currentStufe!];

  if (currentStufe == Stufe.rover) {
    // Ende Mitgliedschaft zum maxAlter der Rover
    final endJahr = m.geburtsdatum.year + currentRange.maxJahre;
    return Wechselzeitraum(startJahr: null, endJahr: endJahr);
  }

  final next = currentStufe.nextStufe!;
  final nextRange = grenzen[next];

  // Start: erstes Wechsel-Jahr, in dem das Mitglied das minAlter der nächsten Stufe erreicht
  final startJahr = m.geburtsdatum.year + nextRange.minJahre;

  // Ende: letztes Wechsel-Jahr, bevor das Mitglied das maxAlter der aktuellen Stufe überschreitet
  final endJahr = m.geburtsdatum.year + currentRange.maxJahre;

  return Wechselzeitraum(startJahr: startJahr, endJahr: endJahr);
}

/// Gibt zurück, ob das Mitglied beim nächsten Wechsel wechseln sollte.
bool berechneShouldWechselNext(
  Mitglied m,
  DateTime stichtag,
  Altersgrenzen grenzen,
) {
  if (MemberUtils.isLeitung(m)) {
    return false;
  }
  // Wenn bereits eine zukünftige Tätigkeit in der nächsten Stufe geplant ist,
  // soll shouldWechselNext = false sein.
  final Stufe? currentStufe = MemberUtils.aktiveStufe(m);
  final Stufe? next = currentStufe?.nextStufe;
  if (next != null) {
    final hasFuturePlannedNext = m.taetigkeiten.any(
      (t) =>
          t.stufe == next &&
          t.art == TaetigkeitsArt.mitglied &&
          t.start.isAfter(stichtag),
    );
    if (hasFuturePlannedNext) return false;
  }
  final wz = berechneWechselzeitraum(m, stichtag, grenzen);
  if (currentStufe == Stufe.rover) {
    return wz.endJahr != null && stichtag.year >= wz.endJahr!;
  }

  final start = wz.startJahr!;
  final end = wz.endJahr!;
  if (stichtag.year < start) return false; // zu jung
  return stichtag.year <= end ||
      stichtag.year > end; // innerhalb oder zu alt => true
}

List<StufenwechselInfo> computeStufenwechselInfos({
  required List<Mitglied> mitglieder,
  required DateTime stichtag,
  required Altersgrenzen grenzen,
}) {
  // Nur Mitglieder berücksichtigen, die aktuell Mitglied in einer Stufe sind
  final filtered = mitglieder.where((m) {
    final stufe = MemberUtils.aktiveStufe(m);
    return stufe != null && stufe != Stufe.leitung;
  });
  return filtered.map((m) {
    final alter = alterAm(m.geburtsdatum, stichtag);
    final wechsel = berechneWechselzeitraum(m, stichtag, grenzen);
    final shouldWechsel = berechneShouldWechselNext(m, stichtag, grenzen);
    return StufenwechselInfo(
      id: m.mitgliedsnummer,
      vorname: m.vorname,
      stufe: MemberUtils.aktiveStufe(m),
      alterZumStichtag: alter,
      wechselzeitraum: wechsel,
      shouldWechselNext: shouldWechsel,
    );
  }).toList();
}
