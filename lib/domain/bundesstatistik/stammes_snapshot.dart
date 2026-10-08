import '../taetigkeit/stufe.dart';
import 'statistik_abdeckung.dart';

/// Stammes-Snapshot fuer die bundesweite Statistik.
///
/// Entspricht dem API-Vertrag `server/spec/stammes_snapshot.md` in der
/// Schema-Version [StammesSnapshot.schemaVersion]. Nicht sicher ableitbare
/// Kennzahlen bleiben `null` und werden nicht geschaetzt.

/// Stufen-Schluessel im API-Vertrag.
const Map<Stufe, String> stufenSchluessel = <Stufe, String>{
  Stufe.biber: 'biber',
  Stufe.woelfling: 'woelflinge',
  Stufe.jungpfadfinder: 'jungpfadfinder',
  Stufe.pfadfinder: 'pfadfinder',
  Stufe.rover: 'rover',
};

Stufe? stufeFuerSchluessel(String? schluessel) {
  for (final entry in stufenSchluessel.entries) {
    if (entry.value == schluessel) {
      return entry.key;
    }
  }
  return null;
}

class GeschlechterVerteilung {
  const GeschlechterVerteilung({
    required this.gesamt,
    required this.maennlich,
    required this.weiblich,
    required this.divers,
    required this.geschlechtUnbekannt,
  });

  const GeschlechterVerteilung.leer()
    : gesamt = 0,
      maennlich = 0,
      weiblich = 0,
      divers = 0,
      geschlechtUnbekannt = 0;

  /// Nicht bekannt, z. B. eine Stufe, die bei Teilsicht nicht ganz lesbar ist.
  const GeschlechterVerteilung.unbekannt()
    : gesamt = null,
      maennlich = null,
      weiblich = null,
      divers = null,
      geschlechtUnbekannt = null;

  final int? gesamt;
  final int? maennlich;
  final int? weiblich;
  final int? divers;
  final int? geschlechtUnbekannt;

  Map<String, Object?> toJson() => <String, Object?>{
    'gesamt': gesamt,
    'maennlich': maennlich,
    'weiblich': weiblich,
    'divers': divers,
    'geschlecht_unbekannt': geschlechtUnbekannt,
  };

  factory GeschlechterVerteilung.fromJson(Map<String, dynamic>? json) =>
      GeschlechterVerteilung(
        gesamt: _toNullableInt(json?['gesamt']),
        maennlich: _toNullableInt(json?['maennlich']),
        weiblich: _toNullableInt(json?['weiblich']),
        divers: _toNullableInt(json?['divers']),
        geschlechtUnbekannt: _toNullableInt(json?['geschlecht_unbekannt']),
      );

  @override
  bool operator ==(Object other) =>
      other is GeschlechterVerteilung &&
      other.gesamt == gesamt &&
      other.maennlich == maennlich &&
      other.weiblich == weiblich &&
      other.divers == divers &&
      other.geschlechtUnbekannt == geschlechtUnbekannt;

  @override
  int get hashCode =>
      Object.hash(gesamt, maennlich, weiblich, divers, geschlechtUnbekannt);
}

class LeitendeAltersVerteilung {
  const LeitendeAltersVerteilung({
    required this.gesamt,
    required this.unter21,
    required this.von21Bis30,
    required this.von31Bis40,
    required this.von41Bis50,
    required this.von51Bis60,
    required this.ueber60,
  });

  final int? gesamt;
  final int? unter21;
  final int? von21Bis30;
  final int? von31Bis40;
  final int? von41Bis50;
  final int? von51Bis60;
  final int? ueber60;

  Map<String, Object?> toJson() => <String, Object?>{
    'gesamt': gesamt,
    'unter_21': unter21,
    'von_21_bis_30': von21Bis30,
    'von_31_bis_40': von31Bis40,
    'von_41_bis_50': von41Bis50,
    'von_51_bis_60': von51Bis60,
    'ueber_60': ueber60,
  };

