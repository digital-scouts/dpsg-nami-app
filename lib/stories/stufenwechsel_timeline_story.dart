import 'package:flutter/material.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/stufenwechsel_timeline.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenwechselTimelineStory() {
  return Story(
    name: 'Stufenwechsel/Widgets/Timeline',
    builder: (context) {
      final stufeIndex = context.knobs.options(
        label: 'Stufe',
        initial: Stufe.woelfling,
        options: [
          Option(label: 'Biber', value: Stufe.biber),
          Option(label: 'Wölfling', value: Stufe.woelfling),
          Option(label: 'Jungpfadfinder', value: Stufe.jungpfadfinder),
          Option(label: 'Pfadfinder', value: Stufe.pfadfinder),
          Option(label: 'Rover', value: Stufe.rover),
        ],
      );

      final alterJahre = context.knobs.sliderInt(
        label: 'Alter (Jahre)',
        initial: 10,
        min: 5,
        max: 20,
      );

      // Altersgrenzen per Knobs – je Stufe
      int knobMin(Stufe s, int def) => context.knobs.sliderInt(
        label: 'Min ${s.shortDisplayName}',
        initial: def,
        min: 1,
        max: 99,
      );
      int knobMax(Stufe s, int def) => context.knobs.sliderInt(
        label: 'Max ${s.shortDisplayName}',
        initial: def,
        min: 1,
        max: 99,
      );

      final defaults = StufenDefaults.build();
      final grenzen = Altersgrenzen({
        for (final s in Stufe.values)
          s: AltersIntervall(
            minJahre: knobMin(s, defaults.forStufe(s).minJahre),
            maxJahre: knobMax(s, defaults.forStufe(s).maxJahre),
          ),
      });

      final heute = DateTime.now();
      final geburtsdatum = DateTime(
        heute.year - alterJahre,
        heute.month,
        heute.day,
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktuelle Stufe: ${stufeIndex.shortDisplayName} | Alter: $alterJahre Jahre',
            ),
            const SizedBox(height: 12),
            StufenwechselTimeline(
              geburtsdatum: geburtsdatum,
              aktuelleStufe: stufeIndex,
              grenzen: grenzen,
            ),
          ],
        ),
      );
    },
  );
}
