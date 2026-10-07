import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import 'app_secure_storage.dart';

/// Ein Vorgang wollte eine sensible Box oeffnen, obwohl keine Sitzung offen
/// ist, etwa nach Logout, Datenablauf oder Benutzerwechsel.
class SensitiveSessionEndedException implements Exception {
  const SensitiveSessionEndedException(this.boxName);

  final String boxName;

  @override
  String toString() =>
      'SensitiveSessionEndedException: keine offene Sitzung fuer $boxName';
}

class SensitiveStorageService {
  SensitiveStorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? appSecureStorage;

  static const String secureMetaBoxName = 'hitobito_secure_meta_box';
  static const String _encryptionKeyStorageKey = 'hitobito_hive_encryption_key';
  static const String _principalKey = 'current_principal';
  static const String _lastSensitiveSyncAtKey = 'last_sensitive_sync_at';
  static const String _lastSensitiveSyncAttemptAtKey =
      'last_sensitive_sync_attempt_at';
  static const String _lastBackgroundedAtKey = 'last_backgrounded_at';
  static const String _hitobitoOauthClientIdKey =
      'hitobito_oauth_client_id_override';
  static const String _hitobitoOauthClientSecretKey =
      'hitobito_oauth_client_secret_override';

  static const List<String> sensitiveBoxNames = <String>[
    secureMetaBoxName,
    'hitobito_arbeitskontext_box',
    'hitobito_pending_person_updates_box',
    'hitobito_profile_box',
    'hitobito_roles_box',
    'hitobito_mailing_lists_box',
    'hitobito_people_box',
    'nami_ai_chat_history_box',
  ];
  static final Map<String, Future<Box<String>>> _openingStringBoxes =
      <String, Future<Box<String>>>{};

  // Sensible Boxen sind nur zwischen beginSession() und endSession()
  // erreichbar. Der Zustand ist statisch wie Hive selbst, weil ein
  // Moduswechsel eine neue Instanz erzeugt.
  static bool _sessionOpen = false;
  static Future<List<int>>? _encryptionKey;

  final FlutterSecureStorage _secureStorage;

  bool get isSessionOpen => _sessionOpen;

  /// Oeffnet die Sitzung fuer sensible Boxen. Nur in einer offenen Sitzung
  /// entsteht bei Bedarf ein neuer Verschluesselungsschluessel.
  void beginSession() {
    _sessionOpen = true;
  }

  /// Schliesst die Sitzung sofort. Laufende Vorgaenge koennen danach keine
  /// sensible Box mehr oeffnen und keinen Schluessel mehr erzeugen.
  void endSession() {
    _sessionOpen = false;
  }

  /// Ob von einer frueheren Sitzung sensible Daten auf dem Geraet liegen.
  /// Oeffnet nichts, damit die Pruefung selbst keine Datei anlegt.
  Future<bool> hasLocalSensitiveData() {
    return Hive.boxExists(secureMetaBoxName);
  }

  Future<Box<String>> openSecureMetaBox() async {
    return openEncryptedStringBox(secureMetaBoxName);
  }

  Future<Box<String>> openEncryptedStringBox(String boxName) async {
    _ensureSessionOpen(boxName);
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }

    final existingOpen = _openingStringBoxes[boxName];
    if (existingOpen != null) {
      final box = await existingOpen;
      _ensureSessionOpen(boxName);
      return box;
    }

    late final Future<Box<String>> openFuture;
    openFuture = _openEncryptedStringBoxInternal(boxName);
    _openingStringBoxes[boxName] = openFuture;

