import 'package:flutter/material.dart';

import '../../../domain/statistiks/stamm_statistik.dart';
import '../../../domain/statistiks/statistik_kachel_typen.dart';
import '../../../domain/statistiks/statistik_mathe.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../statistik_farben.dart';
import 'diagramme.dart';
import 'kachel_daten.dart';
import 'kachel_rahmen.dart';

List<StufenStatistik> _mitAlter(StatistikKachelDaten daten) =>
    daten.statistik.stufen.where((s) => s.alter.isNotEmpty).toList();

class AltersstrukturKachel extends StatelessWidget {
  const AltersstrukturKachel({
    super.key,
    required this.daten,
    this.groesse = KachelGroesse.gross,
  });

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final stufen = _mitAlter(daten);
    final ohne = daten.statistik.ohneGeburtsdatum;
    final fuss = [
      t.t('statistics_age_footer'),
      if (ohne > 0) t.t('statistics_without_birthday', {'count': ohne}),
    ].join(' · ');
    if (stufen.isEmpty) {
      return KachelLeer(
        [t.t('statistics_no_birthdays'), if (ohne > 0) fuss].join('\n'),
      );
    }
    final zeilen = [
      for (final s in stufen)
        AltersZeile(
          beschriftung: s.stufe.shortDisplayName,
          alter: s.alter,
          min: daten.grenzen.forStufe(s.stufe).minJahre,
          max: daten.grenzen.forStufe(s.stufe).maxJahre,
          farbe: farben.stufe(s.stufe),
          flaeche: farben.grenzFlaeche(s.stufe),
          kontur: farben.kontur(s.stufe),
        ),
    ];
    // In 2×1 ist kein Platz für die Fußzeile; die Leiste unter der Achse
    // zeigt die Altersgrenzen.
    if (groesse == KachelGroesse.breit) {
      return AltersSaeulenGestapelt(zeilen: zeilen);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: AltersSaeulen(zeilen: zeilen)),
        const SizedBox(height: 4),
        KachelFuss(fuss, zeilen: 2),
      ],
    );
  }
}

class AlterInZahlenKachel extends StatelessWidget {
  const AlterInZahlenKachel({
    super.key,
    required this.daten,
    required this.groesse,
  });

  final StatistikKachelDaten daten;
  final KachelGroesse groesse;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stufen = _mitAlter(daten);
    if (stufen.isEmpty) return KachelLeer(t.t('statistics_no_birthdays'));
    if (groesse == KachelGroesse.breit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in stufen) ...[
                if (s != stufen.first) const SizedBox(width: 8),
                Expanded(
                  child: _Spalte(stufe: s, daten: daten),
                ),
              ],
            ],
          ),
          KachelRest(
            child: KachelFuss(t.t('statistics_age_numbers_footer_wide')),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final s in stufen) _Zeile(stufe: s, daten: daten)],
          ),
        ),
        KachelFuss(t.t('statistics_age_numbers_footer_large')),
      ],
    );
  }
}

String _spanne(List<double> alter) {
  final lo = alter.reduce((a, b) => a < b ? a : b).floor();
  final hi = alter.reduce((a, b) => a > b ? a : b).floor();
  return '$lo–$hi';
}

class _Spalte extends StatelessWidget {
  const _Spalte({required this.stufe, required this.daten});

  final StufenStatistik stufe;
  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final grenze = daten.grenzen.forStufe(stufe.stufe);
    final klein = TextStyle(fontSize: 10.5, color: farben.textSchwach);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stufe.stufe.shortDisplayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: farben.textGedaempft),
        ),
        KachelZahl(zahlMitKomma(context, median(stufe.alter)), groesse: 22),
        const SizedBox(height: 3),
        AltersStreifen(
          alter: stufe.alter,
          min: grenze.minJahre,
          max: grenze.maxJahre,
          farbe: farben.stufe(stufe.stufe),
          flaeche: farben.grenzFlaeche(stufe.stufe),
          kontur: farben.kontur(stufe.stufe),
          hoehe: 10,
        ),
        const SizedBox(height: 2),
        Text(
          '${_spanne(stufe.alter)} ${t.t('statistics_years_short')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: klein,
        ),
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({required this.stufe, required this.daten});

  final StufenStatistik stufe;
  final StatistikKachelDaten daten;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final grenze = daten.grenzen.forStufe(stufe.stufe);
    return Row(
      children: [
        SizedBox(width: 64, child: stufenSchluessel(context, stufe.stufe)),
        SizedBox(
          width: 62,
          child: KachelZahl(
            zahlMitKomma(context, median(stufe.alter)),
            groesse: 20,
            einheit: t.t('statistics_years_short'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AltersStreifen(
            alter: stufe.alter,
            min: grenze.minJahre,
            max: grenze.maxJahre,
            farbe: farben.stufe(stufe.stufe),
            flaeche: farben.grenzFlaeche(stufe.stufe),
            kontur: farben.kontur(stufe.stufe),
            hoehe: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _spanne(stufe.alter),
          style: TextStyle(
            fontSize: 10.5,
            color: farben.textSchwach,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
