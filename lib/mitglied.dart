import 'package:hive/hive.dart';

part 'mitglied.g.dart';

@HiveType(typeId: 0)
class Mitglied {
  @HiveField(0)
  late String vorname;

  @HiveField(1)
  late String nachname;
}
