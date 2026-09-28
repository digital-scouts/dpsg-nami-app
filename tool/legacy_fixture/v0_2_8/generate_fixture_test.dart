// Wird nur in einem Worktree von v0.2.8 ausgefuehrt, siehe
// tool/legacy_fixture/generate_0_2_8_fixture.sh.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'legacy_seed.dart';

void main() {
  test('erzeugt Hive-Fixture der App-Version 0.2.8', () async {
    final outputPath = Platform.environment['LEGACY_FIXTURE_OUT'];
    if (outputPath == null || outputPath.isEmpty) {
      fail('LEGACY_FIXTURE_OUT ist nicht gesetzt.');
    }

    final outputDir = Directory(outputPath);
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await outputDir.create(recursive: true);

    FlutterSecureStorage.setMockInitialValues({});
    const secureStorage = FlutterSecureStorage();
    // Wie initLogger() in 0.2.8, ohne dessen Plugin-Abhaengigkeiten.
    await secureStorage.write(key: 'salt', value: '424242');

    Hive.init(outputDir.path);
    await seedLegacyData();
    await Hive.close();

    await File('${outputDir.path}/prod.log').writeAsString(
      '<log time="2026-05-01T12:00:00.000" level="info">Fixture</log>\n',
    );

    final secureStorageValues = <String, String?>{
      'key': await secureStorage.read(key: 'key'),
      'salt': await secureStorage.read(key: 'salt'),
    };
    await File('${outputDir.path}/secure_storage.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(secureStorageValues),
    );

    for (final lockFile in outputDir.listSync().where(
      (entity) => entity.path.endsWith('.lock'),
    )) {
      await lockFile.delete();
    }
  });
}
