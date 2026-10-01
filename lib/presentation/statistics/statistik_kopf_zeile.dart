import 'package:flutter/material.dart';

import '../../domain/statistiks/stamm_statistik.dart';
import '../../l10n/app_localizations.dart';
import 'kacheln/diagramme.dart';
import 'kacheln/kachel_rahmen.dart';
import 'statistik_farben.dart';

/// Erste Zeile des Statistik-Headers: Gesamtzahl und Stufenband mit
/// Legende. Füllt die vom `AppPageHeader` vorgegebene Zeilenhöhe; Zahl und
/// Legende schrumpfen bei großer Schrift, statt umzubrechen.
class StatistikKopfZeile extends StatelessWidget {
  const StatistikKopfZeile({super.key, required this.statistik});

  final StammStatistik statistik;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final farben = StatistikFarben.of(context);
    final stufen = statistik.stufen.where((s) => s.kinder > 0).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          constraints: const BoxConstraints(minWidth: 62),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${statistik.personen}',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                Text(
                  t.t('statistics_people'),
                  style: TextStyle(fontSize: 11, color: farben.textGedaempft),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DiagrammBand(
                hoehe: 10,
                teile: [
                  for (final s in stufen)
                    DiagrammTeil(
                      wert: s.kinder,
                      farbe: farben.stufe(s.stufe),
                      kontur: farben.kontur(s.stufe),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    for (final s in stufen) ...[
                      if (s != stufen.first) const SizedBox(width: 9),
                      stufenSchluessel(
                        context,
                        s.stufe,
                        wert: '${s.kinder}',
                        klein: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
