import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/veranstaltung/anmeldestatus.dart';
import '../../../domain/veranstaltung/veranstaltung.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/status_farben.dart';

/// Farben fuer Kurs und Veranstaltung (Entscheidung
/// design/entscheidung/2026-10-10-kurse-veranstaltungen.md: Kurs lila,
/// Veranstaltung blau).
abstract final class VeranstaltungFarben {
  static const Color kursHell = Color(0xFF6A3FA0);
  static const Color kursDunkel = Color(0xFFB99BE6);

  static Color art(BuildContext context, VeranstaltungsArt art) {
    final theme = Theme.of(context);
    if (art == VeranstaltungsArt.veranstaltung) {
      return theme.colorScheme.primary;
    }
    return theme.brightness == Brightness.dark ? kursDunkel : kursHell;
  }
}

/// Status als farbiger Text: grün offen, orange bald offen, grau
/// geschlossen; Plaetze grau bzw. rot bei ausgebucht.
class StatusTeil {
  const StatusTeil(this.text, this.farbe);

  final String text;
  final Color farbe;
}

/// Gemeinsame Formate fuer Liste und Detail.
class VeranstaltungTexte {
  VeranstaltungTexte(this.context)
    : t = AppLocalizations.of(context),
      _sprache = AppLocalizations.of(context).locale.languageCode;

  final BuildContext context;
  final AppLocalizations t;
  final String _sprache;

  static const _status = BestimmeAnmeldestatusUseCase();

  String art(Veranstaltung veranstaltung) => veranstaltung.istKurs
      ? t.t('veranstaltung_art_kurs')
      : t.t('veranstaltung_art_veranstaltung');

  /// „Kurs · GLK“ bzw. „Veranstaltung“.
  String artMitKurzname(Veranstaltung veranstaltung) {
    final kurzname = veranstaltung.kursart?.kurzname;
    return kurzname == null
        ? art(veranstaltung)
        : '${art(veranstaltung)} · $kurzname';
  }

  String monat(DateTime datum) => DateFormat('MMMM y', _sprache).format(datum);

  String tag(DateTime datum) => DateFormat('d', _sprache).format(datum);

  String wochentag(DateTime datum) =>
      DateFormat('E', _sprache).format(datum).replaceAll('.', '');

  String kurzdatum(DateTime datum) =>
      DateFormat('d. MMM', _sprache).format(datum);

  String _uhrzeit(DateTime datum) =>
      DateFormat('HH:mm', _sprache).format(datum);

  String _datumMitTag(DateTime datum) =>
      DateFormat('E, d. MMM', _sprache).format(datum);

  static bool _gleicherTag(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// „Sa, 14. Nov, 18:00 – Mo, 16. Nov, 14:00“ oder „Sa, 7. Nov,
  /// 19:00–21:30“.
  String termin(VeranstaltungsTermin termin) {
    final beginn = termin.beginn;
    final ende = termin.ende;
    if (ende == null) {
      return '${_datumMitTag(beginn)}, ${_uhrzeit(beginn)}';
    }
    if (_gleicherTag(beginn, ende)) {
      return '${_datumMitTag(beginn)}, ${_uhrzeit(beginn)}–${_uhrzeit(ende)}';
    }
    return '${_datumMitTag(beginn)}, ${_uhrzeit(beginn)} – '
        '${_datumMitTag(ende)}, ${_uhrzeit(ende)}';
  }

  /// Gesamter Zeitraum ueber alle Termine, z. B. „14. – 30. Nov“.
  String zeitraum(Veranstaltung veranstaltung) {
    final beginn = veranstaltung.beginn;
    final ende = veranstaltung.ende;
    if (beginn == null) {
      return '';
    }
    if (ende == null || _gleicherTag(beginn, ende)) {
      return _datumMitTag(beginn);
    }
    if (beginn.month == ende.month && beginn.year == ende.year) {
      return '${tag(beginn)}. – ${kurzdatum(ende)}';
    }
    return '${kurzdatum(beginn)} – ${kurzdatum(ende)}';
  }

  Anmeldestatus anmeldestatus(Veranstaltung veranstaltung, DateTime heute) =>
      _status(veranstaltung, heute: heute);

  /// Statuszeile der Liste; leer, wenn nichts bekannt ist.
  List<StatusTeil> statusTeile(Veranstaltung veranstaltung, DateTime heute) {
    final farben = StatusFarben.of(context);
    final grau = Theme.of(context).colorScheme.onSurfaceVariant;
    final status = anmeldestatus(veranstaltung, heute);
    final teile = <StatusTeil>[];
    switch (status.phase) {
      case AnmeldePhase.offen:
        final bis = status.bis;
        teile.add(
          StatusTeil(
            bis == null
                ? t.t('veranstaltung_anmeldung_offen')
                : t.t('veranstaltung_anmeldung_offen_bis', {
                    'datum': kurzdatum(bis),
                  }),
            farben.gut,
          ),
        );
      case AnmeldePhase.baldOffen:
        teile.add(
          StatusTeil(
            t.t('veranstaltung_anmeldung_ab', {'datum': kurzdatum(status.ab!)}),
            farben.warnung,
          ),
        );
      case AnmeldePhase.geschlossen:
        teile.add(StatusTeil(t.t('veranstaltung_anmeldeschluss_vorbei'), grau));
      case AnmeldePhase.unbekannt:
        break;
    }
    final plaetze = plaetzeText(status);
    if (plaetze != null) {
      teile.add(
        StatusTeil(plaetze, status.ausgebucht ? farben.kritisch : grau),
      );
    }
    return teile;
  }

  String? plaetzeText(Anmeldestatus status, {bool mitMaximum = false}) {
    final frei = status.freiePlaetze;
    if (frei == null) {
      return null;
    }
    if (frei == 0) {
      return t.t('veranstaltung_ausgebucht');
    }
    final max = status.maxPlaetze;
    return mitMaximum && max != null
        ? t.t('veranstaltung_frei_von', {'n': frei, 'max': max})
        : t.t('veranstaltung_frei', {'n': frei});
  }
}
