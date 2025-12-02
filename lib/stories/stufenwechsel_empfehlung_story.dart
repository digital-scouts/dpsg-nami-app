import 'package:flutter/material.dart';
import 'package:nami/domain/stufenwechsel/stufenwechsel_info.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/widgets/stufenwechsel_empfehlung.dart';
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
  ];
  return Story(
    name: 'Stufenwechsel/Empfehlung',
    builder: (context) => StufenwechselEmpfehlung(
      infos: infos,
      stufe: Stufe.woelfling,
      onTap: (id) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tap auf Mitglied $id')));
      },
    ),
  );
}