  factory LeitendeAltersVerteilung.fromJson(Map<String, dynamic>? json) =>
      LeitendeAltersVerteilung(
        gesamt: _toNullableInt(json?['gesamt']),
        unter21: _toNullableInt(json?['unter_21']),
        von21Bis30: _toNullableInt(json?['von_21_bis_30']),
        von31Bis40: _toNullableInt(json?['von_31_bis_40']),
        von41Bis50: _toNullableInt(json?['von_41_bis_50']),
        von51Bis60: _toNullableInt(json?['von_51_bis_60']),
        ueber60: _toNullableInt(json?['ueber_60']),
      );

  @override
  bool operator ==(Object other) =>
      other is LeitendeAltersVerteilung &&
      other.gesamt == gesamt &&
      other.unter21 == unter21 &&
      other.von21Bis30 == von21Bis30 &&
      other.von31Bis40 == von31Bis40 &&
      other.von41Bis50 == von41Bis50 &&
      other.von51Bis60 == von51Bis60 &&
      other.ueber60 == ueber60;

  @override
  int get hashCode => Object.hash(
    gesamt,
    unter21,
    von21Bis30,
    von31Bis40,
    von41Bis50,
    von51Bis60,
    ueber60,
  );
}

/// Zaehlwerte einer Stufengruppe (Meute, Trupp, Runde ...).
///
/// Nicht abgedeckte Gruppen gehoeren nur zur Gruppenstruktur und tragen keine
/// Zaehler. Der Name wird nicht gesendet; die UI loest ihn ueber die ID auf.
class GruppenKennzahl {
  const GruppenKennzahl({
    required this.gruppenId,
    required this.stufe,
    required this.abgedeckt,
    this.mitglieder,
    this.leitende,
  });

  final int gruppenId;
  final Stufe stufe;
  final bool abgedeckt;
  final GeschlechterVerteilung? mitglieder;
  final GeschlechterVerteilung? leitende;

  Map<String, Object?> toJson() => <String, Object?>{
    'gruppe_id': gruppenId.toString(),
    'stufe': stufenSchluessel[stufe],
    'abgedeckt': abgedeckt,
    if (abgedeckt) 'mitglieder': mitglieder?.toJson(),
    if (abgedeckt) 'leitende': leitende?.toJson(),
  };

  static GruppenKennzahl? fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['gruppe_id']?.toString() ?? '');
    final stufe = stufeFuerSchluessel(json['stufe']?.toString());
    if (id == null || stufe == null) {
      return null;
    }
    final abgedeckt = json['abgedeckt'] == true;
    return GruppenKennzahl(
      gruppenId: id,
      stufe: stufe,
      abgedeckt: abgedeckt,
      mitglieder: abgedeckt
          ? GeschlechterVerteilung.fromJson(_map(json['mitglieder']))
          : null,
      leitende: abgedeckt
          ? GeschlechterVerteilung.fromJson(_map(json['leitende']))
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GruppenKennzahl &&
      other.gruppenId == gruppenId &&
      other.stufe == stufe &&
      other.abgedeckt == abgedeckt &&
      other.mitglieder == mitglieder &&
      other.leitende == leitende;

  @override
  int get hashCode =>
      Object.hash(gruppenId, stufe, abgedeckt, mitglieder, leitende);
}

class StammesKennzahlen {
  const StammesKennzahlen({
    required this.aktiveMitglieder,
    required this.biber,
    required this.woelflinge,
    required this.jungpfadfinder,
    required this.pfadfinder,
    required this.rover,
    required this.leitende,
    required this.leitendeBiber,
    required this.leitendeWoelflinge,
    required this.leitendeJungpfadfinder,
    required this.leitendePfadfinder,
    required this.leitendeRover,
    required this.nichtLeitendeErwachsene,
    this.passiveMitglieder,
    this.stammesvorstand,
    this.kuraten,
    this.abdeckung = const StatistikAbdeckung.stamm(),
    this.gruppen = const <GruppenKennzahl>[],
  });

