import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/widgets/alterBarChart.widget.dart';
import 'package:nami/screens/widgets/groupBarChart.widget.dart';
import 'package:nami/utilities/hive/mitglied.dart';

import '../widgets/stufenwechselInfo.widget.dart';

enum StatistikType {
  stufen("Stufenverteilung"),
  alter("Altersverteilung");

  final String display;
  const StatistikType(this.display);
}

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({Key? key}) : super(key: key);

  @override
  StatistikScreenState createState() => StatistikScreenState();
}

class StatistikScreenState extends State<StatistikScreen> {
  Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();
  StatistikType selectedType = StatistikType.stufen;
  @override
  void initState() {
    super.initState();
    memberBox.listenable().addListener(() {
      mitglieder = memberBox.values.toList().cast<Mitglied>();
    });
  }

  @override
  Widget build(BuildContext context) {
    const double spacing = 10.0;
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Statistiken')),
      ),
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
                  )
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
          const SizedBox(height: spacing * 5),
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
