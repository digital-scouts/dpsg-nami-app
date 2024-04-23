// flutter packages pub run build_runner build
class NamiMemberAusbildungModel {
  late int id;

  late DateTime datum;

  late String veranstalter;

  late String name;

  late String baustein;

  String? descriptor;

  NamiMemberAusbildungModel._({
    required this.id,
    required this.name,
    required this.veranstalter,
    required this.baustein,
    required this.datum,
  });
  factory NamiMemberAusbildungModel.fromJson(Map<String, dynamic> json) {
    String preText = 'entries_';
    return NamiMemberAusbildungModel._(
      baustein: json['${preText}baustein'],
      veranstalter: json['${preText}veranstalter'],
      id: json['${preText}id'],
      datum: DateTime.tryParse(json['${preText}vstgTag']) ?? DateTime(0),
      name: json['${preText}vstgName'],
    );
  }
}
