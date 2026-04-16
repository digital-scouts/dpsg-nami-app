import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/member_list_search_bar.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story memberListSearchBarStory() {
  return Story(
    name: 'Mitglieder/Widgets/Liste/Suche',
    builder: (context) {
      final initial = context.knobs.text(label: 'Initialer Text', initial: '');
      final showSnack = context.knobs.boolean(
        label: 'Show Snack on Tune',
        initial: true,
      );
      return Card(
        child: MemberSearchBar(
          initial: initial,
          onChanged: (v) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Suche: "$v"')));
          },
          onTunePressed: showSnack
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filter/Optionen geöffnet')),
                )
              : null,
        ),
      );
    },
  );
}
