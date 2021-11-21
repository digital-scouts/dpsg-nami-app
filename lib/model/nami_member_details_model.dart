class NamiMemberDetailsModel {
  final String? jungpfadfinder;
  final String? mglType;
  final String geschlecht;
  final String staatsangehoerigkeit;
  final String? ersteTaetigkeitId;
  final String? ersteUntergliederung;
  final DateTime lastUpdated;
  final String? emailVertretungsberechtigter;
  final String? ersteTaetigkeit;
  final String? nameZusatz;
  final int id;
  final int staatsangehoerigkeitId;
  final int version;
  final bool sonst01;
  final bool sonst02;
  final String? spitzname;
  final int? landId;
  final String staatsangehoerigkeitText;
  final int gruppierungId;
  final String mglTypeId;
  final String? beitragsart;
  final String nachname;
  final DateTime eintrittsdatum;
  final String? rover;
  final String region;
  final String status;
  final String? konfession;
  final String? fixBeitrag;
  final int? konfessionId;
  final bool zeitschriftenversand;
  final String? pfadfinder;
  final String? telefon3;
  final int geschlechtId;
  final String land;
  final String? email;
  final String? telefon1;
  final String? woelfling;
  final String? telefon2;
  final String strasse;
  final String vorname;
  final int mitgliedsNummer;
  final String gruppierung;
  final DateTime? austrittsDatum;
  final String ort;
  final int? ersteUntergliederungId;
  final bool wiederverwendenFlag;
  final int regionId;
  final DateTime geburtsDatum;
  final String? stufe;
  final String? genericField1;
  final String? genericField2;
  final String? telefax;
  final int? beitragsartId;
  final String plz;

  NamiMemberDetailsModel({
    required this.jungpfadfinder,
    required this.mglType,
    required this.geschlecht,
    required this.staatsangehoerigkeit,
    required this.ersteTaetigkeitId,
    required this.ersteUntergliederung,
    required this.lastUpdated,
    required this.emailVertretungsberechtigter,
    required this.ersteTaetigkeit,
    required this.nameZusatz,
    required this.id,
    required this.staatsangehoerigkeitId,
    required this.version,
    required this.sonst01,
    required this.sonst02,
    required this.spitzname,
    required this.landId,
    required this.staatsangehoerigkeitText,
    required this.gruppierungId,
    required this.mglTypeId,
    required this.beitragsart,
    required this.nachname,
    required this.eintrittsdatum,
    required this.rover,
    required this.region,
    required this.status,
    required this.konfession,
    required this.fixBeitrag,
    required this.konfessionId,
    required this.zeitschriftenversand,
    required this.pfadfinder,
    required this.telefon3,
    required this.geschlechtId,
    required this.land,
    required this.email,
    required this.telefon1,
    required this.woelfling,
    required this.telefon2,
    required this.strasse,
    required this.vorname,
    required this.mitgliedsNummer,
    required this.gruppierung,
    required this.austrittsDatum,
    required this.ort,
    required this.ersteUntergliederungId,
    required this.wiederverwendenFlag,
    required this.regionId,
    required this.geburtsDatum,
    required this.stufe,
    required this.genericField1,
    required this.genericField2,
    required this.telefax,
    required this.beitragsartId,
    required this.plz,
  });

  factory NamiMemberDetailsModel.fromJson(Map<String, dynamic> json) {
    return NamiMemberDetailsModel(
      jungpfadfinder: json['jungpfadfinder'],
      mglType: json['mglType'],
      geschlecht: json['geschlecht'],
      staatsangehoerigkeit: json['staatsangehoerigkeit'],
      ersteTaetigkeitId: json['ersteTaetigkeitId'],
      ersteUntergliederung: json['ersteUntergliederung'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      emailVertretungsberechtigter: json['emailVertretungsberechtigter'],
      ersteTaetigkeit: json['ersteTaetigkeit'],
      nameZusatz: json['nameZusatz'],
      id: json['id'],
      staatsangehoerigkeitId: json['staatsangehoerigkeitId'],
      version: json['version'],
      sonst01: json['sonst01'],
      sonst02: json['sonst02'],
      spitzname: json['spitzname'],
      landId: json['landId'],
      staatsangehoerigkeitText: json['staatsangehoerigkeitText'],
      gruppierungId: json['gruppierungId'],
      mglTypeId: json['mglTypeId'],
      beitragsart: json['beitragsart'],
      nachname: json['nachname'],
      eintrittsdatum: DateTime.parse(json['eintrittsdatum']),
      rover: json['rover'],
      region: json['region'],
      status: json['status'],
      konfession: json['konfession'],
      fixBeitrag: json['fixBeitrag'],
      konfessionId: json['konfessionId'],
      zeitschriftenversand: json['zeitschriftenversand'],
      pfadfinder: json['pfadfinder'],
      telefon3: json['telefon3'],
      geschlechtId: json['geschlechtId'],
      land: json['land'],
      email: json['email'],
      telefon1: json['telefon1'],
      woelfling: json['woelfling'],
      telefon2: json['telefon2'],
      strasse: json['strasse'],
      vorname: json['vorname'],
      mitgliedsNummer: json['mitgliedsNummer'],
      gruppierung: json['gruppierung'],
      austrittsDatum: json['austrittsDatum'] == ''
          ? null
          : DateTime.parse(json['austrittsDatum']),
      ort: json['ort'],
      ersteUntergliederungId: json['ersteUntergliederungId'],
      wiederverwendenFlag: json['wiederverwendenFlag'],
      regionId: json['regionId'],
      geburtsDatum: DateTime.parse(json['geburtsDatum']),
      stufe: json['stufe'],
      genericField1: json['genericField1'],
      genericField2: json['genericField2'],
      telefax: json['telefax'],
      beitragsartId: json['beitragsartId'],
      plz: json['plz'],
    );
  }
}
