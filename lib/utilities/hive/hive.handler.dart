import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/settings.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'dart:convert';

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

Future<void> registerAdapter() async {
  try {
    Hive.registerAdapter(TaetigkeitAdapter());
    Hive.registerAdapter(MitgliedAdapter());
  } catch (_) {}
}

Future<void> closeHive() async {
  await Hive.close();
}

Future<void> openHive() async {
  const secureStorage = FlutterSecureStorage();
  var encryprionKey = await secureStorage.read(key: 'key');
  if (encryprionKey == null) {
    final key = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'key',
      value: base64UrlEncode(key),
    );
  }
  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  await Future.wait([
    Hive.openBox<Taetigkeit>('taetigkeit',
        encryptionCipher: HiveAesCipher(encryptionKey)),
    Hive.openBox<Mitglied>('members',
        encryptionCipher: HiveAesCipher(encryptionKey)),
    Hive.openBox('settingsBox', encryptionCipher: HiveAesCipher(encryptionKey))
  ]);
  return;
}
