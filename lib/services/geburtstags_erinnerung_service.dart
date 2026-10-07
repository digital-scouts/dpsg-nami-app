import 'dart:async';

import 'package:flutter/widgets.dart';

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
/// nichts.
class GeburtstagsErinnerungService {
  GeburtstagsErinnerungService({
    required LoggerService logger,
    LokaleMitteilungen? mitteilungen,
    DateTime Function()? jetzt,
    PlaneGeburtstagsErinnerungenUseCase planer =
        const PlaneGeburtstagsErinnerungenUseCase(),
  }) : _logger = logger,
       _mitteilungen =
           mitteilungen ?? PluginLokaleMitteilungen(kanalId: 'geburtstage'),
       _jetzt = jetzt ?? DateTime.now,
       _planer = planer;

  /// Reservierter Bereich; geplant werden hoechstens
  /// [PlaneGeburtstagsErinnerungenUseCase.maxMitteilungen] davon.
  static const idErste = 96000;
  static const idLetzte = 96099;

  final LoggerService _logger;
  final LokaleMitteilungen _mitteilungen;
  final DateTime Function() _jetzt;
  final PlaneGeburtstagsErinnerungenUseCase _planer;

  int? _letzterStand;
  Future<void> _laufend = Future<void>.value();

  /// Plant neu, wenn sich der Plan seit dem letzten Lauf geaendert hat.
  /// Ohne Read Model wird geraeumt.
  Future<void> aktualisiere({
    required ArbeitskontextReadModel? readModel,
    required Set<Stufe> stufen,
    required bool pushErlaubt,
    required String sprache,
  }) {
    _laufend = _laufend.then(
      (_) =>
          _aktualisiere(
            readModel: readModel,
            stufen: stufen,
            pushErlaubt: pushErlaubt,
            sprache: sprache,
          ).catchError((Object fehler, StackTrace stack) {
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
  }) async {
    if (readModel == null) {
      await _raeumen();
      return;
    }
    final plan = pushErlaubt
        ? _planer(readModel: readModel, stufen: stufen, jetzt: _jetzt())
        : const <GeplanteGeburtstagsErinnerung>[];
    final stand = Object.hash(pushErlaubt, sprache, Object.hashAll(plan));
    if (stand == _letzterStand) {
      return;
    }
    _letzterStand = stand;

    await _mitteilungen.initialisieren();
    await _abbrechen();
    if (plan.isEmpty) {
      return;
    }

    final t = AppLocalizations(Locale(sprache));
    for (var i = 0; i < plan.length && idErste + i <= idLetzte; i++) {
      final erinnerung = plan[i];
      await _mitteilungen.planen(
        id: idErste + i,
        titel: t.t('geburtstag_push_titel'),
        text: t.t('geburtstag_push_text', {
          'name': erinnerung.kurzname,
          'alter': erinnerung.alter,
        }),
        zeitpunkt: erinnerung.zeitpunkt,
        kanalName: t.t('geburtstag_push_kanal'),
      );
    }
    await _logger.logInfo(
      'notifications',
      'Geburtstags-Erinnerungen geplant (anzahl=${plan.length})',
    );
  }

  Future<void> _raeumen() async {
    _letzterStand = null;
    await _mitteilungen.initialisieren();
    await _abbrechen();
  }

  Future<void> _abbrechen() async {
    for (final id in await _mitteilungen.geplanteIds()) {
      if (id >= idErste && id <= idLetzte) {
        await _mitteilungen.abbrechen(id);
      }
    }
  }
}
