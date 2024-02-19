import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/settings.dart';

import 'mitglied.dart';

void logout() {
  //loaded Data
  Hive.box<Mitglied>('members').clear();
  deleteGruppierungId();

  // login data
  deleteNamiApiCookie();
  deleteNamiLoginId();
  deleteNamiPassword();

  // other Stuff
  deleteLastLoginCheck();
  deleteLastNamiSync();
}
