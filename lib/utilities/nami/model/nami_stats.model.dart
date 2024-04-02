class StatsCategorie {
  final String name;
  final int count;

  StatsCategorie({required this.name, required this.count});

  factory StatsCategorie.fromJson(Map<String, dynamic> json) {
    return StatsCategorie(name: json['name'], count: json['count']);
  }
}

class NamiStatsModel {
  final int nrMitglieder;
  final List<StatsCategorie> statsCategories;

  NamiStatsModel({
    required this.nrMitglieder,
    required this.statsCategories,
  });

  factory NamiStatsModel.fromJson(Map<String, dynamic> json) {
    List<StatsCategorie> list = [];
    int count = json['data']['nrMitglieder'];
    for (var item in json['data']['statsCategories']) {
      list.add(StatsCategorie.fromJson(item));
    }
    return NamiStatsModel(nrMitglieder: count, statsCategories: list);
  }
}
