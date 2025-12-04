import 'package:hive_ce/hive.dart';
import 'package:nami/ignore_deprecated_utilities/hive/hive_service.dart';
import 'package:nami/ignore_deprecated_utilities/hive/settings.dart';

void logout() {
  //loaded Data
  hiveService.memberBox.clear();
  deleteGruppierungId();
  deleteGruppierungName();
  setRechte([]);

  setStammheim('');
  setFavouriteList([]);
  // login data
  deleteNamiApiCookie();
  deleteNamiLoginId();
  deleteLoggedInUserId();
  deleteNamiPassword();

  // other Stuff
  deleteLastLoginCheck();
  deleteLastNamiSyncTry();
  deleteLastNamiSync();
}

Future<void> closeHive() async {
  await Hive.close();
}

Future<void> deleteHiveMemberDataOnFail() async {
  await Hive.openBox('members');
  await Hive.box('members').clear();

  await Hive.openBox('taetigkeit');
  await Hive.box('taetigkeit').clear();

  await Hive.openBox('dataChanges');
  await Hive.box('dataChanges').clear();

  Hive.close();
}
