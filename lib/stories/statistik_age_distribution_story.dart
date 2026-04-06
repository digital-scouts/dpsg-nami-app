// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/statistiks/age_distribution.dart';
import '../domain/taetigkeit/roles.dart';
import '../domain/taetigkeit/stufe.dart';
import '../presentation/widgets/statistik_agedistribution.dart';

Story ageDistributionStory() {
  return Story(
    name: 'Statistik/AgeDistribution',
    builder: (context) {
      final minAge = context.knobs.sliderInt(
        label: 'Global Mindestalter',
        initial: 4,
        min: 4,
        max: 15,
      );
      final maxAge = context.knobs.sliderInt(
        label: 'Global Maxalter',
        initial: 21,
        min: minAge + 5,
        max: 30,
      );
      final count = context.knobs.sliderInt(
        label: 'Anzahl Mitglieder',
        initial: 40,
        min: 5,
        max: 200,
      );
      final seed = context.knobs.sliderInt(
        label: 'Seed',
        initial: 1,
        min: 1,
        max: 100,
      );

      final rnd = _LCG(seed);
      final now = DateTime.now();
      final stufen = [
        Stufe.biber,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
        Stufe.woelfling,
        Stufe.jungpfadfinder,
        Stufe.pfadfinder,
        Stufe.rover,
      ];
      final List<MemberAgeInfo> members = [];
      for (int i = 0; i < count; i++) {
        final stufe = stufen[rnd.nextInt(stufen.length)];
        // Nutze stufenspezifische Altersgrenzen, aber clamp auf globale Grenzen.
        final sMin = stufe.defaultMinAge.toInt();
        final sMax = stufe.defaultMaxAge.toInt();
        final low = sMin < minAge ? minAge : sMin;
        final high = sMax > maxAge ? maxAge : sMax;
        if (high < low) continue; // Falls globale Grenzen außerhalb liegen
        final age = low + rnd.nextInt(high - low + 1);
        final month = rnd.nextInt(12) + 1;
        final day = (rnd.nextInt(27) + 1);
        final birthYear = now.year - age;
        final birthDate = DateTime(birthYear, month, day);
        members.add(
          MemberAgeInfo(
            stufe: stufe,
            birthDate: birthDate,
            art: RoleCategory.mitglied,
          ),
        );
      }
      // Füge einige Leitung / Sonstiges hinzu zur Demonstration der Filterung
      for (int i = 0; i < (count / 10).round(); i++) {
        final stufe = stufen[rnd.nextInt(stufen.length)];
        final sMin = stufe.defaultMinAge.toInt();
        final sMax = stufe.defaultMaxAge.toInt();
        final low = sMin < minAge ? minAge : sMin;
        final high = sMax > maxAge ? maxAge : sMax;
        if (high < low) continue;
        final age = low + rnd.nextInt(high - low + 1);
        final birthDate = DateTime(now.year - age, 1, 1);
        members.add(
          MemberAgeInfo(
            stufe: stufe,
            birthDate: birthDate,
            art: RoleCategory.leitung,
          ),
        );
      }
      final data = computeAgeDistribution(members);
      return AgeDistributionChart(data: data);
    },
  );
}

class _LCG {
  _LCG(int seed) : _state = seed;
  int _state;
  // Einfacher Linear Congruential Generator für reproduzierbare Story-Daten.
  int nextInt(int max) {
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state % max;
  }
}
