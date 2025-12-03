import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/stufen_choice_chips.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenChoiceChipsStory({bool showBiber = true}) {
  return Story(
    name: 'Stufenwechsel/ChoiceChips',
    builder: (context) {
      final showBiberKnob = context.knobs.boolean(
        label: 'Biber anzeigen',
        initial: showBiber,
      );
      Stufe selected = showBiberKnob ? Stufe.biber : Stufe.woelfling;
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StufenChoiceChips(
                showBiber: showBiberKnob,
                ausgewaehlteStufe: selected,
                onChanged: (s) => setState(() => selected = s),
              ),
              const SizedBox(height: 16),
              Text('Ausgewählt: ${selected.name}'),
            ],
          ),
        ),
      );
    },
  );
}
