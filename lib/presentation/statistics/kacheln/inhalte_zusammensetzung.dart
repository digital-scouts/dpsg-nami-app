import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/statistiks/stamm_statistik.dart';
import '../../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../domain/statistiks/statistik_mathe.dart';
import '../../../domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/statistics_location_service.dart';
import '../statistics_ui.dart';
import '../statistik_farben.dart';
import '../statistik_standorte.dart';
import 'diagramme.dart';
import 'kachel_daten.dart';
import 'kachel_rahmen.dart';

/// Ein Merkmal (Geschlecht, Konfession) mit Anzahl.
class _Merkmal {
  const _Merkmal(this.label, this.kurz, this.wert);

  final String label;
  final String kurz;
  final int wert;
}

class GeschlechtKachel extends StatelessWidget {
  const GeschlechtKachel({
    super.key,
    required this.daten,
    required this.groesse,
  });

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final g = daten.statistik.geschlecht;
    String text(String schluessel) => t.t('statistics_gender_$schluessel');
    return _MerkmalAnsicht(
      groesse: groesse,
      merkmale: [
        _Merkmal(
          text('female'),
          text('female_short'),
          g[GeschlechtKategorie.weiblich] ?? 0,
        ),
        _Merkmal(
          text('male'),
          text('male_short'),
          g[GeschlechtKategorie.maennlich] ?? 0,
        ),
        _Merkmal(
          text('diverse'),
          text('diverse_short'),
          g[GeschlechtKategorie.divers] ?? 0,
        ),
        _Merkmal(
          text('unknown'),
          text('unknown_short'),
          g[GeschlechtKategorie.ohneAngabe] ?? 0,
        ),
      ],
    );
  }
}

class KonfessionKachel extends StatelessWidget {
  const KonfessionKachel({
    super.key,
    required this.daten,
    required this.groesse,
  });

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final werte = daten.konfession;
    int wert(int i) => i < werte.length ? math.max(0, werte[i]) : 0;
    String text(String schluessel) => t.t('statistics_confession_$schluessel');
    return _MerkmalAnsicht(
      groesse: groesse,
      merkmale: [
        _Merkmal(text('catholic'), text('catholic_short'), wert(0)),
        _Merkmal(text('protestant'), text('protestant_short'), wert(1)),
        _Merkmal(text('none'), text('none_short'), wert(2)),
        _Merkmal(text('other'), text('other_short'), wert(3)),
      ],
    );
  }
}

class _MerkmalAnsicht extends StatelessWidget {
  const _MerkmalAnsicht({required this.groesse, required this.merkmale});