    try {
      final box = await openFuture;
      _ensureSessionOpen(boxName);
      return box;
    } finally {
      if (identical(_openingStringBoxes[boxName], openFuture)) {
        _openingStringBoxes.remove(boxName);
      }
    }
  }

  Future<Box<String>> _openEncryptedStringBoxInternal(String boxName) async {
    final encryptionKey = await _loadEncryptionKey();
    _ensureSessionOpen(boxName);
    return Hive.openBox<String>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }

  // Ein gemeinsames Future verhindert, dass parallele Erstoeffnungen zwei
  // verschiedene Schluessel erzeugen.
  Future<List<int>> _loadEncryptionKey() async {
    final keyFuture = _encryptionKey ??= _loadOrCreateEncryptionKey();
    try {
      return await keyFuture;
    } catch (_) {
      if (identical(_encryptionKey, keyFuture)) {
        _encryptionKey = null;
      }
      rethrow;
    }
  }

  void _ensureSessionOpen(String boxName) {
    if (!_sessionOpen) {
      throw SensitiveSessionEndedException(boxName);
    }
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

  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? timestamp) async {
    final box = await openSecureMetaBox();
    if (timestamp == null) {
      await box.delete(_lastSensitiveSyncAttemptAtKey);
      return;
    }

    await box.put(_lastSensitiveSyncAttemptAtKey, timestamp.toIso8601String());
  }

  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async {
    final box = await openSecureMetaBox();
    final raw = box.get(_lastSensitiveSyncAttemptAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastBackgroundedAt(DateTime? timestamp) async {
    final box = await openSecureMetaBox();
    if (timestamp == null) {
      await box.delete(_lastBackgroundedAtKey);
      return;
    }

    await box.put(_lastBackgroundedAtKey, timestamp.toIso8601String());
  }

  Future<DateTime?> loadLastBackgroundedAt() async {
    final box = await openSecureMetaBox();
    final raw = box.get(_lastBackgroundedAtKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  // Der OAuth-Override ist Geraetekonfiguration ohne Personenbezug. Er liegt
  // direkt im Secure Storage, damit er auch ohne Sitzung lesbar ist.
  Future<void> saveHitobitoOauthClientId(String? clientId) async {
    if (clientId == null || clientId.isEmpty) {
      await _secureStorage.delete(key: _hitobitoOauthClientIdKey);
      return;
    }
    await _secureStorage.writeReplacing(
      key: _hitobitoOauthClientIdKey,
      value: clientId,
    );
  }

  Future<String?> loadHitobitoOauthClientId() {
    return _secureStorage.read(key: _hitobitoOauthClientIdKey);
  }

  Future<void> saveHitobitoOauthClientSecret(String? clientSecret) async {
    if (clientSecret == null || clientSecret.isEmpty) {
      await _secureStorage.delete(key: _hitobitoOauthClientSecretKey);
      return;
    }
    await _secureStorage.writeReplacing(
      key: _hitobitoOauthClientSecretKey,
      value: clientSecret,
    );
  }

  Future<String?> loadHitobitoOauthClientSecret() {
    return _secureStorage.read(key: _hitobitoOauthClientSecretKey);
  }

  Future<void> clearHitobitoOauthOverride() async {
    await _secureStorage.delete(key: _hitobitoOauthClientIdKey);
    await _secureStorage.delete(key: _hitobitoOauthClientSecretKey);
  }

  Future<void> purgeSensitiveData() async {
    endSession();
    final pendingKey = _encryptionKey;
    _encryptionKey = null;

    // Laufende Oeffnungen erst abwarten, sonst legen sie die Box nach dem
    // Loeschen mit dem alten Schluessel wieder an.
    final pendingOpens = _openingStringBoxes.values.toList();
    _openingStringBoxes.clear();
    for (final pending in <Future<Object?>>[...pendingOpens, ?pendingKey]) {
      try {
        await pending;
      } catch (_) {
        // Ein abgebrochener Vorgang ist hier erwartet.
      }
    }

    await _deleteSensitiveBoxes();
    await _secureStorage.delete(key: _encryptionKeyStorageKey);
    await clearHitobitoOauthOverride();
  }

  Future<void> _deleteSensitiveBoxes() async {
    for (final boxName in sensitiveBoxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<String>(boxName).close();
      }

      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {
        // Ignorieren: Box kann auf frischen Instanzen fehlen.
      }
    }
  }

  Future<List<int>> _loadOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _encryptionKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }

    // Ohne passenden Schluessel sind vorhandene Boxen ohnehin unlesbar,
    // etwa nach einer Wiederherstellung auf einem anderen Geraet.
    await _deleteSensitiveBoxes();

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.writeReplacing(
      key: _encryptionKeyStorageKey,
      value: base64Encode(bytes),
    );
    return bytes;
  }

  @visibleForTesting
  static void resetForTest() {
    _sessionOpen = false;
    _encryptionKey = null;
    _openingStringBoxes.clear();
  }
}
