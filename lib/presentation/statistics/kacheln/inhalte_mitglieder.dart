import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/statistiks/stamm_statistik.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../statistik_farben.dart';
import 'diagramme.dart';
import 'kachel_daten.dart';
import 'kachel_rahmen.dart';

class PersonenKachel extends StatelessWidget {
  const PersonenKachel({super.key, required this.daten, required this.groesse});

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = daten.statistik;
    final farben = StatistikFarben.of(context);
    final klein = TextStyle(fontSize: 11, color: farben.textSchwach);
    if (groesse == KachelGroesse.klein) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KachelZahl('${s.personen}'),
          Text(
            '${s.kinder} ${t.t('statistics_children')}',
            style: klein,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [
              '${s.leitende} ${t.t('statistics_leaders')}',
              if (s.sonstige > 0) '${s.sonstige} ${t.t('statistics_others')}',
            ].join(' · '),
            style: klein,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    Widget zeile(int wert, String text) => Row(
      children: [
        SizedBox(
          width: 36,
          child: KachelZahl(
            '$wert',
            groesse: 17,
            ausrichtung: Alignment.centerRight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: farben.textGedaempft),
          ),
        ),
      ],
    );
    return Row(
      children: [
        Flexible(child: KachelZahl('${s.personen}', groesse: 40)),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              zeile(s.kinder, t.t('statistics_children')),
              zeile(s.leitende, t.t('statistics_leaders')),
              if (s.sonstige > 0) zeile(s.sonstige, t.t('statistics_others')),
            ],
          ),
        ),
      ],
    );
  }
}

class StufenKachel extends StatelessWidget {
  const StufenKachel({super.key, required this.daten});

  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final stufen = daten.statistik.stufen.where((s) => s.kinder > 0).toList();
    return KachelEingepasst(
      ausrichtung: AlignmentDirectional.topStart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiagrammBand(
            hoehe: 14,
            teile: [
              for (final s in stufen)
                DiagrammTeil(
                  wert: s.kinder,
                  farbe: farben.stufe(s.stufe),
                  kontur: farben.kontur(s.stufe),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final s in stufen)
                stufenSchluessel(context, s.stufe, wert: '${s.kinder}'),
            ],
          ),
        ],
      ),
    );
  }
}

class GruppenKachel extends StatelessWidget {
  const GruppenKachel({super.key, required this.daten, required this.groesse});

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    return groesse == KachelGroesse.gross
        ? _GruppenListe(daten: daten)
        : _GruppenJeStufe(daten: daten);
  }
}

class _GruppenJeStufe extends StatelessWidget {
  const _GruppenJeStufe({required this.daten});

  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stufen = daten.statistik.stufen
        .where((s) => s.kinder > 0 || s.gruppen.isNotEmpty)
        .toList();
    if (stufen.isEmpty) return KachelLeer(t.t('statistics_no_data'));
    final hatZiele = daten.ziele.gruppeMax.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in stufen) ...[
              if (s != stufen.first) const SizedBox(width: 8),
              Expanded(
                child: _StufenSpalte(stufe: s, daten: daten),
              ),
            ],
          ],
        ),
        KachelRest(
          child: KachelFuss(
            [
              t.t('statistics_groups_legend'),
              if (hatZiele) '| ${t.t('statistics_target')}',
            ].join(' · '),
          ),
        ),
      ],
    );
  }
}

class _StufenSpalte extends StatelessWidget {
  const _StufenSpalte({required this.stufe, required this.daten});

  final StufenStatistik stufe;
  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final ziel = daten.ziele.zielFuerStufe(stufe.stufe, stufe.gruppen.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KachelZahl(
          '${stufe.kinder}',
          groesse: 22,
          zusatz: '+${stufe.leitende}',
        ),
        Text(
          stufe.stufe.shortDisplayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: farben.textGedaempft),
        ),
        const SizedBox(height: 4),
        ZielBalken(
          wert: stufe.kinder,
          skala: math.max(1, math.max(stufe.kinder, ziel ?? 0)),
          ziel: ziel,
          farbe: farben.stufe(stufe.stufe),
          kontur: farben.kontur(stufe.stufe),
          dicke: 3,
        ),
      ],
    );
  }
}

class _GruppenListe extends StatelessWidget {
  const _GruppenListe({required this.daten});

  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = daten.statistik;
    final gruppen = s.stufen.expand((st) => st.gruppen).toList();
    if (gruppen.isEmpty) return KachelLeer(t.t('statistics_no_data'));
    final skala = math.max(
      1,
      [
        s.groessteGruppe,
        ...daten.ziele.gruppeMax.values,
      ].fold<int>(0, math.max),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final zeilenHoehe = textScaler.scale(17) + textScaler.scale(10) + 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final kapazitaet = math.max(
          1,
          (constraints.maxHeight / zeilenHoehe).floor(),
        );
        final zuViele = gruppen.length > kapazitaet;
        final sichtbar = zuViele
            ? gruppen.take(math.max(0, kapazitaet - 1)).toList()
            : gruppen;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in sichtbar)
              SizedBox(
                height: zeilenHoehe,
                child: _GruppenZeile(
                  gruppe: g,
                  skala: skala,
                  ziel: daten.ziele.gruppeMax[g.stufe],
                  onTap: daten.onGruppeOeffnen == null
                      ? null
                      : () => daten.onGruppeOeffnen!(g.gruppenId),
                  trenner: g != sichtbar.last || zuViele,
                ),
              ),
            if (zuViele)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t.t('statistics_groups_more', {
                    'count': gruppen.length - sichtbar.length,
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GruppenZeile extends StatelessWidget {
  const _GruppenZeile({
    required this.gruppe,
    required this.skala,
    required this.ziel,
    required this.onTap,
    required this.trenner,
  });

  final GruppenStatistik gruppe;
  final int skala;
  final int? ziel;
  final VoidCallback? onTap;
  final bool trenner;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final farbe = farben.stufe(gruppe.stufe);
    final kontur = farben.kontur(gruppe.stufe);
    final inhalt = DecoratedBox(
      decoration: BoxDecoration(
        border: trenner ? Border(bottom: BorderSide(color: farben.spur)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: farbe,
              shape: BoxShape.circle,
              border: kontur != null ? Border.all(color: kontur) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: gruppe.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: farben.text,
                    ),
                    children: [
                      TextSpan(
                        text:
                            '  ${t.t('statistics_group_subtitle', {'stage': gruppe.stufe.displayName, 'count': gruppe.leitende})}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: farben.textSchwach,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                ZielBalken(
                  wert: gruppe.kinder,
                  skala: skala,
                  ziel: ziel,
                  farbe: farbe,
                  kontur: kontur,
                  dicke: 5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: KachelZahl(
              '${gruppe.kinder}',
              groesse: 20,
              zusatz: '+${gruppe.leitende}',
              ausrichtung: Alignment.centerRight,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return inhalt;
    return InkWell(onTap: onTap, child: inhalt);
  }
}
