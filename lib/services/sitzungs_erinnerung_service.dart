import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'hitobito_auth_env.dart';
import 'logger_service.dart';
import 'lokale_mitteilungen.dart';

/// Erinnert einmalig, bevor Hitobito die Anmeldung beendet. Hitobito loescht
/// Refresh-Tokens nach [HitobitoAuthEnv.refreshTokenLebensdauer] ohne
/// Erneuerung; ein kurzes Oeffnen der App erneuert das Token still. Jede
/// Erneuerung verschiebt die Erinnerung. Rechte fragt der Dienst nie an; ohne
/// Erlaubnis zeigt das System nichts.
class SitzungsErinnerungService {
  SitzungsErinnerungService({
    required LoggerService logger,
    LokaleMitteilungen? mitteilungen,
    DateTime Function()? jetzt,
  }) : _logger = logger,
       _mitteilungen =
           mitteilungen ?? PluginLokaleMitteilungen(kanalId: 'anmeldung'),
       _jetzt = jetzt ?? DateTime.now;

  static const id = 96200;

  /// So lange vor dem Ende der Anmeldung erinnert die App.
  static const vorlauf = Duration(days: 1);

  final LoggerService _logger;
  final LokaleMitteilungen _mitteilungen;
  final DateTime Function() _jetzt;

  // Erst nach dem ersten Lauf bekannt; bis dahin wird immer abgeglichen.
  bool _abgeglichen = false;
  DateTime? _geplantFuer;
  String? _sprache;
  Future<void> _laufend = Future<void>.value();

  /// Plant die Erinnerung zur letzten Erneuerung [erneuertAm]. Ohne
  /// Erneuerung (abgemeldet, Anmeldung bereits abgelaufen) oder ohne
  /// erlaubte Mitteilungen wird sie entfernt.
  Future<void> aktualisiere({
    required DateTime? erneuertAm,
    required bool pushErlaubt,
    required String sprache,
  }) {
    _laufend = _laufend.then(
      (_) =>
          _aktualisiere(
            erneuertAm: erneuertAm,
            pushErlaubt: pushErlaubt,
            sprache: sprache,
          ).catchError((Object fehler, StackTrace stack) {
            _abgeglichen = false;
            unawaited(
              _logger.logWarn(
                'notifications',
                'Anmelde-Erinnerung fehlgeschlagen: $fehler\n$stack',
              ),
            );
          }),
    );
    return _laufend;
  }

  Future<void> _aktualisiere({
    required DateTime? erneuertAm,
    required bool pushErlaubt,
    required String sprache,
  }) async {
    var zeitpunkt = erneuertAm == null || !pushErlaubt
        ? null
        : erneuertAm.add(HitobitoAuthEnv.refreshTokenLebensdauer - vorlauf);
    if (zeitpunkt != null && !zeitpunkt.isAfter(_jetzt())) {
      // Die App ist gerade offen und erneuert das Token gleich selbst.
      zeitpunkt = null;
    }
    if (_abgeglichen && zeitpunkt == _geplantFuer && sprache == _sprache) {
      return;
    }

    await _mitteilungen.initialisieren();
    await _mitteilungen.abbrechen(id);
    _abgeglichen = true;
    _geplantFuer = zeitpunkt;
    _sprache = sprache;
    if (zeitpunkt == null) {
      return;
    }

    final t = AppLocalizations(Locale(sprache));
    await _mitteilungen.planen(
      id: id,
      titel: t.t('auth_session_reminder_title'),
      text: t.t('auth_session_reminder_body'),
      zeitpunkt: zeitpunkt,
      kanalName: t.t('auth_session_reminder_kanal'),
    );
    await _logger.logInfo(
      'notifications',
      'Anmelde-Erinnerung geplant (zeitpunkt=${zeitpunkt.toIso8601String()})',
    );
  }
}
