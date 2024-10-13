import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(AusbildungAdapter());
    registerAdapter(MitgliedAdapter());
    registerAdapter(TaetigkeitAdapter());
  }
}
