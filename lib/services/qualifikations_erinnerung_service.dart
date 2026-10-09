import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import '../domain/qualifikation/qualifikations_einstellungen.dart';
import '../l10n/app_localizations.dart';
import 'logger_service.dart';
import 'lokale_mitteilungen.dart';

/// Plant Erinnerungen an ablaufende Qualifikationen nach jedem Sync und
/// jeder Einstellungsaenderung neu. Nutzt einen eigenen ID-Bereich und raeumt
/// nur diesen, damit andere Erinnerungen (Datenablauf) bestehen bleiben.
class QualifikationsErinnerungService {
  QualifikationsErinnerungService({
    required LoggerService logger,
    LokaleMitteilungen? mitteilungen,
    DateTime Function()? jetzt,
    PlaneQualifikationsErinnerungenUseCase planer =
        const PlaneQualifikationsErinnerungenUseCase(),
  }) : _logger = logger,
       _mitteilungen =
           mitteilungen ?? PluginLokaleMitteilungen(kanalId: 'qualifikationen'),
       _jetzt = jetzt ?? DateTime.now,
       _planer = planer;

  static const idErste = 95000;
  static const idLetzte = 95099;
  static const _prefsSchluessel = 'qualifikationsErinnerungenGeplant';

  final LoggerService _logger;
  final LokaleMitteilungen _mitteilungen;
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
            // Etwa ohne Systemerlaubnis: Stand vergessen, damit die naechste
            // Aenderung (z. B. die Erlaubnis im Stepper) neu plant.
            _letzterStand = null;
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
      // Nach Zeitzonen- oder Sommerzeitwechsel neu planen, damit "9 Uhr"
      // wieder zur Ortszeit passt.
      jetzt.timeZoneName,
      jetzt.timeZoneOffset,
    );
    if (stand == _letzterStand) {
      return;
    }
    _letzterStand = stand;

    await _mitteilungen.initialisieren();
    final bereitsGeplant = await _ladeGeplant();
    if (!pushErlaubt) {
      await _mitteilungen.abbrechenBereich(idErste, idLetzte);
      // Noch nicht Zugestelltes gilt nicht als gemeldet, damit es nach dem
      // Wiedereinschalten kommt (spaetestens am naechsten Morgen).
      await _speichereGeplant(_vergangene(bereitsGeplant, jetzt));
      return;
    }

    final plan = _planer(
      readModel: readModel,
      einstellungen: einstellungen,
      eigenePersonId: eigenePersonId,
      supporter: supporter,
      jetzt: jetzt,
      bereitsGeplant: bereitsGeplant,
    );
    // Vergangenes bleibt gemerkt, damit es nicht erneut kommt.
    final gemerkt = _vergangene(bereitsGeplant, jetzt);
    final t = AppLocalizations(Locale(sprache));
    final anzahl = plan.length < idLetzte - idErste + 1
        ? plan.length
        : idLetzte - idErste + 1;
    Object? fehler;
    StackTrace? fehlerStack;
    // Erst ersetzen, dann Ueberzaehliges entfernen: schlaegt das Planen fehl,
    // bleiben die bisherigen Erinnerungen erhalten.
    for (var i = 0; i < anzahl; i++) {
      final erinnerung = plan[i];
      final (titel, text) = _texte(t, erinnerung);
      try {
        await _mitteilungen.planen(
          id: idErste + i,
          titel: titel,
          text: text,
          zeitpunkt: erinnerung.zeitpunkt,
          kanalName: t.t('quali_push_kanal'),
        );
      } on Object catch (e, stack) {
        fehler ??= e;
        fehlerStack ??= stack;
        continue;
      }
      for (final schluessel in erinnerung.meldeSchluessel) {
        gemerkt[schluessel] = erinnerung.zeitpunkt;
      }
    }
    await _mitteilungen.abbrechenAb(idErste + anzahl, idLetzte);
    await _speichereGeplant(gemerkt);
    if (fehler != null) {
      // Der Aufrufer vergisst den Stand und plant beim naechsten Anlass neu.
      Error.throwWithStackTrace(fehler, fehlerStack!);
    }
    await _logger.logInfo(
      'notifications',
      'Qualifikations-Erinnerungen geplant (anzahl=${plan.length})',
    );
  }

  Map<String, DateTime> _vergangene(
    Map<String, DateTime> geplant,
    DateTime jetzt,
  ) => <String, DateTime>{
    for (final eintrag in geplant.entries)
      if (!eintrag.value.isAfter(jetzt) &&
          eintrag.value.isAfter(jetzt.subtract(const Duration(days: 400))))
        eintrag.key: eintrag.value,
  };

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
    await _mitteilungen.abbrechenBereich(idErste, idLetzte);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsSchluessel);
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
