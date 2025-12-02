import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/statistiks/group_distribution.dart';
import '../domain/taetigkeit/stufe.dart';
import '../domain/taetigkeit/taetigkeit.dart';
import '../presentation/widgets/statistik_groupdistribution.dart';

Story groupDistributionStory() {
  return Story(
    name: 'Statistik/GroupDistribution',
    builder: (context) {
      final seed = context.knobs.sliderInt(
        label: 'Seed',
        initial: 1,
        min: 1,
        max: 50,
      );
      // Pro-Stufe Mitgliederregler
      final perBiber = context.knobs.sliderInt(
        label: 'Biber Mitglieder',
        initial: 8,
        min: 0,
        max: 40,
      );
      final perWoelfling = context.knobs.sliderInt(
        label: 'Wölfling Mitglieder',
        initial: 8,
        min: 0,
        max: 40,
      );
      final perJufi = context.knobs.sliderInt(
        label: 'Jungpfadfinder Mitglieder',
        initial: 8,
        min: 0,
        max: 40,
      );
      final perPfadi = context.knobs.sliderInt(
        label: 'Pfadfinder Mitglieder',
        initial: 8,
        min: 0,
        max: 40,
      );
      final perRover = context.knobs.sliderInt(
        label: 'Rover Mitglieder',
        initial: 8,
        min: 0,
        max: 40,
      );
      final leitungFaktor = context.knobs.sliderInt(
        label: 'Leitung-Faktor (%)',
        initial: 25,
        min: 0,
        max: 100,
      );
      final rnd = _LCG(seed);
      final stufen = [
        Stufe.biber,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
      ];
      final taetigkeiten = <Taetigkeit>[];
      for (final s in stufen) {
        // Mitglieder abhängig von Stufe-Regler
        final perStufeMitglieder = switch (s) {
          Stufe.biber => perBiber,
          Stufe.woelfling => perWoelfling,
          Stufe.jungpfadfinder => perJufi,
          Stufe.pfadfinder => perPfadi,
          Stufe.rover => perRover,
          Stufe.leitung => 0,
        };
        for (int i = 0; i < perStufeMitglieder; i++) {
          taetigkeiten.add(
            Taetigkeit(
              stufe: s,
              art: TaetigkeitsArt.mitglied,
              start: DateTime(2024, 1, 1),
            ),
          );
        }
        // Leitende (prozentual)
        final leitungAnzahl = ((perStufeMitglieder * leitungFaktor) / 100)
            .round()
            .clamp(0, perStufeMitglieder);
        for (int i = 0; i < leitungAnzahl; i++) {
          taetigkeiten.add(
            Taetigkeit(
              stufe: s,
              art: TaetigkeitsArt.leitung,
              start: DateTime(2023, 6, 1),
            ),
          );
        }
        // Zufällige inaktive Leitung um Verhalten zu zeigen
        if (rnd.nextInt(100) < 30) {
          taetigkeiten.add(
            Taetigkeit(
              stufe: s,
              art: TaetigkeitsArt.leitung,
              start: DateTime(2022, 1, 1),
              ende: DateTime(2024, 5, 1),
            ),
          );
        }
      }
      final dist = computeGroupDistributions(taetigkeiten);
      return GroupDistributionChart(data: dist);
    },
  );
}

class _LCG {
  _LCG(int seed) : _state = seed;
  int _state;
  int nextInt(int max) {
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state % max;
  }
}
