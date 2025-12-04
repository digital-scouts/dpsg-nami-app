import 'package:hive_ce/hive.dart';

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

  bool isLeitung() {
    if (taetigkeit.contains('LeiterIn')) {
      return true;
    }
    return false;
  }

  bool isActive() {
    DateTime now = DateTime.now();
    if (aktivVon.isBefore(now) &&
        (aktivBis == null || aktivBis!.isAfter(now))) {
      return true;
    }
    return false;
  }

  bool isFutureTaetigkeit() {
    DateTime now = DateTime.now();
    if (aktivVon.isAfter(now)) {
      return true;
    }
    return false;
  }

  bool endsInFuture() {
    DateTime now = DateTime.now();
    if (aktivBis == null || aktivBis!.isAfter(now)) {
      return true;
    }
    return false;
  }
}
