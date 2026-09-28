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

/// Löscht die Mitgliederdaten, wenn sie nicht mehr gelesen werden können.
/// Einstellungen und Login bleiben erhalten, die Daten werden neu geladen.
Future<void> deleteHiveMemberDataOnFail() async {
  await _deleteBoxesFromDisk(['members', 'taetigkeit', 'dataChanges']);
}

/// Letzter Ausweg, wenn auch die Einstellungen nicht mehr geöffnet werden
/// können: Statt eines Absturzes bei jedem Start wird neu angemeldet.
Future<void> deleteAllHiveDataOnFail() async {
  await _deleteBoxesFromDisk(_boxNames);
  // Ein unlesbarer Schlüssel wird beim nächsten [openHive] neu erzeugt
  try {
    await const FlutterSecureStorage().delete(key: 'key');
  } catch (_) {}
}

Future<void> _deleteBoxesFromDisk(List<String> boxNames) async {
  try {
    await Hive.close();
  } catch (_) {}
  for (final name in boxNames) {
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {}
  }
}

/// Der Schlüssel konnte nicht gelesen werden. Die Daten dürfen dann nicht
/// gelöscht werden, da sie nach dem Entsperren wieder lesbar sind.
class HiveKeyUnavailableException implements Exception {
  final Object cause;
  HiveKeyUnavailableException(this.cause);

  @override
  String toString() => 'HiveKeyUnavailableException: $cause';
}

const _boxNames = [
  'taetigkeit',
  'members',
  'settingsBox',
  'filterBox',
  'dataChanges',
  'satzung_db',
  'ai_chat_messages',
];

Future<void> openHive() async {
  const secureStorage = FlutterSecureStorage();
  final String? encryprionKey;
  try {
    encryprionKey = await _readEncryptionKey(secureStorage);
  } catch (e) {
    throw HiveKeyUnavailableException(e);
  }
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

/// Liest den Hive-Schlüssel. Ist der Keychain direkt nach dem Start noch nicht
/// verfügbar (z.B. gesperrtes Gerät), wird kurz erneut versucht, statt sofort
/// einen neuen Schlüssel zu erzeugen und damit alle Daten unlesbar zu machen.
Future<String?> _readEncryptionKey(FlutterSecureStorage secureStorage) async {
  final hasExistingData = await Hive.boxExists('settingsBox');
  const attempts = 3;
  for (var i = 0; i < attempts; i++) {
    try {
      final key = await secureStorage.read(key: 'key');
      if (key != null || !hasExistingData) return key;
    } catch (_) {
      if (i == attempts - 1) rethrow;
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
  return null;
}
