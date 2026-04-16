import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';

/// Bereinigt eine Liste von Tätigkeiten für Statistik-Zwecke.
/// Regeln:
/// - Überlappende Zeiten werden aufgelöst, indem in jedem Überlapp-Intervall
///   die neueste Tätigkeit (höchstes Startdatum) gewählt wird.
/// - Doppelte/zusammenhängende Zeiträume derselben (Stufe, Art) werden
///   zusammengelegt.
/// - Parallele, unwichtigere Tätigkeiten in Überlapp werden entfernt
///   (Priorität: Leitung > Mitglied > Sonstige).
///
/// Input: Original Liste Taetigkeit
/// Output: Neue Liste Taetigkeit ohne Überlapp, zusammengelegt.
List<Role> cleanForStatistiks(List<Role> original) {
  if (original.isEmpty) return const [];

  // Vergangene und aktuelle Tätigkeiten berücksichtigen.
  // Aktuelle werden bis "jetzt" begrenzt; zukünftige ignoriert.
  final now = DateTime.now();
  final normalized = <Role>[];
  for (final t in original) {
    final startsInFuture = t.start.isAfter(now);
    if (startsInFuture) continue; // zukünftige Tätigkeit ignorieren^

    final isActive = t.ende == null || (t.ende!.isAfter(now));
    final effectiveEnd = isActive ? now : t.ende!;
    // Nur Intervalle mit positiver Dauer aufnehmen
    if (!effectiveEnd.isAfter(t.start)) continue;
    normalized.add(
      roleFromLegacy(
        stufe: t.stufe,
        art: t.art,
        start: DateTime(t.start.year, t.start.month, t.start.day),
        ende: DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day),
      ),
    );
  }
  if (normalized.isEmpty) return const [];

  // Erzeuge sortierte Schnittpunkte (Tage-genau), an denen sich Zustände ändern.
  final points = <DateTime>{};
  for (final t in normalized) {
    points.add(DateTime(t.start.year, t.start.month, t.start.day));
    final e = t.ende!;
    points.add(DateTime(e.year, e.month, e.day));
  }
  final cuts = points.toList()..sort();
  if (cuts.length < 2) return const [];

  // (Priorität-Hilfsfunktion entfällt; Regeln unten angewandt)

  // Priorität: Leitung > Mitglied > Sonstige
  int priority(RoleCategory art) {
    switch (art) {
      case RoleCategory.leitung:
        return 3;
      case RoleCategory.mitglied:
        return 2;
      case RoleCategory.sonstiges:
        return 1;
    }
  }

  // Iteratives Einfügen mit Kürzungsregeln
  final segments = <Role>[];
  final byStart = [...normalized]..sort((a, b) => a.start.compareTo(b.start));
  for (var t in byStart) {
    // Kürzungen gegenüber bereits enthaltenen Segmenten anwenden
    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      final overlaps = s.start.isBefore(t.ende!) && t.start.isBefore(s.ende!);
      if (!overlaps) continue;

      final pNew = priority(t.art);
      final pOld = priority(s.art);

      if (t.start.isAtSameMomentAs(s.start)) {
        // Gleicher Start: behalte die höhere Priorität, entferne/verkürze die niedrigere
        if (pNew >= pOld) {
          // kürze bestehendes Segment bis 0 Dauer
          segments[i] = roleFromLegacy(
            stufe: s.stufe,
            art: s.art,
            start: s.start,
            ende: s.start,
          );
        } else {
          // kürze neues Segment am Start auf s.ende
          t = roleFromLegacy(
            stufe: t.stufe,
            art: t.art,
            start: s.ende!,
            ende: t.ende,
          );
        }
      } else if (pNew >= pOld) {
        // Neuere mit höherer/gleicher Priorität gewinnt: kürze älteres Ende auf neueren Start
        if (s.ende!.isAfter(t.start)) {
          segments[i] = roleFromLegacy(
            stufe: s.stufe,
            art: s.art,
            start: s.start,
            ende: t.start,
          );
        }
      } else {
        // Neuere hat niedrigere Priorität: kürze neuere am Start auf älteres Ende
        if (t.start.isBefore(s.ende!)) {
          t = roleFromLegacy(
            stufe: t.stufe,
            art: t.art,
            start: s.ende!,
            ende: t.ende,
          );
        }
      }
    }
    // Nur hinzufügen, wenn gültige Dauer
    if (t.ende!.isAfter(t.start)) {
      segments.add(t);
    }
  }

  // Entferne Null-/Negativ-Dauer-Segmente (können durch Kürzungen entstehen)
  segments.removeWhere((s) => !s.ende!.isAfter(s.start));
  if (segments.isEmpty) return const [];

  // Zusammenlegen: aufeinanderfolgende Segmente mit gleicher (Stufe, Art)
  // und lückenlos angrenzenden Zeiten werden gemerged.
  segments.sort((a, b) => a.start.compareTo(b.start));
  final merged = <Role>[];
  for (final s in segments) {
    if (merged.isEmpty) {
      merged.add(s);
      continue;
    }
    final last = merged.last;
    final sameRole = last.stufe == s.stufe && last.art == s.art;
    final overlapsOrContiguous = !s.start.isAfter(
      last.ende!,
    ); // s.start <= last.ende
    if (sameRole && overlapsOrContiguous) {
      merged[merged.length - 1] = roleFromLegacy(
        stufe: last.stufe,
        art: last.art,
        start: last.start,
        ende: (s.ende!.isAfter(last.ende!) ? s.ende : last.ende),
      );
    } else {
      merged.add(s);
    }
  }

  // Sonderfall: Zwei gleiche Rollen, getrennt durch genau ein anderes Segment direkt dazwischen
  // Beispiel: Mitglied [Jan-Feb], Leitung [Feb-Mar], Mitglied [Mar-Apr] => Mitglied [Jan-Mar], Mitglied [Mar-Apr]
  for (int i = 0; i + 2 < merged.length;) {
    final a = merged[i];
    final b = merged[i + 1];
    final c = merged[i + 2];
    final sameAC = a.stufe == c.stufe && a.art == c.art;
    final fillsGap = a.ende == b.start && b.ende == c.start;
    if (sameAC && fillsGap) {
      // Entferne mittleres Segment und merge A mit C
      merged[i] = roleFromLegacy(
        stufe: a.stufe,
        art: a.art,
        start: a.start,
        ende: c.start,
      );
      merged.removeAt(i + 1); // entferne b
      // c bleibt bestehen
      // Nicht i++ erhöhen, da neues Muster erneut möglich sein kann
    } else {
      i++;
    }
  }

  return merged;
}

class RoleDuration {
  RoleDuration({required this.stufe, required this.art, required this.days});
  final Stufe stufe;
  final RoleCategory art;
  final int days;
}

List<RoleDuration> durationsByRoleDays(List<Role> original) {
  final cleaned = cleanForStatistiks(original);
  if (cleaned.isEmpty) return const [];

  final Map<(Stufe, RoleCategory), int> acc = {};
  for (final t in cleaned) {
    final days = t.ende!.difference(t.start).inDays;
    if (days <= 0) continue;
    final key = (t.stufe, t.art);
    acc.update(key, (v) => v + days, ifAbsent: () => days);
  }

  return [
    for (final e in acc.entries)
      RoleDuration(stufe: e.key.$1, art: e.key.$2, days: e.value),
  ];
}

Duration membershipDuration(List<Role> original) {
  final cleaned = cleanForStatistiks(original);
  if (cleaned.isEmpty) return Duration.zero;

  int days = 0;
  for (final t in cleaned) {
    final d = t.ende!.difference(t.start).inDays;
    if (d > 0) days += d;
  }
  return Duration(days: days);
}
