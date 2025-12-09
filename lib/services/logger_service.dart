import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/settings/app_settings_repository.dart';

typedef WiredashEventHook =
    Future<void> Function(String name, Map<String, Object?> properties);

class LoggerService {
  final AppSettingsRepository settingsRepository;
  final GlobalKey<NavigatorState> navigatorKey;
  final WiredashEventHook? wiredashEventHook;
  final Future<File> Function()? logFileProvider;

  LoggerService({
    required this.settingsRepository,
    required this.navigatorKey,
    this.wiredashEventHook,
    this.logFileProvider,
  });

  Future<File> _defaultLogFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/app.log');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<File> _logFile() async => logFileProvider != null
      ? await logFileProvider!()
      : await _defaultLogFile();
  Future<File> getLogFile() async => _logFile();

  Future<void> log(String service, String message) async {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final line = '[$ts][$service] $message\n';
    if (kDebugMode) {
      // ignore: avoid_print
      print(line.trim());
    }
    final file = await _logFile();
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Future<void> trackEvent(String name, Map<String, Object?> properties) async {
    final settings = await settingsRepository.load();

    if (!settings.analyticsEnabled) {
      // Telemetrie aus: keine Weitergabe an Wiredash
      return;
    }
    if (wiredashEventHook != null) {
      await wiredashEventHook!(name, properties);
    }
  }

  Future<void> trackAndLog(
    String service,
    String name,
    Map<String, Object?> properties,
  ) async {
    await log(service, '$name props:${properties.toString()}');
    await trackEvent(name, properties);
  }
}
