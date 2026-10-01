import 'package:collection/collection.dart';

import '../taetigkeit/stufe.dart';

/// Kennzahlen eines Stamms für die Statistik-Kacheln.
///
/// Alle Werte sind endlich und nie negativ, auch bei krummen Daten
/// (Platzhalter-Geburtsdaten, Eintritte in der Zukunft, leere Gruppen).
class StammStatistik {
  const StammStatistik({
    required this.stammName,
    required this.personen,
    required this.kinder,
    required this.leitende,
    required this.sonstige,
    required this.stufen,
    required this.prognose,
    required this.bindung,
    required this.geschlecht,
    required this.ohneGeburtsdatum,
  });

  final String stammName;

  /// Alle Personen im Arbeitskontext.
  final int personen;

  /// Kinder und Jugendliche (Mitgliedsrolle in einer Stufengruppe).
  final int kinder;

  /// Leitende (Leitungsrolle in einer Stufengruppe).
  final int leitende;

  /// Personen ohne Rolle in einer Stufengruppe (z. B. Vorstand, Kurat*in).
  final int sonstige;

  /// Biber bis Rover, immer in dieser Reihenfolge und vollständig.
  final List<StufenStatistik> stufen;

  /// `null`, solange die Rollen noch nicht geladen sind oder kein Stichtag
  /// bekannt ist.
  final StufenwechselPrognose? prognose;

  final BindungStatistik bindung;

  /// Geschlecht der Kinder und Jugendlichen.
  final Map<GeschlechtKategorie, int> geschlecht;

  /// Kinder und Jugendliche ohne bekanntes Geburtsdatum.
  final int ohneGeburtsdatum;

  StufenStatistik stufe(Stufe stufe) =>
      stufen.firstWhere((s) => s.stufe == stufe);

  /// Höchste Kinderzahl einer einzelnen Gruppe (0 ohne Gruppen).
  int get groessteGruppe => stufen
      .expand((s) => s.gruppen)
      .fold<int>(0, (max, g) => g.kinder > max ? g.kinder : max);

  @override
  bool operator ==(Object other) =>
      other is StammStatistik &&
      other.stammName == stammName &&
      other.personen == personen &&
      other.kinder == kinder &&
      other.leitende == leitende &&
      other.sonstige == sonstige &&
      const ListEquality<StufenStatistik>().equals(other.stufen, stufen) &&
      other.prognose == prognose &&
      other.bindung == bindung &&
      const MapEquality<GeschlechtKategorie, int>().equals(
        other.geschlecht,
        geschlecht,
      ) &&
      other.ohneGeburtsdatum == ohneGeburtsdatum;

  @override
  int get hashCode => Object.hash(
    stammName,
    personen,
    kinder,
    leitende,
    sonstige,
    Object.hashAll(stufen),
    prognose,
    bindung,
    ohneGeburtsdatum,
  );
}

class StufenStatistik {
  const StufenStatistik({
    required this.stufe,
    required this.gruppen,
    required this.kinder,
    required this.leitende,
    required this.alter,
  });

  final Stufe stufe;
  final List<GruppenStatistik> gruppen;

  /// Kinder und Jugendliche der Stufe (jede Person einmal).
  final int kinder;

  /// Leitende der Stufe (jede Person einmal).
  final int leitende;

  /// Alter der Kinder und Jugendlichen in Jahren, nur bekannte Geburtsdaten.
  final List<double> alter;

  @override
  bool operator ==(Object other) =>
      other is StufenStatistik &&
      other.stufe == stufe &&
      const ListEquality<GruppenStatistik>().equals(other.gruppen, gruppen) &&
      other.kinder == kinder &&
      other.leitende == leitende &&
      const ListEquality<double>().equals(other.alter, alter);

  @override
  int get hashCode => Object.hash(
    stufe,
    Object.hashAll(gruppen),
    kinder,
    leitende,
    Object.hashAll(alter),
  );
}

class GruppenStatistik {
  const GruppenStatistik({
    required this.gruppenId,
    required this.name,
    required this.stufe,
    required this.kinder,
    required this.leitende,
  });

  final int gruppenId;
  final String name;
  final Stufe stufe;
  final int kinder;
  final int leitende;

  @override
  bool operator ==(Object other) =>
      other is GruppenStatistik &&
      other.gruppenId == gruppenId &&
      other.name == name &&
      other.stufe == stufe &&
      other.kinder == kinder &&
      other.leitende == leitende;

