import 'veranstaltung.dart';

enum AnmeldePhase {
  /// Anmeldefenster laeuft (oder ist ohne Beginn bis [Anmeldestatus.bis]
  /// offen).
  offen,

  /// Anmeldung oeffnet erst am [Anmeldestatus.ab].
  baldOffen,

  /// Anmeldeschluss ist vorbei.
  geschlossen,

  /// Das Event pflegt kein Anmeldefenster.
  unbekannt,
}

/// Anmeldestatus und Platzlage eines Events zu einem Stichtag.
class Anmeldestatus {
  const Anmeldestatus({
    required this.phase,
    this.ab,
    this.bis,
    this.freiePlaetze,
    this.maxPlaetze,
  });

  final AnmeldePhase phase;
  final DateTime? ab;
  final DateTime? bis;

  /// Nur bei Kursen mit gepflegtem Maximum.
  final int? freiePlaetze;
  final int? maxPlaetze;

  bool get ausgebucht => freiePlaetze == 0;
}

/// Leitet den Anmeldestatus aus Anmeldefenster und Platzlage ab. Hitobito
/// speichert die Fenster als Kalendertage; der Schlusstag zaehlt noch mit.
class BestimmeAnmeldestatusUseCase {
  const BestimmeAnmeldestatusUseCase();

  Anmeldestatus call(Veranstaltung veranstaltung, {required DateTime heute}) {
    final tag = DateTime(heute.year, heute.month, heute.day);
    final ab = _tag(veranstaltung.anmeldungAb);
    final bis = _tag(veranstaltung.anmeldungBis);

    final AnmeldePhase phase;
    if (ab == null && bis == null) {
      phase = AnmeldePhase.unbekannt;
    } else if (bis != null && tag.isAfter(bis)) {
      phase = AnmeldePhase.geschlossen;
    } else if (ab != null && tag.isBefore(ab)) {
      phase = AnmeldePhase.baldOffen;
    } else {
      phase = AnmeldePhase.offen;
    }

    final max = veranstaltung.maxTeilnehmende;
    return Anmeldestatus(
      phase: phase,
      ab: ab,
      bis: bis,
      freiePlaetze: veranstaltung.freiePlaetze,
      maxPlaetze: max != null && max > 0 ? max : null,
    );
  }

  static DateTime? _tag(DateTime? wert) =>
      wert == null ? null : DateTime(wert.year, wert.month, wert.day);
}
