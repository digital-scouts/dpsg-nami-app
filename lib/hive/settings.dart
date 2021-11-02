import 'package:hive/hive.dart';

// flutter packages pub run build_runner build

part 'settings.g.dart';

@HiveType(typeId: 0)
class Settings {
  @HiveField(0)
  late String namiApiToken;

  @HiveField(1)
  late int loginId;

  @HiveField(2)
  late String password;
}
