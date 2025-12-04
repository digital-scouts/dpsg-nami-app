import 'package:flutter/material.dart';
import 'package:nami/domain/stufenwechsel/stufenwechsel_info.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/stufenwechsel_empfehlung.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenwechselEmpfehlungStory() {
  final infos = [
    StufenwechselInfo(
      id: 'w1',
      vorname: 'Max',
      stufe: Stufe.woelfling,
      alterZumStichtag: const Duration(days: (10 * 365) + (2 * 30)),
      wechselzeitraum: const Wechselzeitraum(startJahr: 2025, endJahr: 2027),
      shouldWechselNext: true,
    ),
    StufenwechselInfo(
      id: 'w2',
      vorname: 'Mia',
      stufe: Stufe.woelfling,
      alterZumStichtag: const Duration(days: (9 * 365) + (11 * 30)),
      wechselzeitraum: const Wechselzeitraum(startJahr: 2025, endJahr: 2025),
      shouldWechselNext: true,
    ),
    StufenwechselInfo(
      id: 'j1',
      vorname: 'Jonas',
      stufe: Stufe.jungpfadfinder,
      alterZumStichtag: const Duration(days: (12 * 365) + (6 * 30)),
      wechselzeitraum: const Wechselzeitraum(startJahr: 2026, endJahr: 2028),
      shouldWechselNext: true,
    ),
    StufenwechselInfo(
      id: 'p1',
      vorname: 'Paula',
      stufe: Stufe.pfadfinder,
      alterZumStichtag: const Duration(days: (15 * 365) + (3 * 30)),
      wechselzeitraum: const Wechselzeitraum(startJahr: 2027, endJahr: 2029),
      shouldWechselNext: false,
    ),
    StufenwechselInfo(
      id: 'r1',
      vorname: 'Robert',
      stufe: Stufe.rover,
      alterZumStichtag: const Duration(days: (18 * 365) + (0 * 30)),
      wechselzeitraum: const Wechselzeitraum(startJahr: 2028, endJahr: null),
      shouldWechselNext: false,
    ),
  ];
  return Story(
    name: 'Stufenwechsel/EmpfehlungTabelle',
    builder: (context) {
      final showBiber = context.knobs.boolean(label: 'Biber', initial: false);
      final showWoe = context.knobs.boolean(label: 'Wölfling', initial: true);
      final showJufi = context.knobs.boolean(label: 'Jufi', initial: true);
      final showPfadi = context.knobs.boolean(label: 'Pfadi', initial: false);
      final showRover = context.knobs.boolean(label: 'Rover', initial: false);
      final stichtag = DateTime.now();

      final stufen = <Stufe>[
        if (showBiber) Stufe.biber,
        if (showWoe) Stufe.woelfling,
        if (showJufi) Stufe.jungpfadfinder,
        if (showPfadi) Stufe.pfadfinder,
        if (showRover) Stufe.rover,
      ];

      return StufenwechselEmpfehlung(
        infos: infos,
        stufen: stufen,
        stichtag: stichtag,
        onTap: (id) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Tap auf Mitglied $id')));
        },
      );
    },
  );
}
