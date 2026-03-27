import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

class SensitiveStorageService {
  SensitiveStorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String secureMetaBoxName = 'hitobito_secure_meta_box';
  static const String _encryptionKeyStorageKey = 'hitobito_hive_encryption_key';
  static const String _principalKey = 'current_principal';
  static const String _lastSensitiveSyncAtKey = 'last_sensitive_sync_at';

  static const List<String> sensitiveBoxNames = <String>[
    secureMetaBoxName,
    'hitobito_people_box',
    'hitobito_roles_box',
    'hitobito_mailing_lists_box',
  ];
  static final Map<String, Future<Box<String>>> _openingStringBoxes =
      <String, Future<Box<String>>>{};

  final FlutterSecureStorage _secureStorage;

  Future<Box<String>> openSecureMetaBox() async {
    return openEncryptedStringBox(secureMetaBoxName);
  }

  Future<Box<String>> openEncryptedStringBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }

    final existingOpen = _openingStringBoxes[boxName];
    if (existingOpen != null) {
      return existingOpen;
    }

    late final Future<Box<String>> openFuture;
    openFuture = _openEncryptedStringBoxInternal(boxName);
    _openingStringBoxes[boxName] = openFuture;

    try {
      return await openFuture;
    } finally {
      if (identical(_openingStringBoxes[boxName], openFuture)) {
        _openingStringBoxes.remove(boxName);
      }
    }
  }

  Future<Box<String>> _openEncryptedStringBoxInternal(String boxName) async {
    final encryptionKey = await _loadOrCreateEncryptionKey();
    return Hive.openBox<String>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  Future<void> savePrincipal(String? principal) async {
    final box = await openSecureMetaBox();
    if (principal == null || principal.isEmpty) {
      await box.delete(_principalKey);
      return;
    }
    await box.put(_principalKey, principal);
  }

  Future<String?> loadPrincipal() async {
    final box = await openSecureMetaBox();
    return box.get(_principalKey);
  }

  Future<void> saveLastSensitiveSyncAt(DateTime timestamp) async {
    final box = await openSecureMetaBox();
    await box.put(_lastSensitiveSyncAtKey, timestamp.toIso8601String());
  }

  Future<DateTime?> loadLastSensitiveSyncAt() async {
    final box = await openSecureMetaBox();
    final raw = box.get(_lastSensitiveSyncAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> purgeSensitiveData() async {
    for (final boxName in sensitiveBoxNames) {
      _openingStringBoxes.remove(boxName);
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<String>(boxName).close();
      }

      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {
        // Ignorieren: Box kann auf frischen Instanzen fehlen.
      }
    }

    await _secureStorage.delete(key: _encryptionKeyStorageKey);
  }

  Future<List<int>> _loadOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _encryptionKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(
      key: _encryptionKeyStorageKey,
      value: base64Encode(bytes),
    );
    return bytes;
  }
}
