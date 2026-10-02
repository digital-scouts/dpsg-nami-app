import '../member/member_utils.dart';
import '../member/mitglied.dart';
import '../stufe/altersgrenzen.dart';
import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';

/// Wann der naechste Stufenwechsel ansteht.
enum StufenwechselZeitpunkt {
  /// Ueberfaellig: das Hoechstalter der aktuellen Stufe ist ueberschritten.
  jetzt,

  /// Noch nicht moeglich, fruehestens im genannten Jahr.
  ab,

  /// Jetzt moeglich, spaetestens im genannten Jahr.
  bis,
}

class NaechsterStufenwechsel {
  const NaechsterStufenwechsel({
    required this.aktuelleStufe,
    required this.zielStufe,
    required this.zeitpunkt,
    required this.jahr,
  });

  final Stufe aktuelleStufe;

  /// `null` bei Rovern: dann steht das Ende der Roverzeit an.
  final Stufe? zielStufe;
  final StufenwechselZeitpunkt zeitpunkt;
  final int jahr;

  bool get istEndeRoverzeit => zielStufe == null;
}

/// Naechster Stufenwechsel eines Kindes oder Jugendlichen nach derselben
/// Regel wie der Stufenwechsel-Tab: faellig ab Geburtsjahr plus Mindestalter
/// der Zielstufe, spaetestens Geburtsjahr plus Hoechstalter der aktuellen
/// Stufe. Massgeblich ist die hoechste aktive Mitgliedsstufe, damit eine
/// parallele Zugehoerigkeit waehrend des Wechsels nicht doppelt zaehlt.
NaechsterStufenwechsel? berechneNaechstenStufenwechsel(
  Mitglied mitglied, {
  required Altersgrenzen altersgrenzen,
  required DateTime stichtag,
  required DateTime heute,
}) {
  if (!mitglied.hatBekanntesGeburtsdatum) {
    return null;
  }
  final austritt = mitglied.austrittsdatum;
  if (austritt != null && !austritt.isAfter(heute)) {
    return null;
  }

  Stufe? aktuelle;
  for (final rolle in mitglied.roles) {
    if (MemberUtils.istMitgliederRolle(rolle) ||
        !rolle.isActiveAt(heute) ||
        rolle.art != RoleCategory.mitglied ||
        rolle.stufe == Stufe.leitung) {
      continue;
    }
    if (aktuelle == null || rolle.stufe.index > aktuelle.index) {
      aktuelle = rolle.stufe;
    }
  }
  if (aktuelle == null) {
    return null;
  }

  final geburtsjahr = mitglied.geburtsdatum.year;
  final stichjahr = stichtag.year;
  final spaetestens = geburtsjahr + altersgrenzen.forStufe(aktuelle).maxJahre;
  final ziel = aktuelle.nextStufe;
  if (ziel == null) {
    return NaechsterStufenwechsel(
      aktuelleStufe: aktuelle,
      zielStufe: null,
      zeitpunkt: spaetestens < stichjahr
          ? StufenwechselZeitpunkt.jetzt
          : StufenwechselZeitpunkt.bis,
      jahr: spaetestens,
    );
  }

  final ab = geburtsjahr + altersgrenzen.forStufe(ziel).minJahre;
  final (zeitpunkt, jahr) = spaetestens < stichjahr
      ? (StufenwechselZeitpunkt.jetzt, spaetestens)
      : ab > stichjahr
      ? (StufenwechselZeitpunkt.ab, ab)
      : (StufenwechselZeitpunkt.bis, spaetestens);
  return NaechsterStufenwechsel(
    aktuelleStufe: aktuelle,
    zielStufe: ziel,
    zeitpunkt: zeitpunkt,
    jahr: jahr,
  );
}
