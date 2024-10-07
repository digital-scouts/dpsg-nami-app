class NamiMemberDetailsModel {
  String? mglType;
  String? ersteUntergliederung;
  String? ersteTaetigkeitId;
  DateTime? lastUpdated;
  String? emailVertretungsberechtigter;
  String? ersteTaetigkeit;
  String? nameZusatz;
  int? id;
  int staatsangehoerigkeitId;
  int version;
  String? spitzname;
  int? landId;
  String? staatsangehoerigkeitText;
  int gruppierungId;
  String? mglTypeId;
  String nachname;
  DateTime eintrittsdatum;
  String? status;
  String? fixBeitrag;
  int? konfessionId;
  bool zeitschriftenversand;
  String? telefon3;
  int geschlechtId;
  String? email;
  String? telefon1;
  String? telefon2;
  String strasse;
  String vorname;
  int? mitgliedsNummer;
  String? gruppierung;
  DateTime? austrittsDatum;
  String ort;
  int? ersteUntergliederungId;
  bool wiederverwendenFlag;
  int? regionId;
  DateTime geburtsDatum;
  String? stufe;
  String? telefax;
  int? beitragsartId;
  String plz;

  NamiMemberDetailsModel({
    this.mglType,
    this.ersteTaetigkeitId,
    this.ersteUntergliederung,
    this.lastUpdated,
    required this.emailVertretungsberechtigter,
    this.ersteTaetigkeit,
    this.nameZusatz,
    this.id,
    required this.staatsangehoerigkeitId,
    required this.version,
    this.spitzname,
    required this.landId,
    this.staatsangehoerigkeitText,
    required this.gruppierungId,
    this.mglTypeId,
    required this.nachname,
    required this.eintrittsdatum,
    this.status,
    this.fixBeitrag,
    required this.konfessionId,
    required this.zeitschriftenversand,
    required this.telefon3,
    required this.geschlechtId,
    required this.email,
    required this.telefon1,
    required this.telefon2,
    required this.strasse,
    required this.vorname,
    this.mitgliedsNummer,
    this.gruppierung,
    this.austrittsDatum,
    required this.ort,
    this.ersteUntergliederungId,
    required this.wiederverwendenFlag,
    required this.regionId,
    required this.geburtsDatum,
    this.stufe,
    this.telefax,
    required this.beitragsartId,
    required this.plz,
  });

  factory NamiMemberDetailsModel.fromJson(Map<String, dynamic> json) {
    return NamiMemberDetailsModel(
      mglType: json['mglType'],
      ersteTaetigkeitId: json['ersteTaetigkeitId'],
      ersteUntergliederung: json['ersteUntergliederung'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      emailVertretungsberechtigter: json['emailVertretungsberechtigter'],
      ersteTaetigkeit: json['ersteTaetigkeit'],
      nameZusatz: json['nameZusatz'],
      id: json['id'],
      staatsangehoerigkeitId: json['staatsangehoerigkeitId'],
      version: json['version'],
      spitzname: json['spitzname'],
      landId: json['landId'],
      staatsangehoerigkeitText: json['staatsangehoerigkeitText'],
      gruppierungId: json['gruppierungId'],
      mglTypeId: json['mglTypeId'],
      nachname: json['nachname'],
      eintrittsdatum: json['eintrittsdatum'].length > 5
          ? DateTime.parse(json['eintrittsdatum'])
          : DateTime(1599),
      status: json['status'],
      fixBeitrag: json['fixBeitrag'],
      konfessionId: json['konfessionId'],
      zeitschriftenversand: json['zeitschriftenversand'],
      telefon3: json['telefon3'],
      geschlechtId: json['geschlechtId'],
      email: json['email'],
      telefon1: json['telefon1'],
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
      telefax: json['telefax'],
      beitragsartId: json['beitragsartId'],
      plz: json['plz'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'vorname': vorname,
      'nachname': nachname,
      'geschlechtId': geschlechtId,
      'staatsangehoerigkeitId': staatsangehoerigkeitId,
      'konfessionId': konfessionId,
      'geburtsDatum': geburtsDatum.toIso8601String(),
      'eintrittsdatum': eintrittsdatum.toIso8601String(),
      'austrittsDatum': austrittsDatum?.toIso8601String(),
      'beitragsartId': beitragsartId,
      'mglTypeId': mglTypeId,
      'ersteTaetigkeitId': ersteTaetigkeitId,
      'ersteUntergliederungId': ersteUntergliederungId,
      'zeitschriftenversand': zeitschriftenversand,
      'wiederverwendenFlag': wiederverwendenFlag,
      'strasse': strasse,
      'plz': plz,
      'ort': ort,
      'regionId': regionId,
      'landId': landId,
      'telefon1': telefon1,
      'telefon2': telefon2,
      'telefon3': telefon3,
      'email': email,
      'emailVertretungsberechtigter': emailVertretungsberechtigter,
      'gruppierungId': gruppierungId,
      'version': version,
    };
  }
}