  final KachelGroesse groesse;
  final List<_Merkmal> merkmale;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final palette = farben.merkmal;
    final summe = merkmale.fold<int>(0, (s, m) => s + m.wert);
    if (groesse == KachelGroesse.klein) {
      // Im Ring nur kurze Kürzel ohne Prozente; der Rest steht darunter.
      bool imRing(_Merkmal m) =>
          anteil(m.wert, summe) >= 0.12 && m.kurz.length <= 3;
      final rest = [
        for (var i = 0; i < merkmale.length; i++)
          if (merkmale[i].wert > 0 && !imRing(merkmale[i])) i,
      ];
      return Column(
        children: [
          Expanded(
            child: Center(
              child: MerkmalRing(
                mitte: '$summe',
                teile: [
                  for (var i = 0; i < merkmale.length; i++)
                    DiagrammTeil(
                      wert: merkmale[i].wert,
                      farbe: palette[i],
                      beschriftung: imRing(merkmale[i])
                          ? merkmale[i].kurz
                          : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 7,
            children: [
              for (final i in rest)
                KachelSchluessel(
                  farbe: palette[i],
                  text: merkmale[i].kurz,
                  klein: true,
                ),
            ],
          ),
        ],
      );
    }
    final sprache = Localizations.maybeLocaleOf(context)?.languageCode;
    final ring = MerkmalRing(
      mitte: '$summe',
      ringAnteil: 0.2,
      teile: [
        for (var i = 0; i < merkmale.length; i++)
          DiagrammTeil(wert: merkmale[i].wert, farbe: palette[i]),
      ],
    );
    // Bei großer Schrift wird die Kachel höher; der Ring darf der Legende
    // trotzdem nicht die Breite nehmen.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox.square(
            dimension: math.max(
              0,
              math.min(
                constraints.maxHeight,
                (constraints.maxWidth - 16) * 0.42,
              ),
            ),
            child: ring,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: KachelEingepasst(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < merkmale.length; i++)
                    if (merkmale[i].wert > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: KachelSchluessel(
                                farbe: palette[i],
                                text: merkmale[i].label,
                              ),
                            ),
                            Text(
                              '${merkmale[i].wert}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: farben.text,
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${(anteil(merkmale[i].wert, summe) * 100).round()}${sprache == 'en' ? '%' : ' %'}',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: farben.textSchwach,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StandorteKachel extends StatelessWidget {
  const StandorteKachel({
    super.key,
    required this.daten,
    required this.groesse,
  });

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!StatistikStandortAufloesung.hatEingaben(
      daten.standortMitglieder,
      daten.stammAdresse,
    )) {
      return KachelLeer(t.t('statistics_no_locations'));
    }
    return StatistikStandortAufloesung(
      members: daten.standortMitglieder,
      stammAddress: daten.stammAdresse,
      aufloesung: daten.standortAufloesung,
      builder: (context, aufgeloest) {
        if (aufgeloest == null) {
          return const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }
        final hinweis = aufgeloest.hinweis;
        if (aufgeloest.memberPoints.isEmpty && aufgeloest.stammPoint == null) {
          if (hinweis == null) {
            return KachelLeer(t.t('statistics_no_locations'));
          }
          return _StandortHinweisLeer(hinweis: hinweis);
        }
        final karte = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child:
              daten.kartenBauer?.call(
                context,
                aufgeloest.memberPoints,
                aufgeloest.stammPoint,
              ) ??
              StatisticsMap(
                markers: aufgeloest.memberPoints,
                stammLocation: aufgeloest.stammPoint,
              ),
        );
        final legende = [
          _KartenLegende(
            icon: Icons.location_on,
            farbe: const Color(0xFFCC1F2F),
            text: t.t('statistics_residences'),
            wert: '${aufgeloest.memberPoints.length}',
          ),
          if (aufgeloest.stammPoint != null)
            _KartenLegende(
              icon: Icons.home,
              farbe: const Color(0xFF1565C0),
              text: t.t('statistics_home'),
            ),
          if (hinweis != null) _StandortHinweisZeile(hinweis: hinweis),
        ];
        if (groesse == KachelGroesse.gross) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: karte),
              const SizedBox(height: 8),
              Wrap(spacing: 18, runSpacing: 2, children: legende),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: karte),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legende,
              ),
            ),
          ],
        );
      },
    );
  }
}

IconData _standortHinweisIcon(StandortHinweis hinweis) => switch (hinweis) {
  StandortHinweis.keineMobilenDaten => Icons.wifi,
  StandortHinweis.offline => Icons.cloud_off,
  StandortHinweis.pausiert => Icons.pause_circle_outline,
  StandortHinweis.unvollstaendig => Icons.error_outline,
};

/// Grund, warum noch kein Standort bekannt ist, mittig in der Kachel.
class _StandortHinweisLeer extends StatelessWidget {
  const _StandortHinweisLeer({required this.hinweis});

  final StandortHinweis hinweis;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final (haupt, neben) = switch (hinweis) {
      StandortHinweis.keineMobilenDaten => (
        'statistics_locations_wifi',
        'statistics_locations_wifi_reason',
      ),
      StandortHinweis.offline => ('statistics_locations_offline', null),
      StandortHinweis.pausiert => (
        'statistics_locations_paused',
        'statistics_locations_retry_later',
      ),
      StandortHinweis.unvollstaendig => (
        'statistics_locations_incomplete',
        'statistics_locations_retry_later',
      ),
    };
    return Center(
      key: const Key('standorte-hinweis-leer'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _standortHinweisIcon(hinweis),
              size: 22,
              color: farben.textGedaempft,
            ),
            const SizedBox(height: 6),
            // Flexible: Bei großer Schrift kürzt der Text statt die Kachel
            // zu sprengen.
            Flexible(
              child: Text(
                t.t(haupt),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: farben.textGedaempft,
                ),
              ),
            ),
            if (neben != null) ...[
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  t.t(neben),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: farben.textSchwach),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grund für fehlende Standorte als leise Zeile unter der Legende.
class _StandortHinweisZeile extends StatelessWidget {
  const _StandortHinweisZeile({required this.hinweis});

