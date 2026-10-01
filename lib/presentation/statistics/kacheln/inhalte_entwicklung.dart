import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/statistiks/stamm_statistik.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../domain/statistiks/statistik_mathe.dart';
import '../../../domain/statistiks/statistik_verlauf.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../statistik_farben.dart';
import 'diagramme.dart';
import 'kachel_daten.dart';
import 'kachel_rahmen.dart';

List<String> _monate(AppLocalizations t) => t.t('statistics_months').split(',');

class StufenwechselKachel extends StatelessWidget {
  const StufenwechselKachel({
    super.key,
    required this.daten,
    required this.groesse,
  });

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final prognose = daten.statistik.prognose;
    if (prognose == null) return KachelLeer(t.t('statistics_roles_loading'));
    final farben = StatistikFarben.of(context);
    final stufen = prognose.stufen
        .where((s) => s.heute > 0 || s.danach > 0)
        .toList();
    final textStil = TextStyle(fontSize: 14, color: farben.textGedaempft);

    if (groesse == KachelGroesse.klein) {
      final abgaenge = prognose.stufen.where((s) => s.ab > 0).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KachelZahl('${prognose.anzahl}'),
          Text(
            t.t('statistics_stage_change_short', {
              'date': datumKurz(prognose.stichtag),
            }),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: farben.textSchwach,
            ),
          ),
          if (abgaenge.isNotEmpty)
            KachelRest(
              abstand: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiagrammBand(
                    hoehe: 8,
                    teile: [
                      for (final s in abgaenge)
                        DiagrammTeil(
                          wert: s.ab,
                          farbe: farben.stufe(s.stufe),
                          kontur: farben.kontur(s.stufe),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final s in abgaenge)
                        stufenSchluessel(
                          context,
                          s.stufe,
                          wert: '${s.ab}',
                          klein: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final lead = Text.rich(
      TextSpan(
        children: _fett(
          t.t('statistics_stage_change_lead', {
            'count': '\u0000${prognose.anzahl}\u0000',
            'date': datumLang(prognose.stichtag),
          }),
          farben.text,
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStil,
    );
    final skala = math.max(
      1,
      stufen
          .map((s) => [s.heute, s.danach, _ziel(s) ?? 0].fold<int>(0, math.max))
          .fold<int>(0, math.max),
    );

    if (groesse == KachelGroesse.breit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lead,
          KachelRest(
            abstand: 10,
            ausrichtung: AlignmentDirectional.topStart,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in stufen) ...[
                  if (s != stufen.first) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.stufe.shortDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: farben.textGedaempft,
                          ),
                        ),
                        _HeuteDanachZahl(heute: s.heute, danach: s.danach),
                        const SizedBox(height: 3),
                        HeuteDanachBalken(
                          heute: s.heute,
                          danach: s.danach,
                          skala: skala,
                          farbe: farben.stufe(s.stufe),
                          kontur: farben.kontur(s.stufe),
                          hoehe: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        lead,
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final zeilenHoehe = stufen.isEmpty
                  ? 0.0
                  : constraints.maxHeight / stufen.length;
              final balkenHoehe = (zeilenHoehe * 0.5).clamp(8.0, 22.0);
              return Column(
                children: [
                  for (final s in stufen)
                    SizedBox(
                      height: zeilenHoehe,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              s.stufe.shortDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: farben.textGedaempft,
                              ),
                            ),
                          ),
                          Expanded(
                            child: HeuteDanachBalken(
                              heute: s.heute,
                              danach: s.danach,
                              skala: skala,
                              farbe: farben.stufe(s.stufe),
                              kontur: farben.kontur(s.stufe),
                              ziel: _ziel(s),
                              hoehe: balkenHoehe,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 62,
                            child: _HeuteDanachZahl(
                              heute: s.heute,
                              danach: s.danach,
                              ausrichtung: Alignment.centerRight,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _Legende(mitZiel: daten.ziele.gruppeMax.isNotEmpty),
      ],
    );
  }

  int? _ziel(StufenwechselStufe s) => daten.ziele.zielFuerStufe(
    s.stufe,
    daten.statistik.stufe(s.stufe).gruppen.length,
  );
}

/// Zerlegt Text mit `\u0000`-markierten Stellen in normale und fette Teile.
List<InlineSpan> _fett(String text, Color farbe) {
  final teile = text.split('\u0000');
  return [
    for (var i = 0; i < teile.length; i++)
      TextSpan(
        text: teile[i],
        style: i.isOdd
            ? TextStyle(fontWeight: FontWeight.w700, color: farbe)
            : null,
      ),
  ];
}

class _HeuteDanachZahl extends StatelessWidget {
  const _HeuteDanachZahl({
    required this.heute,
    required this.danach,
    this.ausrichtung = Alignment.centerLeft,
  });

  final int heute;
  final int danach;
  final AlignmentGeometry ausrichtung;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: ausrichtung,
      child: Text.rich(
        TextSpan(
          text: '$heute → ',
          style: TextStyle(fontSize: 12, color: farben.textSchwach),
          children: [
            TextSpan(
              text: '$danach',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: farben.text,
              ),
            ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende({required this.mitZiel});

  final bool mitZiel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: [
        KachelSchluessel(
          farbe: farben.heute,
          text: t.t('statistics_stage_change_today'),
          klein: true,
        ),
        KachelSchluessel(
          farbe: farben.textGedaempft,
          text: t.t('statistics_stage_change_after'),
          klein: true,
        ),
        if (mitZiel)
          KachelSchluessel(
            farbe: farben.textSchwach,
            text: t.t('statistics_target'),
            klein: true,
          ),
      ],
    );
  }
}

class BindungKachel extends StatelessWidget {
  const BindungKachel({super.key, required this.daten, required this.groesse});

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final b = daten.statistik.bindung;
    final ziel = daten.ziele.neuProJahr;
    final klein = TextStyle(fontSize: 11, color: farben.textSchwach);
    if (groesse == KachelGroesse.klein) {
      final monate = _monate(t);
      final werte = [for (final m in b.eintritteJeMonat) m.anzahl];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KachelZahl('${b.neuInZwoelfMonaten}'),
          if (ziel != null)
            KachelMeter(anteil: anteil(b.neuInZwoelfMonaten, ziel)),
          Text(
            ziel != null
                ? t.t('statistics_target_per_year', {'count': ziel})
                : t.t('statistics_no_target'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: klein,
          ),
          KachelRest(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonatsSaeulen(werte: werte),
                if (b.eintritteJeMonat.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        monate[b.eintritteJeMonat.first.monat - 1],
                        style: klein,
                      ),
                      const Spacer(),
                      Text(
                        monate[b.eintritteJeMonat.last.monat - 1],
                        style: klein,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      );
    }
    Widget spalte(String titel, Widget wert, Widget? mitte, String unten) =>
        Expanded(
          child: KachelEingepasst(
            ausrichtung: AlignmentDirectional.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: farben.textGedaempft),
                ),
                const SizedBox(height: 2),
                wert,
                ?mitte,
                Text(
                  unten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: klein,
                ),
              ],
            ),
          ),
        );
    Widget trenner() => Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: farben.spur,
    );
    final jahre = t.t('statistics_years_short');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              spalte(
                t.t('statistics_new_short'),
                KachelZahl(
                  '${b.neuInZwoelfMonaten}',
                  groesse: 24,
                  ausrichtung: Alignment.center,
                ),
                ziel != null
                    ? FractionallySizedBox(
                        widthFactor: 0.7,
                        child: KachelMeter(
                          anteil: anteil(b.neuInZwoelfMonaten, ziel),
                        ),
                      )
                    : null,
                ziel != null
                    ? t.t('statistics_target_short', {'count': ziel})
                    : t.t('statistics_no_target_short'),
              ),
              trenner(),
              spalte(
                t.t('statistics_children_tenure'),
                KachelZahl(
                  zahlMitKomma(context, b.medianJahreKinder),
                  groesse: 24,
                  einheit: jahre,
                  ausrichtung: Alignment.center,
                ),
                null,
                t.t('statistics_median'),
              ),
              trenner(),
              spalte(
                t.t('statistics_leaders_tenure'),
                KachelZahl(
                  zahlMitKomma(context, b.medianJahreLeitende),
                  groesse: 24,
                  einheit: jahre,
                  ausrichtung: Alignment.center,
                ),
                null,
                t.t('statistics_median'),
              ),
            ],
          ),
        ),
        KachelFuss(t.t('statistics_only_current_members')),
      ],
    );
  }
}

