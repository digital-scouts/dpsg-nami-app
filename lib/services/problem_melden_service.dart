import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/hilfe/problem_meldung.dart';
import '../domain/rechtliches/anbieter.dart';
import 'logger_service.dart';
import 'teilen_ordner.dart';

/// Öffnet eine vorbefüllte Mail an den Entwickler mit den Antworten aus
/// „Problem melden“ und dem App-Protokoll der letzten 24 Stunden im
/// Anhang. Gesendet wird erst im Mailprogramm.
class ProblemMeldenService {
  ProblemMeldenService({
    required LoggerService logger,
    Future<void> Function(Email email)? senden,
    Future<Directory> Function()? temp,
    Future<String> Function()? geraet,
    DateTime Function()? nowProvider,
  }) : _logger = logger,
       _senden = senden ?? FlutterEmailSender.send,
       _temp = temp ?? getTemporaryDirectory,
       _geraet = geraet ?? _geraetStandard,
       _now = nowProvider ?? DateTime.now;

  static const Duration zeitraum = Duration(hours: 24);

  final LoggerService _logger;
  final Future<void> Function(Email email) _senden;
  final Future<Directory> Function() _temp;
  final Future<String> Function() _geraet;
  final DateTime Function() _now;

  /// Wirft, wenn kein Mailprogramm die Mail annimmt.
  Future<void> melden(
    ProblemMeldung meldung,
    String Function(String key) t,
  ) async {
    final anhang = await _protokollDatei();
    await _senden(
      Email(
        recipients: const [Anbieter.email],
        subject: meldung.betreff(t),
        body: meldung.text(t, geraet: await _geraet()),
        attachmentPaths: [?anhang?.path],
      ),
    );
  }

  /// App-Protokoll der letzten 24 Stunden im Teilen-Ordner, der beim Start
  /// und beim Logout geleert wird (A-127); `null`, wenn es leer ist.
  Future<File?> _protokollDatei() async {
    final grenze = _now().subtract(zeitraum);
    final eintraege = AppLogEntry.parseAll(await _logger.readLogs());
    final zeilen = [
      for (final eintrag in eintraege)
        if (!eintrag.timestamp.isBefore(grenze)) ...eintrag.rawLines,
    ];
    if (zeilen.isEmpty) {
      return null;
    }
    final stempel = DateFormat('yyyy-MM-dd_HHmm').format(_now());
    final ordner = await TeilenOrdner.verzeichnis(temp: _temp);
    final datei = File('${ordner.path}/nami-app-log_$stempel.log');
    await datei.writeAsString('${zeilen.join('\n')}\n');
    return datei;
  }

  static Future<String> _geraetStandard() async {
    final info = await PackageInfo.fromPlatform();
    return 'App ${info.version} (${info.buildNumber}) · '
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}
