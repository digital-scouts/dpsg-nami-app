import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/stufen_choice_chips.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenChoiceChipsStory({
  bool singleSelect = true,
  bool showLeader = false,
}) {
  return Story(
    name: 'Stufenwechsel/ChoiceChips',
    builder: (context) {
      final singleSelectKnob = context.knobs.boolean(
        label: 'Single Select',
        initial: singleSelect,
      );
      final showLeaderKnob = context.knobs.boolean(
        label: 'Leiter anzeigen',
        initial: showLeader,
      );
      final showBiberKnob = context.knobs.boolean(
        label: 'Biber anzeigen',
        initial: false,
      );
      Set<Stufe> selected = {Stufe.woelfling};
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StufenChoiceChips(
                singleSelect: singleSelectKnob,
                showBiber: showBiberKnob,
                showLeader: showLeaderKnob,
                ausgewaehlteStufen: selected,
                ausgewaehlteStufenChanged: (s) => setState(() => selected = s),
              ),
              const SizedBox(height: 16),
              Text('Ausgewählt: ${selected.map((s) => s.name).join(', ')}'),
            ],
          ),
        ),
      );
    },
  );
}
