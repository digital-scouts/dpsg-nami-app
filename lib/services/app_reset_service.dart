import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth/auth_session_repository.dart';
import 'sensitive_storage_service.dart';

typedef ResetPreferencesProvider = Future<SharedPreferences> Function();
typedef ResetLogFileProvider = Future<File> Function();
typedef ResetLogsCleaner = Future<void> Function();

class AppResetService {
  AppResetService({
    required AuthSessionRepository authSessionRepository,
    required SensitiveStorageService sensitiveStorageService,
    ResetPreferencesProvider? preferencesProvider,
    ResetLogFileProvider? logFileProvider,
    ResetLogsCleaner? clearLogs,
    ResetLogsCleaner? clearHitobitoTrafficLogs,
    Future<void> Function()? clearMapCache,
    Future<void> Function()? clearLegacyData,
    Future<void> Function()? clearInstallationCredentials,
    Future<void> Function()? cancelScheduledNotifications,
  }) : _authSessionRepository = authSessionRepository,
       _sensitiveStorageService = sensitiveStorageService,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _logFileProvider = logFileProvider,
       _clearLogs = clearLogs,
       _clearHitobitoTrafficLogs = clearHitobitoTrafficLogs,
       _clearMapCache = clearMapCache,
       _clearLegacyData = clearLegacyData,
       _clearInstallationCredentials = clearInstallationCredentials,
       _cancelScheduledNotifications = cancelScheduledNotifications;

  static const List<String> plainHiveBoxes = <String>[
    'notifications_box',
    'notifications_meta_box',
    'notifications_ack_box',
  ];

  final AuthSessionRepository _authSessionRepository;
  final SensitiveStorageService _sensitiveStorageService;
  final ResetPreferencesProvider _preferencesProvider;
  final ResetLogFileProvider? _logFileProvider;
  final ResetLogsCleaner? _clearLogs;
  final ResetLogsCleaner? _clearHitobitoTrafficLogs;
  final Future<void> Function()? _clearMapCache;
  final Future<void> Function()? _clearLegacyData;
  final Future<void> Function()? _clearInstallationCredentials;
  final Future<void> Function()? _cancelScheduledNotifications;

  /// Löscht alle lokalen Daten. Jeder Schritt läuft für sich: Scheitert
  /// einer, laufen die übrigen trotzdem, damit möglichst wenig zurückbleibt.
  /// Das Ergebnis nennt die gescheiterten Schritte.
  Future<AppResetErgebnis> resetAllData({bool clearLogFile = true}) async {
    final fehlgeschlagen = <String>[];
    Future<void> schritt(String name, Future<void> Function() aktion) async {
      try {
        await aktion();
      } catch (_) {
        fehlgeschlagen.add(name);
      }
    }

    await schritt('preferences', () async {
      final prefs = await _preferencesProvider();
      await prefs.clear();
    });
    await schritt('session', _authSessionRepository.clear);
    await schritt(
      'sensitive_data',
      _sensitiveStorageService.purgeSensitiveData,
    );
    // Geplante Erinnerungen (Datenablauf, Qualifikationen, Geburtstage)
    // enthalten Namen und duerfen den Reset nicht ueberdauern.
    final cancelScheduledNotifications = _cancelScheduledNotifications;
    if (cancelScheduledNotifications != null) {
      await schritt('notifications', cancelScheduledNotifications);
    }
    // Nach einem Reset tritt die App gegenueber dem Statistikserver als neue
    // Installation auf.
    final clearInstallationCredentials = _clearInstallationCredentials;
    if (clearInstallationCredentials != null) {
      await schritt('installation_credentials', clearInstallationCredentials);
    }
    final clearLegacyData = _clearLegacyData;
    if (clearLegacyData != null) {
      await schritt('legacy_data', clearLegacyData);
    }
    final clearMapCache = _clearMapCache;
    if (clearMapCache != null) {
      await schritt('map_cache', clearMapCache);
    }

    for (final boxName in plainHiveBoxes) {
      await schritt('hive_$boxName', () async {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }
        try {
          await Hive.deleteBoxFromDisk(boxName);
        } catch (_) {
          // Box existiert auf frischen Instanzen eventuell nicht.
        }
      });
    }

    if (clearLogFile) {
      await schritt('logs', _clearLogFiles);
    }
    return AppResetErgebnis(fehlgeschlagen: List.unmodifiable(fehlgeschlagen));
  }

  Future<void> _clearLogFiles() async {
    final clearLogs = _clearLogs;
    if (clearLogs != null) {
      await clearLogs();
    } else {
      final logFileProvider = _logFileProvider;
      if (logFileProvider != null) {
        final file = await logFileProvider();
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    final clearHitobitoTrafficLogs = _clearHitobitoTrafficLogs;
    if (clearHitobitoTrafficLogs != null) {
      await clearHitobitoTrafficLogs();
    }
  }
}

/// Ausgang eines App-Resets.
class AppResetErgebnis {
  const AppResetErgebnis({this.fehlgeschlagen = const <String>[]});

  /// Technische Namen der Schritte, die nicht gelöscht werden konnten.
  final List<String> fehlgeschlagen;

  bool get vollstaendig => fehlgeschlagen.isEmpty;
}
