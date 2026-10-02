import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_daten;
import 'package:timezone/timezone.dart' as tz;

import '../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import '../domain/qualifikation/qualifikations_einstellungen.dart';
import '../l10n/app_localizations.dart';
import 'logger_service.dart';

/// Schmale Schnittstelle zum Benachrichtigungs-Plugin, damit sich die
/// Planung ohne Plattform testen laesst.
abstract class QualifikationsMitteilungen {
  Future<void> initialisieren();

  /// Fragt die Berechtigung an; erst aufrufen, wenn wirklich etwas geplant
  /// wird.
  Future<void> berechtigungAnfragen();

  Future<List<int>> geplanteIds();

  Future<void> abbrechen(int id);

  Future<void> planen({
    required int id,
    required String titel,
    required String text,
    required DateTime zeitpunkt,
    required String kanalName,
  });
}

class PluginQualifikationsMitteilungen implements QualifikationsMitteilungen {
  PluginQualifikationsMitteilungen({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialisiert = false;

  @override
  Future<void> initialisieren() async {
    if (_initialisiert) {
      return;
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
    tz_daten.initializeTimeZones();
    _initialisiert = true;
  }

  @override
  Future<void> berechtigungAnfragen() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<List<int>> geplanteIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((anfrage) => anfrage.id)
          .toList();

  @override
  Future<void> abbrechen(int id) => _plugin.cancel(id);

  @override
  Future<void> planen({
    required int id,
    required String titel,
    required String text,
    required DateTime zeitpunkt,
    required String kanalName,
  }) {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'qualifikationen',
        kanalName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
    // Der lokale Zeitpunkt wird als Instant uebergeben; eine lokale Zeitzone
    // braucht das Plugin dafuer nicht.
    return _plugin.zonedSchedule(
      id,
      titel,
      text,
      tz.TZDateTime.from(zeitpunkt, tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

/// Plant Erinnerungen an ablaufende Qualifikationen nach jedem Sync und
/// jeder Einstellungsaenderung neu. Nutzt einen eigenen ID-Bereich und raeumt
/// nur diesen, damit andere Erinnerungen (Datenablauf) bestehen bleiben.
class QualifikationsErinnerungService {
  QualifikationsErinnerungService({
    required LoggerService logger,
    QualifikationsMitteilungen? mitteilungen,
    DateTime Function()? jetzt,
    PlaneQualifikationsErinnerungenUseCase planer =
        const PlaneQualifikationsErinnerungenUseCase(),
  }) : _logger = logger,
       _mitteilungen = mitteilungen ?? PluginQualifikationsMitteilungen(),
       _jetzt = jetzt ?? DateTime.now,
       _planer = planer;

  static const idErste = 95000;
  static const idLetzte = 95099;
  static const _prefsSchluessel = 'qualifikationsErinnerungenGeplant';

  final LoggerService _logger;
  final QualifikationsMitteilungen _mitteilungen;
  final DateTime Function() _jetzt;
  final PlaneQualifikationsErinnerungenUseCase _planer;

  int? _letzterStand;
  Future<void> _laufend = Future<void>.value();

  /// Plant neu, wenn sich die Eingaben seit dem letzten Lauf geaendert haben.
  /// Ohne Read Model oder ohne eigene Person (abgemeldet) wird geraeumt.
  Future<void> aktualisiere({
    required ArbeitskontextReadModel? readModel,
    required QualifikationsEinstellungen einstellungen,
    required int? eigenePersonId,
    required bool supporter,
    required bool pushErlaubt,
    required String sprache,
  }) {
    _laufend = _laufend.then(
      (_) =>
          _aktualisiere(
            readModel: readModel,
            einstellungen: einstellungen,
            eigenePersonId: eigenePersonId,
            supporter: supporter,
            pushErlaubt: pushErlaubt,
            sprache: sprache,
          ).catchError((Object fehler, StackTrace stack) {
            unawaited(
              _logger.logWarn(
                'notifications',
                'Qualifikations-Erinnerungen fehlgeschlagen: $fehler\n$stack',
              ),
            );
          }),
    );
    return _laufend;
  }

  /// Loescht geplante Mitteilungen und die Merkliste, etwa beim Logout.
  Future<void> raeumen() {
    _laufend = _laufend.then((_) => _raeumen());
    return _laufend;
  }

  Future<void> _aktualisiere({
    required ArbeitskontextReadModel? readModel,
    required QualifikationsEinstellungen einstellungen,
    required int? eigenePersonId,
    required bool supporter,
    required bool pushErlaubt,
    required String sprache,
  }) async {
    if (readModel == null || eigenePersonId == null) {
      await _raeumen();
      return;
    }
    final jetzt = _jetzt();
    final stand = Object.hash(
      readModel,
      einstellungen,
      eigenePersonId,
      supporter,
      pushErlaubt,
      sprache,
      DateTime(jetzt.year, jetzt.month, jetzt.day, jetzt.hour),
    );
    if (stand == _letzterStand) {
      return;
    }
    _letzterStand = stand;

    await _mitteilungen.initialisieren();
    await _abbrechen();
    if (!pushErlaubt) {
      return;
    }

    final bereitsGeplant = await _ladeGeplant();
    final plan = _planer(
      readModel: readModel,
      einstellungen: einstellungen,
      eigenePersonId: eigenePersonId,
      supporter: supporter,
      jetzt: jetzt,
      bereitsGeplant: bereitsGeplant,
    );
    // Vergangenes bleibt gemerkt, damit es nicht erneut kommt.
    final gemerkt = <String, DateTime>{
      for (final eintrag in bereitsGeplant.entries)
        if (!eintrag.value.isAfter(jetzt) &&
            eintrag.value.isAfter(jetzt.subtract(const Duration(days: 400))))
          eintrag.key: eintrag.value,
    };
    if (plan.isNotEmpty) {
      await _mitteilungen.berechtigungAnfragen();
      final t = AppLocalizations(Locale(sprache));
      for (var i = 0; i < plan.length && idErste + i <= idLetzte; i++) {
        final erinnerung = plan[i];
        final (titel, text) = _texte(t, erinnerung);
        await _mitteilungen.planen(
          id: idErste + i,
          titel: titel,
          text: text,
          zeitpunkt: erinnerung.zeitpunkt,
          kanalName: t.t('quali_push_kanal'),
        );
        for (final schluessel in erinnerung.meldeSchluessel) {
          gemerkt[schluessel] = erinnerung.zeitpunkt;
        }
      }
    }
    await _speichereGeplant(gemerkt);
    await _logger.logInfo(
      'notifications',
      'Qualifikations-Erinnerungen geplant (anzahl=${plan.length})',
    );
  }

  (String, String) _texte(
    AppLocalizations t,
    GeplanteQualifikationsErinnerung erinnerung,
  ) {
    final datum = DateFormat('dd.MM.yyyy').format(erinnerung.gueltigBis);
    if (erinnerung.eigene) {
      return (
        t.t('quali_push_eigene_titel', {'art': erinnerung.artLabel}),
        t.t('quali_push_eigene_text', {'datum': datum}),
      );
    }
    final personen = erinnerung.personen;
    return (
      t.t('quali_push_fremde_titel', {'art': erinnerung.artLabel}),
      personen.length == 1
          ? t.t('quali_push_fremde_text_eins', {
              'name': personen.first,
              'datum': datum,
            })
          : t.t('quali_push_fremde_text_mehr', {
              'name': personen.first,
              'n': personen.length - 1,
              'datum': datum,
            }),
    );
  }

  Future<void> _raeumen() async {
    _letzterStand = null;
    await _mitteilungen.initialisieren();
    await _abbrechen();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsSchluessel);
  }

  Future<void> _abbrechen() async {
    for (final id in await _mitteilungen.geplanteIds()) {
      if (id >= idErste && id <= idLetzte) {
        await _mitteilungen.abbrechen(id);
      }
    }
  }

  Future<Map<String, DateTime>> _ladeGeplant() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsSchluessel);
    if (raw == null) {
      return const <String, DateTime>{};
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return const <String, DateTime>{};
      }
      return <String, DateTime>{
        for (final eintrag in json.entries)
          if (DateTime.tryParse(eintrag.value.toString()) != null)
            eintrag.key.toString(): DateTime.parse(eintrag.value.toString()),
      };
    } on FormatException {
      return const <String, DateTime>{};
    }
  }

  Future<void> _speichereGeplant(Map<String, DateTime> geplant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsSchluessel,
      jsonEncode(<String, String>{
        for (final eintrag in geplant.entries)
          eintrag.key: eintrag.value.toIso8601String(),
      }),
    );
  }
}