  @override
  int get hashCode => Object.hash(gruppenId, name, stufe, kinder, leitende);
}

/// Größe der Stufen heute und nach dem nächsten Stufenwechsel.
class StufenwechselPrognose {
  const StufenwechselPrognose({
    required this.stichtag,
    required this.anzahl,
    required this.stufen,
  });

  final DateTime stichtag;

  /// Personen, die zum Stichtag in die nächste Stufe wechseln können.
  final int anzahl;

  /// Biber bis Rover, immer vollständig.
  final List<StufenwechselStufe> stufen;

  @override
  bool operator ==(Object other) =>
      other is StufenwechselPrognose &&
      other.stichtag == stichtag &&
      other.anzahl == anzahl &&
      const ListEquality<StufenwechselStufe>().equals(other.stufen, stufen);

  @override
  int get hashCode => Object.hash(stichtag, anzahl, Object.hashAll(stufen));
}

class StufenwechselStufe {
  const StufenwechselStufe({
    required this.stufe,
    required this.heute,
    required this.ab,
    required this.zu,
  });

  final Stufe stufe;
  final int heute;

  /// Wechseln weiter (bei Rovern: werden zu alt für die Stufe).
  final int ab;

  /// Kommen aus der vorherigen Stufe dazu.
  final int zu;

  /// Größe nach dem Stichtag, nie negativ.
  int get danach {
    final wert = heute - ab + zu;
    return wert < 0 ? 0 : wert;
  }

  @override
  bool operator ==(Object other) =>
      other is StufenwechselStufe &&
      other.stufe == stufe &&
      other.heute == heute &&
      other.ab == ab &&
      other.zu == zu;

  @override
  int get hashCode => Object.hash(stufe, heute, ab, zu);
}

class BindungStatistik {
  const BindungStatistik({
    required this.neuInZwoelfMonaten,
    required this.eintritteJeMonat,
    required this.medianJahreKinder,
    required this.medianJahreLeitende,
  });

  final int neuInZwoelfMonaten;

  /// Die letzten zwölf Monate, ältester zuerst, aktueller Monat zuletzt.
  final List<EintritteImMonat> eintritteJeMonat;

  /// Median der Mitgliedsdauer in Jahren; `null` ohne bekannte Eintritte.
  final double? medianJahreKinder;
  final double? medianJahreLeitende;

  @override
  bool operator ==(Object other) =>
      other is BindungStatistik &&
      other.neuInZwoelfMonaten == neuInZwoelfMonaten &&
      const ListEquality<EintritteImMonat>().equals(
        other.eintritteJeMonat,
        eintritteJeMonat,
      ) &&
      other.medianJahreKinder == medianJahreKinder &&
      other.medianJahreLeitende == medianJahreLeitende;

  @override
  int get hashCode => Object.hash(
    neuInZwoelfMonaten,
    Object.hashAll(eintritteJeMonat),
    medianJahreKinder,
    medianJahreLeitende,
  );
}

class EintritteImMonat {
  const EintritteImMonat({
    required this.jahr,
    required this.monat,
    required this.anzahl,
  });

  final int jahr;

  /// 1 bis 12.
  final int monat;
  final int anzahl;

  @override
  bool operator ==(Object other) =>
      other is EintritteImMonat &&
      other.jahr == jahr &&
      other.monat == monat &&
      other.anzahl == anzahl;

  @override
  int get hashCode => Object.hash(jahr, monat, anzahl);
}

enum GeschlechtKategorie {
  weiblich,
  maennlich,
  divers,
  ohneAngabe;

  /// Ordnet die freie Angabe aus Hitobito ein (`w`, `female`, `weiblich` …).
  static GeschlechtKategorie aus(String? angabe) {
    switch (angabe?.trim().toLowerCase()) {
      case 'w':
      case 'f':
      case 'female':
      case 'weiblich':
        return GeschlechtKategorie.weiblich;
      case 'm':
      case 'male':
      case 'maennlich':
      case 'männlich':
        return GeschlechtKategorie.maennlich;
      case 'd':
      case 'divers':
      case 'diverse':
        return GeschlechtKategorie.divers;
      default:
        return GeschlechtKategorie.ohneAngabe;
    }
  }
}
