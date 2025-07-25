import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/hive/data_changes.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

import 'mitglied.dart';

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

Future<void> registerAdapter() async {
  try {
    Hive.registerAdapter(TaetigkeitAdapter());
    Hive.registerAdapter(AusbildungAdapter());
    Hive.registerAdapter(MitgliedAdapter());
    Hive.registerAdapter(DataChangeAdapter());
    Hive.registerAdapter(CustomGroupAdapter());
  } catch (_) {}
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

Future<void> openHive() async {
  const secureStorage = FlutterSecureStorage();
  var encryprionKey = await secureStorage.read(key: 'key');
  if (encryprionKey == null) {
    final key = Hive.generateSecureKey();
    await secureStorage.write(key: 'key', value: base64UrlEncode(key));
  }
  final encryptionKey = base64Url.decode(
    (await secureStorage.read(key: 'key'))!,
  );

  await Future.wait([
    Hive.openBox<Taetigkeit>(
      'taetigkeit',
      encryptionCipher: HiveAesCipher(encryptionKey),
    ),
    Hive.openBox<Mitglied>(
      'members',
      encryptionCipher: HiveAesCipher(encryptionKey),
    ),
    Hive.openBox('settingsBox', encryptionCipher: HiveAesCipher(encryptionKey)),
    Hive.openBox('filterBox', encryptionCipher: HiveAesCipher(encryptionKey)),
    Hive.openBox<DataChange>(
      'dataChanges',
      encryptionCipher: HiveAesCipher(encryptionKey),
    ),
    Hive.openBox<Map>(
      'satzung_db',
      encryptionCipher: HiveAesCipher(encryptionKey),
    ),
    Hive.openBox<Map>(
      'ai_chat_messages',
      encryptionCipher: HiveAesCipher(encryptionKey),
    ),
  ]);
  return;
}