  final StandortHinweis hinweis;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final text = t.t(switch (hinweis) {
      StandortHinweis.keineMobilenDaten => 'statistics_locations_wifi_more',
      StandortHinweis.offline => 'statistics_locations_offline_more',
      StandortHinweis.pausiert => 'statistics_locations_paused',
      StandortHinweis.unvollstaendig => 'statistics_locations_incomplete',
    });
    return Padding(
      key: const Key('standorte-hinweis-zeile'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _standortHinweisIcon(hinweis),
            size: 13,
            color: farben.textSchwach,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: farben.textSchwach,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartenLegende extends StatelessWidget {
  const _KartenLegende({
    required this.icon,
    required this.farbe,
    required this.text,
    this.wert,
  });

  final IconData icon;
  final Color farbe;
  final String text;
  final String? wert;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: farbe),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (wert != null)
                    TextSpan(
                      text: '  $wert',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: farben.text,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: farben.textGedaempft),
            ),
          ),
        ],
      ),
    );
  }
}

class EigeneKachelInhalt extends StatelessWidget {
  const EigeneKachelInhalt({
    super.key,
    required this.kachel,
    required this.zaehlung,
    required this.groesse,
  });

  final EigeneKachel kachel;
  final EigeneKachelZaehlung zaehlung;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final teile = [
      for (final stufe in Stufe.values)
        if ((zaehlung.jeStufe[stufe] ?? 0) > 0)
          (stufe, zaehlung.jeStufe[stufe]!),
    ];
    final nachStufe =
        kachel.darstellung == EigeneKachelDarstellung.nachStufe &&
        teile.isNotEmpty;
    final ziel = kachel.ziel;
    final zielZeile = ziel != null
        ? Text(
            t.t('statistics_of_target', {
              'value': zaehlung.anzahl,
              'target': ziel,
              'text': kachel.zielText ?? '',
            }).trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: farben.textSchwach),
          )
        : null;
    final zahl = KachelZahl('${zaehlung.anzahl}');
    final einheit = Text(
      t.t('statistics_persons_unit'),
      style: TextStyle(fontSize: 11, color: farben.textSchwach),
    );

    if (groesse == KachelGroesse.klein) {
      if (nachStufe) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  zahl,
                  KachelRest(
                    abstand: 4,
                    ausrichtung: AlignmentDirectional.topStart,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (stufe, _) in teile)
                          stufenSchluessel(context, stufe, klein: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 72,
              child: MerkmalRing(
                torte: true,
                teile: [
                  for (final (stufe, wert) in teile)
                    DiagrammTeil(
                      wert: wert,
                      farbe: farben.stufe(stufe),
                      kontur: farben.kontur(stufe),
                      beschriftung: '$wert',
                    ),
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          zahl,
          KachelRest(
            child: ziel != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PlatzFelder(besetzt: zaehlung.anzahl, plaetze: ziel),
                      const SizedBox(height: 4),
                      zielZeile!,
                    ],
                  )
                : einheit,
          ),
        ],
      );
    }
    final rechts = nachStufe
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiagrammBand(
                hoehe: 18,
                teile: [
                  for (final (stufe, wert) in teile)
                    DiagrammTeil(
                      wert: wert,
                      farbe: farben.stufe(stufe),
                      kontur: farben.kontur(stufe),
                      beschriftung: '$wert',
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  for (final (stufe, wert) in teile)
                    stufenSchluessel(
                      context,
                      stufe,
                      wert: '$wert',
                      klein: true,
                    ),
                ],
              ),
            ],
          )
        : ziel != null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlatzFelder(besetzt: zaehlung.anzahl, plaetze: ziel),
              const SizedBox(height: 4),
              zielZeile!,
            ],
          )
        : const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: KachelEingepasst(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KachelZahl(
                  '${zaehlung.anzahl}',
                  groesse: 46,
                  ausrichtung: Alignment.center,
                ),
                einheit,
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: rechts),
      ],
    );
  }
}
