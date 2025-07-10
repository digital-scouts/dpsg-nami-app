class NamiGruppierungModel {
  int id;
  String name;

  NamiGruppierungModel({required this.id, required this.name});

  static NamiGruppierungModel fromJson(dynamic e) {
    return NamiGruppierungModel(id: e['id'], name: e['descriptor']);
  }
}
