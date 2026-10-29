import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../domain/member/plane_geburtstags_erinnerungen_usecase.dart';
import '../domain/taetigkeit/stufe.dart';
import '../l10n/app_localizations.dart';
import 'logger_service.dart';
import 'lokale_mitteilungen.dart';

/// Plant Geburtstags-Erinnerungen nach jedem Sync und jeder
/// Einstellungsaenderung neu. Nutzt einen eigenen ID-Bereich und raeumt nur
/// diesen, damit andere Erinnerungen (Datenablauf, Qualifikationen) bestehen
/// bleiben. Rechte fragt der Dienst nie an; ohne Erlaubnis zeigt das System
/// nichts. Die Mitteilungen nennen Namen; Android blendet sie deshalb auf dem
/// gesperrten Geraet aus, unter iOS gilt die Systemeinstellung fuer
/// Vorschauen.
class GeburtstagsErinnerungService {
  GeburtstagsErinnerungService({
    required LoggerService logger,
    LokaleMitteilungen? mitteilungen,
    DateTime Function()? jetzt,
    PlaneGeburtstagsErinnerungenUseCase planer =
        const PlaneGeburtstagsErinnerungenUseCase(),
  }) : _logger = logger,
       _mitteilungen =
           mitteilungen ??
           PluginLokaleMitteilungen(
             kanalId: 'geburtstage',
             visibility: NotificationVisibility.secret,
           ),
       _jetzt = jetzt ?? DateTime.now,
       _planer = planer;

  /// Reservierter Bereich; geplant werden hoechstens
  /// [PlaneGeburtstagsErinnerungenUseCase.maxMitteilungen] davon.
  static const idErste = 96000;
  static const idLetzte = 96099;

  /// Mehr Namen kuerzt die Mitteilung auf „und n weitere“.
  static const maxNamen = 3;

  final LoggerService _logger;
  final LokaleMitteilungen _mitteilungen;
  final DateTime Function() _jetzt;
  final PlaneGeburtstagsErinnerungenUseCase _planer;

  int? _letzterStand;
  Future<void> _laufend = Future<void>.value();

  /// Plant neu, wenn sich der Plan seit dem letzten Lauf geaendert hat.
  /// Ohne Read Model wird geraeumt. Ab [datenEnde] (Datenablauf) kommt
  /// nichts mehr.
  Future<void> aktualisiere({
    required ArbeitskontextReadModel? readModel,
    required Set<Stufe> stufen,
    required bool pushErlaubt,
    required String sprache,
    required DateTime? datenEnde,
  }) {
    _laufend = _laufend.then(
      (_) =>
          _aktualisiere(
            readModel: readModel,
            stufen: stufen,
            pushErlaubt: pushErlaubt,
            sprache: sprache,
            datenEnde: datenEnde,
          ).catchError((Object fehler, StackTrace stack) {
            // Etwa ohne Systemerlaubnis: Stand vergessen, damit die naechste
            // Aenderung (z. B. die Erlaubnis im Stepper) neu plant.
            _letzterStand = null;
            unawaited(
              _logger.logWarn(
                'notifications',
                'Geburtstags-Erinnerungen fehlgeschlagen: $fehler\n$stack',
              ),
            );
          }),
    );
    return _laufend;
  }

  /// Loescht geplante Geburtstags-Mitteilungen, etwa beim Logout.
  Future<void> raeumen() {
    _laufend = _laufend.then((_) => _raeumen());
    return _laufend;
  }

  Future<void> _aktualisiere({
    required ArbeitskontextReadModel? readModel,
    required Set<Stufe> stufen,
    required bool pushErlaubt,
    required String sprache,
    required DateTime? datenEnde,
  }) async {
    if (readModel == null) {
      await _raeumen();
      return;
    }
    final jetzt = _jetzt();
    final plan = pushErlaubt
        ? _planer(
            readModel: readModel,
            stufen: stufen,
            jetzt: jetzt,
            datenEnde: datenEnde,
          )
        : const <GeplanteGeburtstagsErinnerung>[];
    // Die Zeitzone gehoert zum Stand, damit nach einem Wechsel neu geplant
    // wird.
    final stand = Object.hash(
      pushErlaubt,
      sprache,
      Object.hashAll(plan),
      jetzt.timeZoneName,
      jetzt.timeZoneOffset,
    );
    if (stand == _letzterStand) {
      return;
    }
    _letzterStand = stand;

    await _mitteilungen.initialisieren();
    if (plan.isEmpty) {
      await _mitteilungen.abbrechenBereich(idErste, idLetzte);
      return;
    }

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
          kanalName: t.t('geburtstag_push_kanal'),
        );
      } on Object catch (e, stack) {
        fehler ??= e;
        fehlerStack ??= stack;
      }
    }
    await _mitteilungen.abbrechenAb(idErste + anzahl, idLetzte);
    if (fehler != null) {
      // Der Aufrufer vergisst den Stand und plant beim naechsten Anlass neu.
      Error.throwWithStackTrace(fehler, fehlerStack!);
    }
    await _logger.logInfo(
      'notifications',
      'Geburtstags-Erinnerungen geplant (anzahl=${plan.length})',
    );
  }

  /// Einzeln mit Alter, sonst „Heute haben A, B und C Geburtstag.“
  (String, String) _texte(
    AppLocalizations t,
    GeplanteGeburtstagsErinnerung erinnerung,
  ) {
    final personen = erinnerung.personen;
    if (personen.length == 1) {
      return (
        t.t('geburtstag_push_titel'),
        t.t('geburtstag_push_text', {
          'name': personen.first.kurzname,
          'alter': personen.first.alter,
        }),
      );
    }
    final namen = <String>[
      for (final person in personen.take(maxNamen)) person.kurzname,
      if (personen.length > maxNamen)
        t.t('geburtstag_push_weitere', {'n': personen.length - maxNamen}),
    ];
    final aufzaehlung =
        '${namen.sublist(0, namen.length - 1).join(', ')} '
        '${t.t('geburtstag_push_und')} ${namen.last}';
    return (
      t.t('geburtstag_push_titel_mehr'),
      t.t('geburtstag_push_text_mehr', {'namen': aufzaehlung}),
    );
  }

  Future<void> _raeumen() async {
    _letzterStand = null;
    await _mitteilungen.initialisieren();
    await _mitteilungen.abbrechenBereich(idErste, idLetzte);
  }
}
