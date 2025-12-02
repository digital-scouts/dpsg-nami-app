import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';
import 'package:nami/presentation/widgets/member_list_search_bar.dart';

Story searchBarStory() => Story(
  name: 'MemberList/Suchleiste',
  builder: (context) {
    final initial = context.knobs.text(
      label: 'Initialer Suchstring',
      initial: '',
    );
    String current = initial;
    return MemberSearchBar(
      initial: initial,
      onChanged: (v) {
        current = v;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Suche: "$current"')));
      },
    );
  },
);
