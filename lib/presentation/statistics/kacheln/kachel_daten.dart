import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/member/mitglied.dart';
import '../../../domain/statistiks/stamm_statistik.dart';
import '../../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../../domain/statistiks/statistik_verlauf.dart';
import '../../../domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import '../../../domain/stufe/altersgrenzen.dart';
import '../statistik_standorte.dart';

typedef StatistikKartenBauer =
    Widget Function(
      BuildContext context,
      List<LatLng> wohnorte,
      LatLng? stammesheim,
    );

/// Alles, was die Kacheln zum Zeichnen brauchen. Wird einmal je Build der
/// Statistikseite erzeugt; Kacheln rechnen selbst nichts aus.
class StatistikKachelDaten {
  const StatistikKachelDaten({
    required this.statistik,
    required this.grenzen,
    required this.heute,
    this.einstellungen = const StatistikKachelEinstellungen(),
    this.konfession = const [],
    this.eigeneZaehlungen = const {},
    this.verlauf = const [],
    this.standortMitglieder = const [],
    this.stammAdresse,
    this.standortAufloesung,
    this.kartenBauer,
    this.onGruppeOeffnen,
  });

  final StammStatistik statistik;
  final Altersgrenzen grenzen;
  final DateTime heute;
  final StatistikKachelEinstellungen einstellungen;

  /// Konfession der Kinder und Jugendlichen in fester Reihenfolge:
  /// katholisch, evangelisch, konfessionslos, andere.
  final List<int> konfession;

  /// Zählungen der eigenen Kacheln nach deren ID.
  final Map<String, EigeneKachelZaehlung> eigeneZaehlungen;
  final List<StatistikVerlaufEintrag> verlauf;

  final List<Mitglied> standortMitglieder;
  final String? stammAdresse;

  /// Ersatz für Tests und Stories; `null` = echte Auflösung.
  final StandortAufloesung? standortAufloesung;

  /// Ersatz für die Karte in Tests; `null` = echte Karte.
  final StatistikKartenBauer? kartenBauer;

  /// Einzige antippbare Stelle: Gruppenzeilen öffnen das Gruppendetail.
  final ValueChanged<int>? onGruppeOeffnen;

  StatistikZielwerte get ziele => einstellungen.ziele;

  StatistikKachelDaten copyWith({
    StatistikKachelEinstellungen? einstellungen,
    Map<String, EigeneKachelZaehlung>? eigeneZaehlungen,
    ValueChanged<int>? onGruppeOeffnen,
  }) => StatistikKachelDaten(
    statistik: statistik,
    grenzen: grenzen,
    heute: heute,
    einstellungen: einstellungen ?? this.einstellungen,
    konfession: konfession,
    eigeneZaehlungen: eigeneZaehlungen ?? this.eigeneZaehlungen,
    verlauf: verlauf,
    standortMitglieder: standortMitglieder,
    stammAdresse: stammAdresse,
    standortAufloesung: standortAufloesung,
    kartenBauer: kartenBauer,
    onGruppeOeffnen: onGruppeOeffnen ?? this.onGruppeOeffnen,
  );
}