  /// Bei Teilsicht sind alle stammweiten Werte `null` und Stufen nur bekannt,
  /// wenn alle ihre Gruppen lesbar sind.
  final StatistikAbdeckung abdeckung;

  /// Alle Stufengruppen des Stammes; Zaehler nur fuer abgedeckte Gruppen.
  final List<GruppenKennzahl> gruppen;

  /// Anzahl ordentlicher Mitgliedschaften; die Aufteilung nach Beitragsart
  /// (normal, familien-, sozialermaessigt) ist in Hitobito nicht sichtbar.
  final int? aktiveMitglieder;
  final GeschlechterVerteilung biber;
  final GeschlechterVerteilung woelflinge;
  final GeschlechterVerteilung jungpfadfinder;
  final GeschlechterVerteilung pfadfinder;
  final GeschlechterVerteilung rover;
  final LeitendeAltersVerteilung leitende;
  final GeschlechterVerteilung leitendeBiber;
  final GeschlechterVerteilung leitendeWoelflinge;
  final GeschlechterVerteilung leitendeJungpfadfinder;
  final GeschlechterVerteilung leitendePfadfinder;
  final GeschlechterVerteilung leitendeRover;
  final int? nichtLeitendeErwachsene;
  final int? passiveMitglieder;
  final int? stammesvorstand;
  final int? kuraten;

  List<GeschlechterVerteilung> get kernstufen => <GeschlechterVerteilung>[
    biber,
    woelflinge,
    jungpfadfinder,
    pfadfinder,
    rover,
  ];

  GeschlechterVerteilung stufe(Stufe stufe) => switch (stufe) {
    Stufe.biber => biber,
    Stufe.woelfling => woelflinge,
    Stufe.jungpfadfinder => jungpfadfinder,
    Stufe.pfadfinder => pfadfinder,
    _ => rover,
  };

  GeschlechterVerteilung leitendeDerStufe(Stufe stufe) => switch (stufe) {
    Stufe.biber => leitendeBiber,
    Stufe.woelfling => leitendeWoelflinge,
    Stufe.jungpfadfinder => leitendeJungpfadfinder,
    Stufe.pfadfinder => leitendePfadfinder,
    _ => leitendeRover,
  };

  List<GruppenKennzahl> get abgedeckteGruppen =>
      gruppen.where((gruppe) => gruppe.abgedeckt).toList(growable: false);

  /// Der Server verlangt mindestens eine abgedeckte Gruppe mit Mitgliedern.
  bool get istPlausibel =>
      abgedeckteGruppen.any((gruppe) => (gruppe.mitglieder?.gesamt ?? 0) > 0);

  /// Teilnahme ohne Werte: Wer teilen will, aber keine Zahlen hat (etwa als
  /// Leitung ohne lesbare Rollen), sendet nur die Gruppenstruktur. Das
  /// berechtigt zum Lesen des Bundesvergleichs, der Stamm zaehlt aber nicht als
  /// teilnehmend.
  StammesKennzahlen get alsTeilnahmeOhneWerte => StammesKennzahlen.fromJson(
    null,
    abdeckung: StatistikAbdeckung.gruppen(const <int>{}),
    gruppen: <GruppenKennzahl>[
      for (final gruppe in gruppen)
        GruppenKennzahl(
          gruppenId: gruppe.gruppenId,
          stufe: gruppe.stufe,
          abgedeckt: false,
        ),
    ],
  );

  /// Stammweite Kennzahlen (`metrics` im Snapshot). Stufenwerte bildet der
  /// Server aus den Gruppen.
  Map<String, Object?> toJson() => <String, Object?>{
    'aktive_mitglieder': <String, Object?>{
      'gesamt': aktiveMitglieder,
      'normaler_beitrag': null,
      'familienermaessigter_beitrag': null,
      'sozialermaessigter_beitrag': null,
    },
    'passive_mitglieder': passiveMitglieder,
    'leitende': leitende.toJson(),
    'nicht_leitende_erwachsene': nichtLeitendeErwachsene,
    'stammesvorstand': stammesvorstand,
    'kuraten': kuraten,
  };

