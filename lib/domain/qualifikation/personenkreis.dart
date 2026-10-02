import '../member/member_utils.dart';
import '../member/mitglied.dart';
import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';

/// Rollenart einer Regel; `amt` entspricht `RoleCategory.sonstiges`
/// (Vorstand, Kurat, Kassenwart, ...).
enum Rollenart { leitung, amt, mitglied }

enum PersonenkreisRegelTyp { rollenart, stufe, rollentyp, alterAb, alterBis }

enum RegelVerknuepfung { und, oder }

/// Ein Baustein des Personenkreises, etwa „Rollenart ist Leitung“ oder
/// „Alter ab 16“. [wert] ist je nach [typ] der Name einer [Rollenart], einer
/// [Stufe], ein Rollentyp (`Role.type`, sonst Label) oder eine Zahl.
class PersonenkreisRegel {
  const PersonenkreisRegel({
    required this.typ,
    required this.wert,
    this.verknuepfung = RegelVerknuepfung.oder,
  });

  final PersonenkreisRegelTyp typ;
  final String wert;

  /// Verknuepfung mit der vorherigen Regel; bei der ersten Regel ohne
  /// Bedeutung.
  final RegelVerknuepfung verknuepfung;

  PersonenkreisRegel copyWith({
    PersonenkreisRegelTyp? typ,
    String? wert,
    RegelVerknuepfung? verknuepfung,
  }) => PersonenkreisRegel(
    typ: typ ?? this.typ,
    wert: wert ?? this.wert,
    verknuepfung: verknuepfung ?? this.verknuepfung,
  );

  bool trifft(Mitglied mitglied, List<Role> aktiveRollen, DateTime heute) {
    switch (typ) {
      case PersonenkreisRegelTyp.rollenart:
        final kategorie = switch (_enumWert(Rollenart.values, wert)) {
          Rollenart.leitung => RoleCategory.leitung,
          Rollenart.amt => RoleCategory.sonstiges,
          Rollenart.mitglied => RoleCategory.mitglied,
          null => null,
        };
        return kategorie != null &&
            aktiveRollen.any((rolle) => rolle.art == kategorie);
      case PersonenkreisRegelTyp.stufe:
        final stufe = _enumWert(Stufe.values, wert);
        return stufe != null &&
            aktiveRollen.any((rolle) => rolle.stufe == stufe);
      case PersonenkreisRegelTyp.rollentyp:
        return aktiveRollen.any((rolle) => rollentypVon(rolle) == wert);
      case PersonenkreisRegelTyp.alterAb:
      case PersonenkreisRegelTyp.alterBis:
        final grenze = int.tryParse(wert);
        if (grenze == null || !mitglied.hatBekanntesGeburtsdatum) {
          return false;
        }
        final alter = MemberUtils.alterInJahren(mitglied, stichtag: heute);
        return typ == PersonenkreisRegelTyp.alterAb
            ? alter >= grenze
            : alter <= grenze;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'typ': typ.name,
    'wert': wert,
    'verknuepfung': verknuepfung.name,
  };

  static PersonenkreisRegel? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final typ = _enumWert(PersonenkreisRegelTyp.values, json['typ']);
    final wert = json['wert']?.toString();
    if (typ == null || wert == null || wert.isEmpty) {
      return null;
    }
    return PersonenkreisRegel(
      typ: typ,
      wert: wert,
      verknuepfung:
          _enumWert(RegelVerknuepfung.values, json['verknuepfung']) ??
          RegelVerknuepfung.oder,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PersonenkreisRegel &&
      other.typ == typ &&
      other.wert == wert &&
      other.verknuepfung == verknuepfung;

  @override
  int get hashCode => Object.hash(typ, wert, verknuepfung);
}

/// Wer eine Qualifikation braucht. Regeln werden als „oder“ von
/// „und“-Gruppen ausgewertet: „und“ bindet staerker. Betrachtet werden nur
/// heute aktive Rollen ohne `Group::Mitglieder::*`; wer keine solche Rolle
/// hat, gehoert nie dazu.
class Personenkreis {
  const Personenkreis(this.regeln);

  static const leitungOderAmt = Personenkreis(<PersonenkreisRegel>[
    PersonenkreisRegel(typ: PersonenkreisRegelTyp.rollenart, wert: 'leitung'),
    PersonenkreisRegel(typ: PersonenkreisRegelTyp.rollenart, wert: 'amt'),
  ]);

  static const leitung = Personenkreis(<PersonenkreisRegel>[
    PersonenkreisRegel(typ: PersonenkreisRegelTyp.rollenart, wert: 'leitung'),
  ]);

  final List<PersonenkreisRegel> regeln;

  bool enthaelt(Mitglied mitglied, {required DateTime heute}) {
    final aktiveRollen = mitglied.roles
        .where(
          (rolle) =>
              rolle.isActiveAt(heute) && !MemberUtils.istMitgliederRolle(rolle),
        )
        .toList(growable: false);
    if (aktiveRollen.isEmpty || regeln.isEmpty) {
      return false;
    }
    var gruppeTrifft = true;
    for (var i = 0; i < regeln.length; i++) {
      final regel = regeln[i];
      if (i > 0 && regel.verknuepfung == RegelVerknuepfung.oder) {
        if (gruppeTrifft) {
          return true;
        }
        gruppeTrifft = true;
      }
      gruppeTrifft =
          gruppeTrifft && regel.trifft(mitglied, aktiveRollen, heute);
    }
    return gruppeTrifft;
  }

  List<Map<String, dynamic>> toJson() =>
      regeln.map((regel) => regel.toJson()).toList(growable: false);

  static Personenkreis? fromJson(Object? json) {
    if (json is! List) {
      return null;
    }
    return Personenkreis(
      json
          .map(PersonenkreisRegel.fromJson)
          .whereType<PersonenkreisRegel>()
          .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! Personenkreis || other.regeln.length != regeln.length) {
      return false;
    }
    for (var i = 0; i < regeln.length; i++) {
      if (other.regeln[i] != regeln[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(regeln);
}

/// App-weit stabiler Bezeichner einer Rolle fuer die Regel „Rollentyp“.
String? rollentypVon(Role rolle) => rolle.type ?? rolle.resolvedLabel;

T? _enumWert<T extends Enum>(List<T> werte, Object? name) {
  for (final wert in werte) {
    if (wert.name == name) {
      return wert;
    }
  }
  return null;
}
