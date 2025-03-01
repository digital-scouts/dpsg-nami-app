class NamiGruppierungModel {
  int id;
  String name;

  NamiGruppierungModel({required this.id, required this.name});

  static fromJson(e) {
    return NamiGruppierungModel(id: e['id'], name: e['descriptor']);
  }
}
