import 'package:flutter/material.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_daten.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_katalog.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_raster.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/stories/statistik/statistik_kachel_beispiele.dart';
import 'package:nami/stories/story_tab_shell.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story statistikKachelnGalerieStory() {
  return Story(
    name: 'Statistik/Kacheln/Galerie',
    builder: (context) {
      final datensatz = context.knobs.options<StatistikBeispielDatensatz>(
        label: 'Datensatz',
        initial: StatistikBeispielDatensatz.weitblick,
        options: [
          for (final d in StatistikBeispielDatensatz.values)
            Option(label: d.label, value: d),
        ],
      );
      final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
      final textScale = storyTextScaleKnob(context.knobs);
      return StatistikKachelGalerie(
        datensatz: datensatz,
        dark: dark,
        textScale: textScale,
      );
    },
  );
}

/// Jede Kachel in jeder erlaubten Größe, nach Bereichen wie im Katalog.
class StatistikKachelGalerie extends StatelessWidget {
  const StatistikKachelGalerie({
    super.key,
    required this.datensatz,
    this.dark = false,
    this.textScale = 1,
  });

  final StatistikBeispielDatensatz datensatz;
  final bool dark;
  final double textScale;

  static const Map<KachelBereich, String> _titel = {
    KachelBereich.mitglieder: 'Mitglieder',
    KachelBereich.stufen: 'Stufen',
    KachelBereich.entwicklung: 'Entwicklung',
    KachelBereich.zusammensetzung: 'Zusammensetzung',
    KachelBereich.eigene: 'Eigene Kacheln',
  };

  @override
  Widget build(BuildContext context) {
    final daten = StatistikKachelBeispiele.daten(datensatz);
    final theme = buildTheme(
      AppPaletteId.standard,
      dark ? Brightness.dark : Brightness.light,
    );
    final bereiche = <KachelBereich, List<KachelEintrag>>{
      for (final bereich in KachelBereich.values)
        bereich: _eintraege(daten, bereich),
    }..removeWhere((_, eintraege) => eintraege.isEmpty);
    return Theme(
      data: theme,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppPageHeader.maxTextScaleFactor,
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final MapEntry(key: bereich, value: eintraege)
                      in bereiche.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                      child: Text(
                        _titel[bereich]!,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    KachelRaster(eintraege: eintraege, daten: daten),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<KachelEintrag> _eintraege(
    StatistikKachelDaten daten,
    KachelBereich bereich,
  ) {
    if (bereich == KachelBereich.eigene) {
      return [
        for (final eigene in daten.einstellungen.eigeneKacheln)
          for (final groesse in StatistikKachelTypen.groessenFuer(
            StatistikKachelTypen.eigene,
          ))
            KachelEintrag(
              id: 'galerie-${eigene.id}-${groesse.schluessel}',
              typId: StatistikKachelTypen.eigene,
              groesse: groesse,
              eigeneKachelId: eigene.id,
            ),
      ];
    }
    return [
      for (final definition in KachelKatalog.definitionen)
        if (definition.bereich == bereich)
          for (final groesse in definition.groessen)
            KachelEintrag(
              id: 'galerie-${definition.typId}-${groesse.schluessel}',
              typId: definition.typId,
              groesse: groesse,
            ),
    ];
  }
}