  /// Liest die Kennzahlen eines gesendeten Snapshots zurueck. Stufenwerte
  /// ergeben sich aus den Gruppen, sofern alle Gruppen der Stufe abgedeckt sind.
  factory StammesKennzahlen.fromJson(
    Map<String, dynamic>? json, {
    required StatistikAbdeckung abdeckung,
    required List<GruppenKennzahl> gruppen,
  }) {
    final aktive = json?['aktive_mitglieder'];
    GeschlechterVerteilung summe(
      Stufe stufe,
      GeschlechterVerteilung? Function(GruppenKennzahl gruppe) wert,
    ) => summiereGruppen(
      gruppen.where((gruppe) => gruppe.stufe == stufe).toList(),
      wert,
    );
    return StammesKennzahlen(
      abdeckung: abdeckung,
      gruppen: gruppen,
      aktiveMitglieder: aktive is Map<String, dynamic>
          ? _toNullableInt(aktive['gesamt'])
          : null,
      passiveMitglieder: _toNullableInt(json?['passive_mitglieder']),
      biber: summe(Stufe.biber, (g) => g.mitglieder),
      woelflinge: summe(Stufe.woelfling, (g) => g.mitglieder),
      jungpfadfinder: summe(Stufe.jungpfadfinder, (g) => g.mitglieder),
      pfadfinder: summe(Stufe.pfadfinder, (g) => g.mitglieder),
      rover: summe(Stufe.rover, (g) => g.mitglieder),
      leitende: json == null
          ? const LeitendeAltersVerteilung(
              gesamt: null,
              unter21: null,
              von21Bis30: null,
              von31Bis40: null,
              von41Bis50: null,
              von51Bis60: null,
              ueber60: null,
            )
          : LeitendeAltersVerteilung.fromJson(_map(json['leitende'])),
      leitendeBiber: summe(Stufe.biber, (g) => g.leitende),
      leitendeWoelflinge: summe(Stufe.woelfling, (g) => g.leitende),
      leitendeJungpfadfinder: summe(Stufe.jungpfadfinder, (g) => g.leitende),
      leitendePfadfinder: summe(Stufe.pfadfinder, (g) => g.leitende),
      leitendeRover: summe(Stufe.rover, (g) => g.leitende),
      nichtLeitendeErwachsene: _toNullableInt(
        json?['nicht_leitende_erwachsene'],
      ),
      stammesvorstand: _toNullableInt(json?['stammesvorstand']),
      kuraten: _toNullableInt(json?['kuraten']),
    );
  }

