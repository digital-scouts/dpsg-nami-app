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
    Future<void> Function()? clearMapCache,
  }) : _authSessionRepository = authSessionRepository,
       _sensitiveStorageService = sensitiveStorageService,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _logFileProvider = logFileProvider,
       _clearLogs = clearLogs,
       _clearMapCache = clearMapCache;

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
  final Future<void> Function()? _clearMapCache;

  Future<void> resetAllData({bool clearLogFile = true}) async {
    final prefs = await _preferencesProvider();
    await prefs.clear();

    await _authSessionRepository.clear();
    await _sensitiveStorageService.purgeSensitiveData();
    final clearMapCache = _clearMapCache;
    if (clearMapCache != null) {
      await clearMapCache();
    }

    for (final boxName in plainHiveBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }

      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {
        // Box existiert auf frischen Instanzen eventuell nicht.
      }
    }

    if (!clearLogFile) {
      return;
    }

    final clearLogs = _clearLogs;
    if (clearLogs != null) {
      await clearLogs();
      return;
    }

    final logFileProvider = _logFileProvider;
    if (logFileProvider == null) {
      return;
    }

    final file = await logFileProvider();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
