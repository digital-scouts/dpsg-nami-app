import 'package:flutter/material.dart';

import '../../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import '../../../l10n/app_localizations.dart';
import 'inhalte_alter.dart';
import 'inhalte_entwicklung.dart';
import 'inhalte_mitglieder.dart';
import 'inhalte_zusammensetzung.dart';
import 'kachel_daten.dart';
import 'kachel_rahmen.dart';

enum KachelBereich { mitglieder, stufen, entwicklung, zusammensetzung, eigene }

typedef KachelInhaltBuilder =
    Widget Function(
      BuildContext context,
      StatistikKachelDaten daten,
      KachelEintrag eintrag,
    );

/// Beschreibt einen Kacheltyp: Titel, Bereich im Katalog, erlaubte Größen
/// (aus [StatistikKachelTypen]) und wie der Inhalt gebaut wird.
class KachelDefinition {
  const KachelDefinition({
    required this.typId,
    required this.titelSchluessel,
    required this.bereich,
    required this.inhalt,
    this.titelBreitSchluessel,
  });

  final String typId;
  final String titelSchluessel;

  /// Anderer Titel ab 2×1, z. B. „Bindung“ statt „Neu in 12 Monaten“.
  final String? titelBreitSchluessel;
  final KachelBereich bereich;
  final KachelInhaltBuilder inhalt;

  List<KachelGroesse> get groessen => StatistikKachelTypen.groessenFuer(typId);

  String titel(AppLocalizations t, KachelGroesse groesse) => t.t(
    groesse != KachelGroesse.klein && titelBreitSchluessel != null
        ? titelBreitSchluessel!
        : titelSchluessel,
  );
}

abstract final class KachelKatalog {
  static final List<KachelDefinition> definitionen = [
    KachelDefinition(
      typId: StatistikKachelTypen.personen,
      titelSchluessel: 'statistics_tile_people',
      bereich: KachelBereich.mitglieder,
      inhalt: (context, daten, e) =>
          PersonenKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.stufen,
      titelSchluessel: 'statistics_tile_stages',
      bereich: KachelBereich.mitglieder,
      inhalt: (context, daten, e) => StufenKachel(daten: daten),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.gruppen,
      titelSchluessel: 'statistics_tile_groups',
      bereich: KachelBereich.stufen,
      inhalt: (context, daten, e) =>
          GruppenKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.altersstruktur,
      titelSchluessel: 'statistics_tile_age',
      bereich: KachelBereich.stufen,
      inhalt: (context, daten, e) =>
          AltersstrukturKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.alterInZahlen,
      titelSchluessel: 'statistics_tile_age_numbers',
      bereich: KachelBereich.stufen,
      inhalt: (context, daten, e) =>
          AlterInZahlenKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.stufenwechsel,
      titelSchluessel: 'statistics_tile_stage_change',
      bereich: KachelBereich.entwicklung,
      inhalt: (context, daten, e) =>
          StufenwechselKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.bindung,
      titelSchluessel: 'statistics_tile_new',
      titelBreitSchluessel: 'statistics_tile_retention',
      bereich: KachelBereich.entwicklung,
      inhalt: (context, daten, e) =>
          BindungKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.verlauf,
      titelSchluessel: 'statistics_tile_history',
      bereich: KachelBereich.entwicklung,
      inhalt: (context, daten, e) =>
          VerlaufKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.geschlecht,
      titelSchluessel: 'statistics_tile_gender',
      bereich: KachelBereich.zusammensetzung,
      inhalt: (context, daten, e) =>
          GeschlechtKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.konfession,
      titelSchluessel: 'statistics_tile_confession',
      bereich: KachelBereich.zusammensetzung,
      inhalt: (context, daten, e) =>
          KonfessionKachel(daten: daten, groesse: e.groesse),
    ),
    KachelDefinition(
      typId: StatistikKachelTypen.standorte,
      titelSchluessel: 'statistics_tile_locations',
      bereich: KachelBereich.zusammensetzung,
      inhalt: (context, daten, e) =>
          StandorteKachel(daten: daten, groesse: e.groesse),
    ),
  ];

  static KachelDefinition? finde(String typId) {
    for (final d in definitionen) {
      if (d.typId == typId) return d;
    }
    return null;
  }

  /// Titel eines Eintrags; bei eigenen Kacheln deren Name.
  static String titelFuer(
    AppLocalizations t,
    StatistikKachelDaten daten,
    KachelEintrag eintrag,
  ) {
    if (eintrag.typId == StatistikKachelTypen.eigene) {
      return daten.einstellungen.eigeneKachel(eintrag.eigeneKachelId)?.titel ??
          '';
    }
    // Ab drei Gruppen zeigt 2×1 Stufen statt Gruppen.
    if (eintrag.typId == StatistikKachelTypen.gruppen &&
        GruppenKachel.zeigtStufen(daten, eintrag.groesse)) {
      return t.t('statistics_tile_groups_stages', {
        'count': GruppenKachel.anzahlGruppen(daten),
      });
    }
    return finde(eintrag.typId)?.titel(t, eintrag.groesse) ?? '';
  }

  /// Fertige Kachel mit Rahmen und Inhalt.
  static Widget kachel(
    BuildContext context,
    StatistikKachelDaten daten,
    KachelEintrag eintrag,
  ) {
    final t = AppLocalizations.of(context);
    final Widget inhalt;
    if (eintrag.typId == StatistikKachelTypen.eigene) {
      final eigene = daten.einstellungen.eigeneKachel(eintrag.eigeneKachelId);
      inhalt = eigene == null
          ? const SizedBox.shrink()
          : EigeneKachelInhalt(
              kachel: eigene,
              zaehlung:
                  daten.eigeneZaehlungen[eigene.id] ??
                  const EigeneKachelZaehlung(anzahl: 0, jeStufe: {}),
              groesse: eintrag.groesse,
            );
    } else {
      inhalt =
          finde(eintrag.typId)?.inhalt(context, daten, eintrag) ??
          const SizedBox.shrink();
    }
    final oeffnen = daten.onGruppeOeffnen;
    return KachelRahmen(
      titel: titelFuer(t, daten, eintrag),
      onTitel:
          eintrag.typId == StatistikKachelTypen.gruppen &&
              oeffnen != null &&
              GruppenKachel.anzahlGruppen(daten) > 0
          ? () => oeffneGruppeAusAuswahl(context, daten)
          : null,
      child: inhalt,
    );
  }
}
