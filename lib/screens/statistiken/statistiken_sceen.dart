import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/alterBarChart.widget.dart';
import 'package:nami/screens/widgets/groupBarChart.widget.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/mitglied.dart';

import '../widgets/stufenwechselInfo.widget.dart';

enum StatistikType {
  stufen("Stufenverteilung"),
  alter("Altersverteilung");

  final String display;
  const StatistikType(this.display);
}

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  StatistikScreenState createState() => StatistikScreenState();
}

class StatistikScreenState extends State<StatistikScreen> {
  List<Mitglied> mitglieder = [];
  StatistikType selectedType = StatistikType.stufen;

  @override
  void initState() {
    super.initState();
    _loadMitglieder();
    hiveService.addMemberBoxListener(_loadMitglieder);
  }

  @override
  void dispose() {
    hiveService.removeMemberBoxListener(_loadMitglieder);
    super.dispose();
  }

  void _loadMitglieder() {
    setState(() {
      mitglieder = hiveService.getAllMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Center(child: Text('Statistiken'))),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Text(
            "Allgemeine Statistiken",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 5,
              children: [
                for (final type in StatistikType.values)
                  ChoiceChip(
                    label: Text(type.display),
                    selected: type == selectedType,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedType = type;
                        });
                      }
                    },
                  ),
              ],
            ),
          ),
          if (selectedType == StatistikType.stufen)
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: GroupBarChart(mitglieder: mitglieder),
              ),
            ),
          if (selectedType == StatistikType.alter)
            Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AlterBarChartWidget(mitglieder: mitglieder),
              ),
            ),
          const SizedBox(height: 15),
          Text(
            'Stufenwechselempfehlung',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const StufenwechselInfo(),
        ],
      ),
    );
  }
}
