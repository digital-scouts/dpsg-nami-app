import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/app_localizations.dart';
import 'benachrichtigungs_berechtigung.dart';
import 'logger_service.dart';
import 'lokale_mitteilungen.dart';

/// Erinnert um 9 Uhr 7, 3, 2 und 1 Tag vor dem Datenablauf an die erneute
/// Anmeldung. Jede Mitteilung nennt die dann noch verbleibende Tageszahl.
class DataExpiryNotificationService {
  DataExpiryNotificationService({
    required LoggerService logger,
    FlutterLocalNotificationsPlugin? plugin,
    LokaleMitteilungen? mitteilungen,
    DateTime Function()? jetzt,
  }) : _logger = logger,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _jetzt = jetzt ?? DateTime.now {
    _mitteilungen =
        mitteilungen ??
        PluginLokaleMitteilungen(
          kanalId: 'data_expiry_reminder',
          plugin: _plugin,
          importance: Importance.high,
          priority: Priority.high,
        );
  }

  /// Reservierter Bereich; geplant werden hoechstens [erinnerungsTage].
  static const idErste = 94031;
  static const idLetzte = 94039;
  static const erinnerungsTage = <int>{7, 3, 2, 1};
  static const stunde = 9;

  final LoggerService _logger;
  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _jetzt;
  late final LokaleMitteilungen _mitteilungen;
  Future<void>? _initialisierung;
  Future<void> _laufend = Future<void>.value();

  /// Initialisiert nur das Plugin. Rechte fragt allein
  /// [BenachrichtigungsBerechtigung] an; ohne Erlaubnis zeigt das System die
  /// Erinnerung nicht. Gleichzeitige Aufrufe beim Start teilen sich einen Lauf.
  Future<void> initialize() =>
      _initialisierung ??= _mitteilungen.initialisieren();

  /// Entfernt alle geplanten und angezeigten Benachrichtigungen der App,
  /// ohne dafuer Berechtigungen anzufragen.
  Future<void> cancelAll() {
    return _plugin.cancelAll();
  }

  /// Plant die Erinnerungen bis zum Datenablauf [ablauf]. Ohne [ablauf]
  /// (nichts faellig, abgemeldet) oder bei ausgeschalteten Mitteilungen werden
  /// sie entfernt.
  Future<void> updateExpiryReminder({
    required DateTime? ablauf,
    required bool pushErlaubt,
    required String sprache,
  }) {
    _laufend = _laufend.then(
      (_) =>
          _aktualisiere(
            ablauf: ablauf,
            pushErlaubt: pushErlaubt,
            sprache: sprache,
          ).catchError((Object fehler, StackTrace stack) {
            unawaited(
              _logger.logWarn(
                'notifications',
                'Ablauf-Erinnerung fehlgeschlagen: $fehler\n$stack',
              ),
            );
          }),
    );
    return _laufend;
  }

  /// Zeitpunkte der Erinnerungen: 9 Uhr an den Tagen, an denen noch
  /// [erinnerungsTage] Tage bis [ablauf] bleiben. Sie liegen auch weit in der
  /// Zukunft, damit die Warnung ohne erneutes Oeffnen der App kommt.
  List<DateTime> zeitpunkte(DateTime ablauf, DateTime jetzt) {
    final ergebnis = <DateTime>[];
    final von = DateTime(ablauf.year, ablauf.month, ablauf.day - 8);
    for (var tag = 0; tag <= 8; tag++) {
      final zeitpunkt = DateTime(von.year, von.month, von.day + tag, stunde);
      if (zeitpunkt.isAfter(jetzt) &&
          zeitpunkt.isBefore(ablauf) &&
          erinnerungsTage.contains(tageBis(ablauf, zeitpunkt))) {
        ergebnis.add(zeitpunkt);
      }
    }
    return ergebnis;
  }

  /// Verbleibende Tage zum Zeitpunkt der Mitteilung, mindestens 1.
  static int tageBis(DateTime ablauf, DateTime zeitpunkt) {
    final rest = ablauf.difference(zeitpunkt);
    return rest.inHours <= 24 ? 1 : (rest.inHours / 24).ceil();
  }

  Future<void> _aktualisiere({
    required DateTime? ablauf,
    required bool pushErlaubt,
    required String sprache,
  }) async {
    await initialize();
    final jetzt = _jetzt();
    final plan = ablauf == null || !pushErlaubt
        ? const <DateTime>[]
        : zeitpunkte(ablauf, jetzt);
    if (plan.isEmpty) {
      await _mitteilungen.abbrechenBereich(idErste, idLetzte);
      return;
    }

    final t = AppLocalizations(Locale(sprache));
    for (var i = 0; i < plan.length; i++) {
      final tage = tageBis(ablauf!, plan[i]);
      await _mitteilungen.planen(
        id: idErste + i,
        titel: t.t('ablauf_push_titel'),
        text: tage == 1
            ? t.t('ablauf_push_text_eins')
            : t.t('ablauf_push_text_mehr', {'n': tage}),
        zeitpunkt: plan[i],
        kanalName: t.t('ablauf_push_kanal'),
      );
    }
    await _mitteilungen.abbrechenAb(idErste + plan.length, idLetzte);
    await _logger.logInfo(
      'notifications',
      'Ablauf-Erinnerungen geplant (anzahl=${plan.length})',
    );
  }
}
