import 'package:nami/presentation/stufe/stufe_visuals.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/taetigkeit/stufe.dart';
import '../presentation/widgets/member_list_group_filter_bar.dart';

Story groupFilterStory() => Story(
  name: 'MemberList/Group Filter',
  builder: (context) {
    final itemSize = context.knobs.slider(
      label: 'Item Size',
      initial: 50,
      min: 36,
      max: 80,
    );

    final stufen = Stufe.values;
    final items = stufen
        .map(
          (s) => GroupFilterItem(
            keyName: s.name,
            imageAssetPath: StufeVisuals.assetFor(s),
            semanticLabel: '${s.displayName} Filter',
          ),
        )
        .toList();

    // Auswahl per Boolean-Knobs identisch zur MemberList Story
    final selectedKeys = <String>{};
    for (final s in stufen) {
      final active = context.knobs.boolean(
        label: 'Filter ${s.displayName}',
        initial: false,
      );
      if (active) selectedKeys.add(s.name);
    }

    return GroupFilterBar(
      items: items,
      selectedKeys: selectedKeys,
      itemSize: itemSize,
      onChanged: (_) {}, // deaktiviert
    );
  },
);
