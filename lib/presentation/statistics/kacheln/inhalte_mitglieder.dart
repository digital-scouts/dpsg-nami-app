import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/statistiks/stamm_statistik.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../statistik_farben.dart';
import 'diagramme.dart';
import '../gruppen_auswahl.dart';
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

  /// Bis zu so vielen Gruppen zeigt 2×1 eine Spalte je Gruppe statt je Stufe.
  static const int maxGruppenspalten = 2;

  /// 2×2: bis so viele Gruppen als Liste, bis [maxZellen] in zwei Spalten,
  /// darüber als Chips je Stufe. So bleiben alle Gruppen sichtbar.
  static const int maxListe = 6;
  static const int maxZellen = 12;

  static int anzahlGruppen(StatistikKachelDaten daten) =>
      daten.statistik.stufen.fold(0, (n, s) => n + s.gruppen.length);

  static bool zeigtStufen(StatistikKachelDaten daten, KachelGroesse groesse) =>
      groesse == KachelGroesse.breit &&
      anzahlGruppen(daten) > maxGruppenspalten;

  @override
  Widget build(BuildContext context) {
    final gruppen = daten.statistik.stufen.expand((s) => s.gruppen).toList();
    if (groesse == KachelGroesse.gross) {
      if (gruppen.length > maxZellen) return _GruppenChips(daten: daten);
      if (gruppen.length > maxListe) return _GruppenZellen(daten: daten);
      return _GruppenListe(daten: daten);
    }
    return gruppen.isNotEmpty && gruppen.length <= maxGruppenspalten
        ? _GruppenSpalten(daten: daten, gruppen: gruppen)
        : _GruppenJeStufe(daten: daten);
  }
}

/// Öffnet die Gruppenauswahl und danach die gewählte Gruppe.
Future<void> oeffneGruppeAusAuswahl(
  BuildContext context,
  StatistikKachelDaten daten, {
  Stufe? nurStufe,
}) async {
  final oeffnen = daten.onGruppeOeffnen;
  if (oeffnen == null) return;
  final id = await zeigeGruppenAuswahl(
    context,
    stufen: daten.statistik.stufen,
    nurStufe: nurStufe,
  );
  if (id != null) oeffnen(id);
}

