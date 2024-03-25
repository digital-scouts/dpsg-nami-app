import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/widgets/alterBarChart.widget.dart';
import 'package:nami/screens/widgets/groupBarChart.widget.dart';
import 'package:nami/screens/widgets/stufenwechselInfo.widget.dart';
import 'package:nami/utilities/hive/mitglied.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({Key? key}) : super(key: key);

  @override
  StatistikScreenState createState() => StatistikScreenState();
}

class StatistikScreenState extends State<StatistikScreen> {
  Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();

  @override
  void initState() {
    super.initState();
    memberBox.listenable().addListener(() {
      mitglieder = memberBox.values.toList().cast<Mitglied>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Statistiken')),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double containerWidth = constraints.maxWidth * 0.45;
          final double containerHeight = constraints.maxHeight * 0.25;
          const double spacing = 10.0;

          return Column(
            children: [
              const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.35,
                    height: containerHeight,
                    child: Column(
                      children: [
                        const Text('Stufenverteilung',
                            style: TextStyle(fontSize: 17)),
                        Expanded(child: GroupBarChart(mitglieder: mitglieder)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth * 0.05,
                  ),
                  SizedBox(
                    width: constraints.maxWidth * 0.45,
                    height: containerHeight,
                    child: Column(
                      children: [
                        const Text('Altersverteilung',
                            style: TextStyle(fontSize: 17)),
                        Expanded(
                          child: AlterBarChartWidget(mitglieder: mitglieder),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacing * 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: containerWidth * 2 + spacing * 2,
                    height: containerHeight * 1.5,
                    child: const Column(
                      children: [
                        Text('Stufenwechselemphelung',
                            style: TextStyle(fontSize: 17)),
                        Expanded(child: StufenwechselInfo()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
