import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/services/sensitive_storage_service.dart';

void main() {
  late Directory tempDir;
  late SensitiveStorageService service;
  late _ZaehlenderSecureStorage secureStorage;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SensitiveStorageService.resetForTest();
    tempDir = await Directory.systemTemp.createTemp('sensitive_storage_');
    Hive.init(tempDir.path);
    secureStorage = _ZaehlenderSecureStorage();
    service = SensitiveStorageService(secureStorage: secureStorage);
  });

  tearDown(() async {
    SensitiveStorageService.resetForTest();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('oeffnet dieselbe verschluesselte Box parallel nur einmal', () async {
    service.beginSession();
    final boxes = await Future.wait<Box<String>>(<Future<Box<String>>>[
      service.openEncryptedStringBox('hitobito_arbeitskontext_box'),
      service.openEncryptedStringBox('hitobito_profile_box'),
      service.openEncryptedStringBox('hitobito_arbeitskontext_box'),
    ]);

    expect(boxes[0], same(boxes[2]));
    expect(Hive.isBoxOpen('hitobito_arbeitskontext_box'), isTrue);
    // Parallele Erstoeffnungen teilen sich einen Schluessel.
    expect(secureStorage.keyWrites, 1);
  });

  test('ohne Sitzung entsteht weder Box noch Schluessel', () async {
    await expectLater(
      service.openEncryptedStringBox('hitobito_pending_person_updates_box'),
      throwsA(isA<SensitiveSessionEndedException>()),
    );

    expect(
      await Hive.boxExists('hitobito_pending_person_updates_box'),
      isFalse,
    );
    expect(secureStorage.keyWrites, 0);
  });

  test('purge beendet die Sitzung und loescht Boxen und Schluessel', () async {
    service.beginSession();
    final box = await service.openEncryptedStringBox(
      'hitobito_arbeitskontext_box',
    );
    await box.put('arbeitskontext_read_model_v1', '{}');

    await service.purgeSensitiveData();

    expect(service.isSessionOpen, isFalse);
    expect(await Hive.boxExists('hitobito_arbeitskontext_box'), isFalse);
    expect(
      await secureStorage.read(key: 'hitobito_hive_encryption_key'),
      isNull,
    );
    await expectLater(
      service.openEncryptedStringBox('hitobito_arbeitskontext_box'),
      throwsA(isA<SensitiveSessionEndedException>()),
    );
  });

  test('neue Sitzung nach purge beginnt mit leerer Box', () async {
    service.beginSession();
    final box = await service.openEncryptedStringBox(
      'hitobito_arbeitskontext_box',
    );
    await box.put('arbeitskontext_read_model_v1', '{}');
    await service.purgeSensitiveData();

    service.beginSession();
    final reopened = await service.openEncryptedStringBox(
      'hitobito_arbeitskontext_box',
    );

    expect(reopened.get('arbeitskontext_read_model_v1'), isNull);
  });

  test('laufende Oeffnung legt die Box nach purge nicht wieder an', () async {
    service.beginSession();
    secureStorage.blockReads();
    final opening = service.openEncryptedStringBox(
      'hitobito_arbeitskontext_box',
    );
    // Der Vorgang wartet jetzt auf den Schluessel; das Abmelden faellt in
    // dieses Fenster.
    final purge = service.purgeSensitiveData();
    secureStorage.releaseReads();

    await expectLater(opening, throwsA(isA<SensitiveSessionEndedException>()));
    await purge;

    expect(await Hive.boxExists('hitobito_arbeitskontext_box'), isFalse);
    expect(
      await secureStorage.read(key: 'hitobito_hive_encryption_key'),
      isNull,
    );
  });

  test('Pruefung auf lokale Daten legt keine Datei an', () async {
    expect(await service.hasLocalSensitiveData(), isFalse);
    expect(
      await Hive.boxExists(SensitiveStorageService.secureMetaBoxName),
      isFalse,
    );

    service.beginSession();
    await service.savePrincipal('person-1');

    expect(await service.hasLocalSensitiveData(), isTrue);
  });

  test('OAuth-Override ist ohne Sitzung les- und schreibbar', () async {
    await service.saveHitobitoOauthClientId('client');
    await service.saveHitobitoOauthClientSecret('secret');

    expect(await service.loadHitobitoOauthClientId(), 'client');
    expect(await service.loadHitobitoOauthClientSecret(), 'secret');
    expect(
      await Hive.boxExists(SensitiveStorageService.secureMetaBoxName),
      isFalse,
    );
    expect(secureStorage.keyWrites, 0);
  });
}

/// Secure Storage im Speicher, der Schreibzugriffe auf den Hive-Schluessel
/// zaehlt und Lesezugriffe gezielt anhalten kann.
class _ZaehlenderSecureStorage extends FlutterSecureStorage {
  _ZaehlenderSecureStorage();

  final Map<String, String> _values = <String, String>{};
  int keyWrites = 0;
  Completer<void>? _readGate;

  void blockReads() {
    _readGate = Completer<void>();
  }

  void releaseReads() {
    _readGate?.complete();
    _readGate = null;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final gate = _readGate;
    if (gate != null) {
      await gate.future;
    }
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == 'hitobito_hive_encryption_key') {
      keyWrites += 1;
    }
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}
