import 'package:hive/hive.dart';

// flutter packages pub run build_runner build

part 'taetigkeit.g.dart';

@HiveType(typeId: 2)
class Taetigkeit {
  @HiveField(0)
  late int id;

  @HiveField(1)
  late String taetigkeit;

  @HiveField(2)
  late DateTime aktivVon;

  @HiveField(3)
  late DateTime? aktivBis;

  @HiveField(4)
  late DateTime anlagedatum;

  @HiveField(5)
  late String? untergliederung;

  @HiveField(6)
  late String gruppierung;

  @HiveField(7)
  late String? berechtigteGruppe;

  @HiveField(8)
  late String? berechtigteUntergruppen;
}
