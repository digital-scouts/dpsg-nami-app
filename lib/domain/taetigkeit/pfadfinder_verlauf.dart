import '../member/member_utils.dart';
import '../member/mitglied.dart';
import 'role_derivation.dart';
import 'roles.dart';
import 'stufe.dart';

/// Ein Zeitabschnitt einer Rolle im Pfadfinder-Verlauf.
class VerlaufSegment {
  const VerlaufSegment({
    required this.rolle,
    required this.stufe,
    required this.art,
    required this.von,
    required this.bis,
    required this.aktiv,
  });

  final Role rolle;

  /// `null` fuer Aemter ohne Stufe.
  final Stufe? stufe;
  final RoleCategory art;
  final DateTime von;
  final DateTime bis;
  final bool aktiv;
}

/// Pfadfinder-Verlauf einer Person: Segmente aller begonnenen Rollen und die
/// Kennzahlen daraus. Robust gegen krumme Daten (fehlender Start, Ende vor
/// Start, Rollen vor dem Eintritt).
class PfadfinderVerlauf {
  const PfadfinderVerlauf({
    required this.von,
    required this.bis,
    required this.segmente,
    required this.leitungsJahre,
    required this.stufenAlsMitglied,
    required this.unbekanntBis,
  });

  /// Beginn der Zeitachse: Eintritt oder fruehere erste Rolle.
  final DateTime von;

  /// Ende der Zeitachse: heute oder Austritt.
  final DateTime bis;
  final List<VerlaufSegment> segmente;
  final double leitungsJahre;

  /// Stufen Woelfling bis Rover, in denen die Person Mitglied war.
  final Set<Stufe> stufenAlsMitglied;

  /// Ende der Zeit vor der ersten bekannten Rolle, wenn sie laenger als ein
  /// halbes Jahr ist; Hitobito liefert fruehere Rollen derzeit nicht.
  final DateTime? unbekanntBis;

  bool get istNeu => bis.difference(von).inDays < 180;
  bool get hatLeitung => segmente.any((s) => s.art == RoleCategory.leitung);

  static const Set<Stufe> zaehlStufen = <Stufe>{
    Stufe.woelfling,
    Stufe.jungpfadfinder,
    Stufe.pfadfinder,
    Stufe.rover,
  };
}

PfadfinderVerlauf berechnePfadfinderVerlauf(
  Mitglied mitglied, {
  required DateTime heute,
}) {
  final austritt = mitglied.austrittsdatum;
  final bis = austritt != null && austritt.isBefore(heute) ? austritt : heute;
  final eintritt = mitglied.hatBekanntesEintrittsdatum
      ? mitglied.eintrittsdatum
      : null;

  final segmente = <VerlaufSegment>[];
  for (final rolle in mitglied.roles) {
    if (MemberUtils.istMitgliederRolle(rolle)) {
      continue;
    }
    // Ohne Startdatum zaehlt der Eintritt.
    final start = rolle.startOn ?? rolle.createdAt ?? eintritt;
    if (start == null || start.isAfter(heute)) {
      continue;
    }
    final ende = rolle.ende;
    final segmentBis = ende != null && ende.isBefore(bis) ? ende : bis;
    if (segmentBis.isBefore(start)) {
      continue;
    }
    final stufe = rolle.stufe == Stufe.leitung ? null : rolle.stufe;
    segmente.add(
      VerlaufSegment(
        rolle: rolle,
        stufe: rolle.art == RoleCategory.sonstiges ? null : stufe,
        art: stufe == null && rolle.art != RoleCategory.sonstiges
            ? RoleCategory.sonstiges
            : rolle.art,
        von: start,
        bis: segmentBis,
        aktiv: rolle.isActiveAt(heute),
      ),
    );
  }
  segmente.sort((a, b) => a.von.compareTo(b.von));

  final ersterStart = segmente.isEmpty ? null : segmente.first.von;
  var von = eintritt ?? ersterStart ?? bis;
  if (ersterStart != null && ersterStart.isBefore(von)) {
    von = ersterStart;
  }
  final unbekanntBis =
      ersterStart != null && ersterStart.difference(von).inDays > 182
      ? ersterStart
      : null;

  return PfadfinderVerlauf(
    von: von,
    bis: bis,
    segmente: List.unmodifiable(segmente),
    leitungsJahre: _vereinigteJahre(
      segmente.where((s) => s.art == RoleCategory.leitung),
    ),
    stufenAlsMitglied: {
      for (final s in segmente)
        if (s.art == RoleCategory.mitglied &&
            PfadfinderVerlauf.zaehlStufen.contains(s.stufe))
          s.stufe!,
    },
    unbekanntBis: unbekanntBis,
  );
}

double _vereinigteJahre(Iterable<VerlaufSegment> segmente) {
  final sortiert = segmente.toList()..sort((a, b) => a.von.compareTo(b.von));
  var tage = 0;
  DateTime? start;
  DateTime? ende;
  for (final s in sortiert) {
    if (start == null || s.von.isAfter(ende!)) {
      if (start != null) {
        tage += ende!.difference(start).inDays;
      }
      start = s.von;
      ende = s.bis;
    } else if (s.bis.isAfter(ende)) {
      ende = s.bis;
    }
  }
  if (start != null) {
    tage += ende!.difference(start).inDays;
  }
  return tage / 365.25;
}
