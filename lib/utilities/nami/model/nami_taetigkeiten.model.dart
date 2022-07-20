class NamiMemberTaetigkeitenModel {
  final String taetigkeit;
  final int id;
  final DateTime aktivVon;
  final DateTime? aktivBis;
  final DateTime anlagedatum;
  final String? untergliederung;
  final String gruppierung;
  final String? berechtigteGruppe; //Schreiben/Lesen
  final String? berechtigteUntergruppen;

  NamiMemberTaetigkeitenModel({
    required this.taetigkeit,
    required this.id,
    required this.aktivVon,
    required this.aktivBis,
    required this.anlagedatum,
    required this.untergliederung,
    required this.gruppierung,
    required this.berechtigteGruppe,
    required this.berechtigteUntergruppen,
  });

  factory NamiMemberTaetigkeitenModel.fromJson(Map<String, dynamic> json) {
    return NamiMemberTaetigkeitenModel(
      taetigkeit: json['entries_taetigkeit'],
      id: json['id'],
      aktivVon: DateTime.parse(json['entries_aktivVon']),
      aktivBis: json['entries_aktivBis'].length >= 10
          ? DateTime.parse(json['entries_aktivBis'])
          : null,
      anlagedatum: json['entries_anlagedatum'].length >= 10
          ? DateTime.parse(json['entries_anlagedatum'])
          : DateTime.parse(json['entries_aktivVon']),
      untergliederung: json['entries_untergliederung'],
      gruppierung: json['entries_gruppierung'],
      berechtigteGruppe: json['entries_caeaGroup'].isNotEmpty
          ? json['entries_caeaGroup']
          : null,
      berechtigteUntergruppen: json['entries_caeaGroupForGf'].isNotEmpty
          ? json['entries_caeaGroupForGf']
          : null,
    );
  }
}
