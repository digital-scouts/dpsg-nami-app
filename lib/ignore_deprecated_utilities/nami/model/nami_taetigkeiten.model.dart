class NamiMemberTaetigkeitenModel {
  final String taetigkeit;
  final int? taetigkeitId;
  final int id;
  final DateTime aktivVon;
  final DateTime? aktivBis;
  final DateTime anlagedatum;
  final String? untergliederung;
  final int? untergliederungId;
  final String gruppierung;
  final int? gruppierungId;
  final String? berechtigteGruppe; //Schreiben/Lesen
  final String? berechtigteUntergruppen;
  final int? caeaGroupId;
  final String? caeaGroupForGfId;

  NamiMemberTaetigkeitenModel({
    required this.taetigkeit,
    this.taetigkeitId,
    required this.id,
    required this.aktivVon,
    required this.aktivBis,
    required this.anlagedatum,
    required this.untergliederung,
    this.untergliederungId,
    required this.gruppierung,
    this.gruppierungId,
    required this.berechtigteGruppe,
    required this.berechtigteUntergruppen,
    this.caeaGroupId,
    this.caeaGroupForGfId,
  });

  factory NamiMemberTaetigkeitenModel.fromJson(
    Map<String, dynamic> json,
    bool needPreText,
  ) {
    String preText = needPreText ? 'entries_' : '';
    return NamiMemberTaetigkeitenModel(
      taetigkeit: json['${preText}taetigkeit'],
      taetigkeitId: json['taetigkeitId'],
      id: json['id'],
      aktivVon: DateTime.parse(json['${preText}aktivVon']),
      aktivBis: json['${preText}aktivBis'].length >= 10
          ? DateTime.parse(json['${preText}aktivBis'])
          : null,
      anlagedatum: json['${preText}anlagedatum'].length >= 10
          ? DateTime.parse(json['${preText}anlagedatum'])
          : DateTime.parse(json['${preText}aktivVon']),
      untergliederung: json['${preText}untergliederung'],
      untergliederungId: json['untergliederungId'],
      gruppierung: json['${preText}gruppierung'],
      gruppierungId: json['gruppierungId'],
      berechtigteGruppe: json['${preText}caeaGroup'].isNotEmpty
          ? json['${preText}caeaGroup']
          : null,
      berechtigteUntergruppen: json['${preText}caeaGroupForGf'].isNotEmpty
          ? json['${preText}caeaGroupForGf']
          : null,
      caeaGroupForGfId: json['caeaGroupForGfId'],
      caeaGroupId: json['caeaGroupId'],
    );
  }
}
