import 'package:flutter/material.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/statistics_group_detail_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story statisticsPageStory() {
  return Story(
    name: 'Statistik/Seite/Uebersicht',
    builder: (context) => MaterialApp(
      onGenerateRoute: onGenerateRoute,
      home: const Scaffold(body: StatisticsPage()),
    ),
  );
}

Story statisticsGroupDetailStory() {
  return Story(
    name: 'Statistik/Seite/Gruppendetail',
    builder: (context) {
      final groupId = context.knobs.options<String>(
        label: 'Gruppe',
        initial: 'woe',
        options: const [
          Option(label: 'Woelflinge', value: 'woe'),
          Option(label: 'Jungpfadfinder', value: 'jup'),
          Option(label: 'Pfadfinder', value: 'pf'),
          Option(label: 'Rover', value: 'rov'),
        ],
      );
      return MaterialApp(home: StatisticsGroupDetailPage(groupId: groupId));
    },
  );
}
