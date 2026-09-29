import 'dart:convert';
import 'dart:io';

/// Kopiert die Fixture der App-Version 0.2.8 in [targetDirectory] und
/// liefert die zugehoerigen Secure-Storage-Werte.
Future<Map<String, String>> installLegacy028Fixture(
  Directory targetDirectory,
) async {
  final fixtureDirectory = Directory('test/fixtures/legacy_0_2_8');
  for (final entity in fixtureDirectory.listSync()) {
    if (entity is! File) {
      continue;
    }
    final name = entity.uri.pathSegments.last;
    if (name.endsWith('.hive') || name.endsWith('.log')) {
      await entity.copy('${targetDirectory.path}/$name');
    }
  }

  final secureStorageJson =
      jsonDecode(
            await File(
              '${fixtureDirectory.path}/secure_storage.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  return secureStorageJson.map((key, value) => MapEntry(key, value as String));
}

/// Dateinamen, die nach dem Legacy-Cleanup nicht mehr existieren duerfen.
const List<String> legacy028FileNames = <String>[
  'taetigkeit.hive',
  'members.hive',
  'settingsbox.hive',
  'filterbox.hive',
  'datachanges.hive',
  'satzung_db.hive',
  'ai_chat_messages.hive',
  'prod.log',
];
