import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/custom_group.dart';
import 'package:nami/utilities/hive/data_changes.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

// Optional eigene Exceptions
class HiveInitException implements Exception {
  final String message;
  HiveInitException(this.message);
}

// Globale Zugriffspunkte
late Box<Taetigkeit> taetigkeitBox;
late Box<Mitglied> mitgliedBox;
late Box dataChangesBox;
late Box settingsBox;
late Box filterBox;
late Box<Map> satzungDbBox;
late Box<Map> aiChatMessagesBox;

Future<void> initHiveBoxes() async {
  await Hive.initFlutter();
  await _registerAdapters();

  final encryptionKey = await _loadEncryptionKey();

  // Boxen öffnen mit Typprüfung
  taetigkeitBox = await Hive.openBox<Taetigkeit>(
    'taetigkeit',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  mitgliedBox = await Hive.openBox<Mitglied>(
    'members',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  settingsBox = await Hive.openBox(
    'settingsBox',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  filterBox = await Hive.openBox(
    'filterBox',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  dataChangesBox = await Hive.openBox<DataChange>(
    'dataChanges',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  satzungDbBox = await Hive.openBox<Map>(
    'satzung_db',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );

  aiChatMessagesBox = await Hive.openBox<Map>(
    'ai_chat_messages',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
}

Future<void> _registerAdapters() async {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(DataChangeAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MitgliedAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaetigkeitAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AusbildungAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(CustomGroupAdapter());
  // Weitere Adapter hier registrieren
}

Future<List<int>> _loadEncryptionKey() async {
  const secureStorage = FlutterSecureStorage();
  const keyName = 'key';

  var encodedKey = await secureStorage.read(key: keyName);
  if (encodedKey == null) {
    final newKey = Hive.generateSecureKey();
    encodedKey = base64UrlEncode(newKey);
    await secureStorage.write(key: keyName, value: encodedKey);
  }
  return base64Url.decode(encodedKey);
}