/// Zwei Spalten kompakter Zellen (7 bis 12 Gruppen): Name, Zahl, Balken.
class _GruppenZellen extends StatelessWidget {
  const _GruppenZellen({required this.daten});

  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final gruppen = daten.statistik.stufen.expand((s) => s.gruppen).toList();
    final skala = math.max(1, daten.statistik.groessteGruppe);
    final zeilen = (gruppen.length / 2).ceil();
    final oeffnen = daten.onGruppeOeffnen;
    Widget zelle(GruppenStatistik g) => Material(
      color: farben.spur.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('gruppen-zelle-${g.gruppenId}'),
        onTap: oeffnen == null ? null : () => oeffnen(g.gruppenId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
          child: _Einpassen(
            ausrichtung: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _kurzname(g.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: farben.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    KachelZahl(
                      '${g.kinder}',
                      groesse: 15,
                      zusatz: '+${g.leitende}',
                      ausrichtung: Alignment.centerRight,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ZielBalken(
                  wert: g.kinder,
                  skala: skala,
                  ziel: daten.ziele.gruppeMax[g.stufe],
                  farbe: farben.stufe(g.stufe),
                  kontur: farben.kontur(g.stufe),
                  dicke: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (var z = 0; z < zeilen; z++) ...[
          if (z > 0) const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: zelle(gruppen[2 * z])),
                const SizedBox(width: 8),
                Expanded(
                  child: 2 * z + 1 < gruppen.length
                      ? zelle(gruppen[2 * z + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Je Stufe eine Zeile, die Gruppen als Chips (ab 13 Gruppen).
class _GruppenChips extends StatelessWidget {
  const _GruppenChips({required this.daten});

  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final stufen = daten.statistik.stufen
        .where((s) => s.gruppen.isNotEmpty)
        .toList();
    final oeffnen = daten.onGruppeOeffnen;
    return _Einpassen(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in stufen) ...[
            if (s != stufen.first) Divider(height: 9, color: farben.spur),
            Row(
              children: [
                SizedBox(width: 56, child: stufenSchluessel(context, s.stufe)),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final g in s.gruppen)
                        Material(
                          color: farben.spur.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(99),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('gruppen-chip-${g.gruppenId}'),
                            onTap: oeffnen == null
                                ? null
                                : () => oeffnen(g.gruppenId),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  text: _kurzname(g.name),
                                  children: [
                                    TextSpan(
                                      text: ' ${g.kinder}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: farben.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Verkleinert [child] gleichmäßig, wenn es nicht in den verfügbaren Platz
/// passt, statt es abzuschneiden; die Breite bleibt die verfügbare Breite.
class _Einpassen extends StatelessWidget {
  const _Einpassen({required this.child, this.ausrichtung = Alignment.topLeft});

  final Widget child;
  final Alignment ausrichtung;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: ausrichtung,
        child: SizedBox(width: constraints.maxWidth, child: child),
      ),
    );
  }
}

/// „Meute Wirbelwind“ → „Wirbelwind“; die Stufe zeigt schon die Farbe.
String _kurzname(String name) {
  final kurz = name.replaceFirst(
    RegExp(r'^(Biber|Meute|Trupp|Runde|Rotte|Sippe)\s+', caseSensitive: false),
    '',
  );
  return kurz.isEmpty ? name : kurz;
}

/// Wenige Gruppen, z. B. bei Teilsicht oder zwei Meuten: je Gruppe eine
/// Spalte; ein Tipp öffnet die Gruppe.
class _GruppenSpalten extends StatelessWidget {
  const _GruppenSpalten({required this.daten, required this.gruppen});

  final StatistikKachelDaten daten;
  final List<GruppenStatistik> gruppen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final oeffnen = daten.onGruppeOeffnen;
    final hatZiele = daten.ziele.gruppeMax.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in gruppen) ...[
              if (g != gruppen.first) const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  key: Key('gruppen-spalte-${g.gruppenId}'),
                  onTap: oeffnen == null ? null : () => oeffnen(g.gruppenId),
                  borderRadius: BorderRadius.circular(8),
                  child: _GruppenSpalte(gruppe: g, daten: daten),
                ),
              ),
            ],
          ],
        ),
        KachelRest(
          child: KachelFuss(
            [
              t.t('statistics_groups_legend'),
              if (oeffnen != null) t.t('statistics_groups_tap_hint'),
              if (hatZiele) '| ${t.t('statistics_target')}',
            ].join(' · '),
          ),
        ),
      ],
    );
  }
}

class _GruppenSpalte extends StatelessWidget {
  const _GruppenSpalte({required this.gruppe, required this.daten});

  final GruppenStatistik gruppe;
  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final farben = StatistikFarben.of(context);
    final ziel = daten.ziele.gruppeMax[gruppe.stufe];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KachelZahl(
          '${gruppe.kinder}',
          groesse: 22,
          zusatz: '+${gruppe.leitende}',
        ),
        Row(
          children: [
            Flexible(
              child: Text(
                gruppe.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: farben.textGedaempft),
              ),
            ),
            if (daten.onGruppeOeffnen != null)
              Icon(Icons.chevron_right, size: 14, color: farben.textSchwach),
          ],
        ),
        const SizedBox(height: 4),
        ZielBalken(
          wert: gruppe.kinder,
          skala: math.max(1, math.max(gruppe.kinder, ziel ?? 0)),
          ziel: ziel,
          farbe: farben.stufe(gruppe.stufe),
          kontur: farben.kontur(gruppe.stufe),
          dicke: 3,
        ),
      ],
    );
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
                child: InkWell(
                  key: Key('stufen-spalte-${s.stufe.name}'),
                  borderRadius: BorderRadius.circular(8),
                  // Eine Gruppe: direkt öffnen; mehrere: Auswahl dieser Stufe.
                  onTap: daten.onGruppeOeffnen == null || s.gruppen.isEmpty
                      ? null
                      : s.gruppen.length == 1
                      ? () => daten.onGruppeOeffnen!(s.gruppen.single.gruppenId)
                      : () => oeffneGruppeAusAuswahl(
                          context,
                          daten,
                          nurStufe: s.stufe,
                        ),
                  child: _StufenSpalte(stufe: s, daten: daten),
                ),
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
        if (stufe.gruppen.isNotEmpty)
          Text(
            gruppenAnzahlText(
              AppLocalizations.of(context),
              stufe.gruppen.length,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: farben.textSchwach),
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
            // Nur bei sehr großer Schrift: Die übrigen Gruppen bleiben über
            // die Auswahl erreichbar.
            if (zuViele)
              InkWell(
                key: const Key('gruppen-weitere'),
                onTap: daten.onGruppeOeffnen == null
                    ? null
                    : () => oeffneGruppeAusAuswahl(context, daten),
                child: Padding(
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