class VerlaufKachel extends StatelessWidget {
  const VerlaufKachel({super.key, required this.daten, required this.groesse});

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final monate = _monate(t);
    final klein = groesse == KachelGroesse.klein;
    final anzahl = klein ? 6 : 12;
    // Der laufende Monat wird live gezeigt, auch wenn er noch nicht
    // aufgezeichnet ist; unlesbare Monate fallen weg.
    final dieserMonat = StatistikVerlaufEintrag.monatSchluessel(daten.heute);
    final punkte = <DateTime, int>{
      for (final e in daten.verlauf) ?_monatAus(e.monat): e.personen,
    };
    if (!daten.verlauf.any((e) => e.monat == dieserMonat)) {
      punkte[DateTime(daten.heute.year, daten.heute.month)] =
          daten.statistik.personen;
    }
    final letzter = punkte.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    final erster = punkte.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final fenster = DateTime(letzter.year, letzter.month - anzahl + 1);
    final start = erster.isAfter(fenster) ? erster : fenster;
    final achse = [
      for (var i = 0; i < anzahl; i++)
        () {
          final name = monate[DateTime(start.year, start.month + i).month - 1];
          if (!klein) return name.substring(0, 1);
          return i.isEven ? name : '';
        }(),
    ];
    final werte = <int?>[
      for (var i = 0; i < anzahl; i++)
        punkte[DateTime(start.year, start.month + i)],
    ];
    final abText = t.t('statistics_history_from', {
      'month': '${monate[start.month - 1]} ${start.year}',
    });
    final textStil = TextStyle(fontSize: 11, color: farben.textSchwach);
    if (klein) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: VerlaufKurve(werte: werte, monate: achse),
          ),
          Text(
            abText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStil.copyWith(
              fontWeight: FontWeight.w700,
              color: farben.text,
            ),
          ),
          Text(
            t.t('statistics_history_monthly_sums'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStil,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: VerlaufKurve(werte: werte, monate: achse),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                abText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textStil.copyWith(
                  fontWeight: FontWeight.w700,
                  color: farben.text,
                ),
              ),
              Text(
                t.t('statistics_history_monthly'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStil,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static DateTime? _monatAus(String schluessel) {
    final teile = schluessel.split('-');
    if (teile.length != 2) return null;
    final jahr = int.tryParse(teile[0]);
    final monat = int.tryParse(teile[1]);
    if (jahr == null || monat == null || monat < 1 || monat > 12) return null;
    return DateTime(jahr, monat);
  }
}
