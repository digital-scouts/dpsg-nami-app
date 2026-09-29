/// Stammes-Snapshot fuer die bundesweite Statistik.
///
/// Entspricht dem API-Vertrag `server/spec/stammes_snapshot.md` in der
/// Schema-Version [StammesSnapshot.schemaVersion]. Nicht sicher ableitbare
/// Kennzahlen bleiben `null` und werden nicht geschaetzt.
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
  });

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

  /// Der Server verlangt mindestens eine Kernstufe mit Mitgliedern.
  bool get istPlausibel => kernstufen.any((stufe) => (stufe.gesamt ?? 0) > 0);

  Map<String, Object?> toJson() => <String, Object?>{
    'aktive_mitglieder': <String, Object?>{
      'gesamt': aktiveMitglieder,
      'normaler_beitrag': null,
      'familienermaessigter_beitrag': null,
      'sozialermaessigter_beitrag': null,
    },
    'passive_mitglieder': passiveMitglieder,
    'biber': biber.toJson(),
    'woelflinge': woelflinge.toJson(),
    'jungpfadfinder': jungpfadfinder.toJson(),
    'pfadfinder': pfadfinder.toJson(),
    'rover': rover.toJson(),
    'leitende': leitende.toJson(),
    'leitende_biber': leitendeBiber.toJson(),
    'leitende_woelflinge': leitendeWoelflinge.toJson(),
    'leitende_jungpfadfinder': leitendeJungpfadfinder.toJson(),
    'leitende_pfadfinder': leitendePfadfinder.toJson(),
    'leitende_rover': leitendeRover.toJson(),
    'nicht_leitende_erwachsene': nichtLeitendeErwachsene,
    'stammesvorstand': stammesvorstand,
    'kuraten': kuraten,
  };

  factory StammesKennzahlen.fromJson(Map<String, dynamic> json) {
    final aktive = json['aktive_mitglieder'];
    return StammesKennzahlen(
      aktiveMitglieder: aktive is Map<String, dynamic>
          ? _toNullableInt(aktive['gesamt'])
          : null,
      passiveMitglieder: _toNullableInt(json['passive_mitglieder']),
      biber: GeschlechterVerteilung.fromJson(_map(json['biber'])),
      woelflinge: GeschlechterVerteilung.fromJson(_map(json['woelflinge'])),
      jungpfadfinder: GeschlechterVerteilung.fromJson(
        _map(json['jungpfadfinder']),
      ),
      pfadfinder: GeschlechterVerteilung.fromJson(_map(json['pfadfinder'])),
      rover: GeschlechterVerteilung.fromJson(_map(json['rover'])),
      leitende: LeitendeAltersVerteilung.fromJson(_map(json['leitende'])),
      leitendeBiber: GeschlechterVerteilung.fromJson(
        _map(json['leitende_biber']),
      ),
      leitendeWoelflinge: GeschlechterVerteilung.fromJson(
        _map(json['leitende_woelflinge']),
      ),
      leitendeJungpfadfinder: GeschlechterVerteilung.fromJson(
        _map(json['leitende_jungpfadfinder']),
      ),
      leitendePfadfinder: GeschlechterVerteilung.fromJson(
        _map(json['leitende_pfadfinder']),
      ),
      leitendeRover: GeschlechterVerteilung.fromJson(
        _map(json['leitende_rover']),
      ),
      nichtLeitendeErwachsene: _toNullableInt(
        json['nicht_leitende_erwachsene'],
      ),
      stammesvorstand: _toNullableInt(json['stammesvorstand']),
      kuraten: _toNullableInt(json['kuraten']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StammesKennzahlen &&
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

  static const String schemaVersion = '2026-04-01';

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
    'sent_at': sentAt.toUtc().toIso8601String(),
    'source_data_as_of': sourceDataAsOf.toUtc().toIso8601String(),
    'metrics': kennzahlen.toJson(),
  };

  factory StammesSnapshot.fromJson(Map<String, dynamic> json) =>
      StammesSnapshot(
        stammId: json['stamm_id']?.toString() ?? '',
        dvId: json['dv_id']?.toString(),
        bezirkId: json['bezirk_id']?.toString(),
        senderId: json['sender_id']?.toString() ?? '',
        sentAt: DateTime.parse(json['sent_at'].toString()),
        sourceDataAsOf: DateTime.parse(json['source_data_as_of'].toString()),
        kennzahlen: StammesKennzahlen.fromJson(_map(json['metrics']) ?? {}),
      );
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
