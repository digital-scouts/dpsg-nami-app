import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/services/sensitive_storage_service.dart';

void main() {
  late Directory tempDir;
  late SensitiveStorageService service;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    tempDir = await Directory.systemTemp.createTemp('sensitive_storage_');
    Hive.init(tempDir.path);
    service = SensitiveStorageService();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('oeffnet dieselbe verschluesselte Box parallel nur einmal', () async {
    final boxes = await Future.wait<Box<String>>(<Future<Box<String>>>[
      service.openEncryptedStringBox('hitobito_arbeitskontext_box'),
      service.openEncryptedStringBox('hitobito_arbeitskontext_box'),
    ]);

    expect(boxes[0], same(boxes[1]));
    expect(Hive.isBoxOpen('hitobito_arbeitskontext_box'), isTrue);
  });

  test('kann Box nach purge erneut verschluesselt oeffnen', () async {
    final firstBox = await service.openEncryptedStringBox(
      'hitobito_arbeitskontext_box',
    );
    await firstBox.put('arbeitskontext_read_model_v1', '{}');

    await service.purgeSensitiveData();

    final reopenedBox = await service.openEncryptedStringBox(
      'hitobito_arbeitskontext_box',
    );

    expect(reopenedBox.isOpen, isTrue);
    expect(reopenedBox.get('arbeitskontext_read_model_v1'), isNull);
  });
}
