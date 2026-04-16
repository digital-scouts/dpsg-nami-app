import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story appBottomNavigationStory() {
  return Story(
    name: 'App/Navigation/BottomNavigation',
    builder: (context) {
      final current = context.knobs
          .slider(label: 'Aktiver Tab', initial: 0, min: 0, max: 3)
          .round();

      return Scaffold(
        appBar: AppBar(title: const Text('BottomNavigation Preview')),
        body: Center(child: Text('Aktiver Tab: $current')),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: current,
          onTap: (i) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Tab $i gewählt')));
          },
        ),
      );
    },
  );
}
