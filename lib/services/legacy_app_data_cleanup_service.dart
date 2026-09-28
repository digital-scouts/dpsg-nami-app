import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

typedef LegacyCleanupPreferencesProvider = Future<SharedPreferences> Function();
typedef LegacyCleanupDirectoryProvider = Future<Directory> Function();
typedef LegacyCleanupAction = Future<void> Function();

/// Entfernt beim ersten Start nach einem Update von 0.2.x alle Daten der
/// alten App-Version. Eine Migration ist nicht vorgesehen: Die alten Daten
/// stammen aus einem anderen Quellsystem, nach dem Update ist ein neuer Login
/// noetig und alle Daten werden neu geladen.
///
/// Muss nach `Hive.init(...)` und vor dem Oeffnen der eigenen Boxen laufen.
class LegacyAppDataCleanupService {
  LegacyAppDataCleanupService({
    required LegacyCleanupDirectoryProvider documentsDirectoryProvider,
    FlutterSecureStorage? secureStorage,
    LegacyCleanupPreferencesProvider? preferencesProvider,
    LegacyCleanupAction? cancelScheduledNotifications,
    LegacyCleanupAction? deleteLegacyMapStore,
    LoggerService? logger,
  }) : _documentsDirectoryProvider = documentsDirectoryProvider,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _cancelScheduledNotifications = cancelScheduledNotifications,
       _deleteLegacyMapStore = deleteLegacyMapStore,
       _logger = logger;

  static const String cleanupDoneKey = 'startup.legacy_cleanup_v1_done';

  /// Hive-Boxen der App-Version 0.2.x (verschluesselt, mit alten Adaptern).
  static const List<String> legacyHiveBoxes = <String>[
    'taetigkeit',
    'members',
    'settingsBox',
    'filterBox',
    'dataChanges',
    'satzung_db',
    'ai_chat_messages',
    'ausbildung',
  ];

  /// Secure-Storage-Keys der App-Version 0.2.x (Hive-Schluessel, Log-Salt).
  static const List<String> legacySecureStorageKeys = <String>['key', 'salt'];

  /// Logdateien der App-Version 0.2.x im Documents-Verzeichnis.
  static const List<String> legacyLogFiles = <String>['prod.log', 'dev.log'];

  /// FMTC-Store der App-Version 0.2.x.
  static const String legacyMapStoreName = 'mapStore';

  final LegacyCleanupDirectoryProvider _documentsDirectoryProvider;
  final FlutterSecureStorage _secureStorage;
  final LegacyCleanupPreferencesProvider _preferencesProvider;
  final LegacyCleanupAction? _cancelScheduledNotifications;
  final LegacyCleanupAction? _deleteLegacyMapStore;
  final LoggerService? _logger;

  /// Fuehrt den Cleanup einmalig aus, wenn Spuren von 0.2.x gefunden werden.
  /// Liefert `true`, wenn aufgeraeumt wurde.
  Future<bool> runIfNeeded() async {
    try {
      final prefs = await _preferencesProvider();
      if (prefs.getBool(cleanupDoneKey) ?? false) {
        return false;
      }

      if (!await hasLegacyData()) {
        await prefs.setBool(cleanupDoneKey, true);
        return false;
      }

      await deleteLegacyData();
      await prefs.setBool(cleanupDoneKey, true);
      await _logger?.logInfo(
        'legacy_cleanup',
        'Daten der App-Version 0.2.x entfernt',
      );
      return true;
    } catch (error, stackTrace) {
      await _logger?.logError(
        'legacy_cleanup',
        'Legacy-Cleanup fehlgeschlagen',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> hasLegacyData() async {
    for (final boxName in legacyHiveBoxes) {
      if (await _guard(() => Hive.boxExists(boxName)) ?? false) {
        return true;
      }
    }
    final legacyKey = await _guard(
      () => _secureStorage.read(key: legacySecureStorageKeys.first),
    );
    return legacyKey != null;
  }

  /// Entfernt alle bekannten Daten von 0.2.x. Jeder Schritt laeuft
  /// unabhaengig, damit ein einzelner Fehler den Start nicht blockiert.
  Future<void> deleteLegacyData() async {
    for (final boxName in legacyHiveBoxes) {
      // Loescht die Dateien, ohne die Box zu oeffnen (alte Adapter fehlen).
      await _guard(() => Hive.deleteBoxFromDisk(boxName));
    }

    for (final key in legacySecureStorageKeys) {
      await _guard(() => _secureStorage.delete(key: key));
    }

    final documentsDirectory = await _guard(_documentsDirectoryProvider);
    if (documentsDirectory != null) {
      for (final fileName in legacyLogFiles) {
        await _guard(() async {
          final file = File('${documentsDirectory.path}/$fileName');
          if (await file.exists()) {
            await file.delete();
          }
        });
      }
    }

    // 0.2.x hat jaehrlich wiederkehrende Geburtstagsbenachrichtigungen
    // geplant, die sonst nach dem Update weiter ausgeloest wuerden.
    final cancelScheduledNotifications = _cancelScheduledNotifications;
    if (cancelScheduledNotifications != null) {
      await _guard(cancelScheduledNotifications);
    }

    final deleteLegacyMapStore = _deleteLegacyMapStore;
    if (deleteLegacyMapStore != null) {
      await _guard(deleteLegacyMapStore);
    }
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      await _logger?.logWarn(
        'legacy_cleanup',
        'Legacy-Cleanup-Schritt fehlgeschlagen: $error',
      );
      return null;
    }
  }
}
