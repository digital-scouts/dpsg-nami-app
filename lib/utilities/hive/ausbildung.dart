import 'package:hive/hive.dart';
part 'ausbildung.g.dart';

// flutter packages pub run build_runner build
@HiveType(typeId: 3)
class Ausbildung {
  @HiveField(0)
  late int id;

  @HiveField(1)
  late DateTime datum;

  @HiveField(2)
  late String veranstalter;

  @HiveField(3)
  late String name;

  @HiveField(4)
  late String baustein;

  @HiveField(5)
  late String? descriptor;
}