  /// Feldweise Summe; eine nicht abgedeckte Gruppe macht die Summe unbekannt.
  static GeschlechterVerteilung summiereGruppen(
    List<GruppenKennzahl> gruppen,
    GeschlechterVerteilung? Function(GruppenKennzahl gruppe) wert,
  ) {
    final werte = <GeschlechterVerteilung>[];
    for (final gruppe in gruppen) {
      final verteilung = gruppe.abgedeckt ? wert(gruppe) : null;
      if (verteilung == null) {
        return const GeschlechterVerteilung.unbekannt();
      }
      werte.add(verteilung);
    }
    int? feld(int? Function(GeschlechterVerteilung v) auswahl) {
      var summe = 0;
      for (final verteilung in werte) {
        final teil = auswahl(verteilung);
        if (teil == null) {
          return null;
        }
        summe += teil;
      }
      return summe;
    }

    return GeschlechterVerteilung(
      gesamt: feld((v) => v.gesamt),
      maennlich: feld((v) => v.maennlich),
      weiblich: feld((v) => v.weiblich),
      divers: feld((v) => v.divers),
      geschlechtUnbekannt: feld((v) => v.geschlechtUnbekannt),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StammesKennzahlen &&
      other.abdeckung == abdeckung &&
      _listEquals(other.gruppen, gruppen) &&
      other.aktiveMitglieder == aktiveMitglieder &&
      other.biber == biber &&
      other.woelflinge == woelflinge &&
      other.jungpfadfinder == jungpfadfinder &&
      other.pfadfinder == pfadfinder &&
      other.rover == rover &&
      other.leitende == leitende &&
      other.leitendeBiber == leitendeBiber &&
      other.leitendeWoelflinge == leitendeWoelflinge &&
      other.leitendeJungpfadfinder == leitendeJungpfadfinder &&
      other.leitendePfadfinder == leitendePfadfinder &&
      other.leitendeRover == leitendeRover &&
      other.nichtLeitendeErwachsene == nichtLeitendeErwachsene &&
      other.passiveMitglieder == passiveMitglieder &&
      other.stammesvorstand == stammesvorstand &&
      other.kuraten == kuraten;

  @override
  int get hashCode => Object.hash(
    abdeckung,
    Object.hashAll(gruppen),
    aktiveMitglieder,
    Object.hashAll(kernstufen),
    leitende,
    leitendeBiber,
    leitendeWoelflinge,
    leitendeJungpfadfinder,
    leitendePfadfinder,
    leitendeRover,
    nichtLeitendeErwachsene,
    passiveMitglieder,
    stammesvorstand,
    kuraten,
  );
}

class StammesSnapshot {
  const StammesSnapshot({
    required this.stammId,
    required this.senderId,
    required this.sentAt,
    required this.sourceDataAsOf,
    required this.kennzahlen,
    this.dvId,
    this.bezirkId,
  });

  static const String schemaVersion = '2026-10-01';

  final String stammId;
  final String? dvId;
  final String? bezirkId;

  /// Installations-ID, keine Personen-ID.
  final String senderId;
  final DateTime sentAt;
  final DateTime sourceDataAsOf;
  final StammesKennzahlen kennzahlen;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': schemaVersion,
    'stamm_id': stammId,
    'dv_id': dvId,
    'bezirk_id': bezirkId,
    'sender_id': senderId,
    'sent_at': _isoMillis(sentAt),
    'source_data_as_of': _isoMillis(sourceDataAsOf),
    'abdeckung': kennzahlen.abdeckung.istStamm ? 'stamm' : 'gruppen',
    'gruppen': [for (final gruppe in kennzahlen.gruppen) gruppe.toJson()],
    'metrics': kennzahlen.abdeckung.istStamm ? kennzahlen.toJson() : null,
  };

  factory StammesSnapshot.fromJson(Map<String, dynamic> json) =>
      StammesSnapshot(
        stammId: json['stamm_id']?.toString() ?? '',
        dvId: json['dv_id']?.toString(),
        bezirkId: json['bezirk_id']?.toString(),
        senderId: json['sender_id']?.toString() ?? '',
        sentAt: DateTime.parse(json['sent_at'].toString()),
        sourceDataAsOf: DateTime.parse(json['source_data_as_of'].toString()),
        kennzahlen: _kennzahlenAusJson(json),
      );

  static StammesKennzahlen _kennzahlenAusJson(Map<String, dynamic> json) {
    final gruppen = <GruppenKennzahl>[
      for (final eintrag in (json['gruppen'] as List?) ?? const <Object?>[])
        if (eintrag is Map<String, dynamic>) ?GruppenKennzahl.fromJson(eintrag),
    ];
    final abdeckung = json['abdeckung'] == 'gruppen'
        ? StatistikAbdeckung.gruppen(
            gruppen.where((g) => g.abgedeckt).map((g) => g.gruppenId),
          )
        : const StatistikAbdeckung.stamm();
    return StammesKennzahlen.fromJson(
      abdeckung.istStamm ? _map(json['metrics']) : null,
      abdeckung: abdeckung,
      gruppen: gruppen,
    );
  }
}

/// ISO-Zeitstempel in UTC mit hoechstens Millisekunden; `toIso8601String`
/// liefert auf manchen Plattformen Mikrosekunden.
String _isoMillis(DateTime value) {
  final utc = value.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    utc.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;

int? _toNullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
