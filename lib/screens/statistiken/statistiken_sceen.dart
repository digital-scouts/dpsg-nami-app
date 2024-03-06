import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/widgets/groupBarChart.widget.dart';
import 'package:nami/screens/widgets/stufenwechselInfo.widget.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';
import 'dart:collection';

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

  Widget _buildMemberCountStatistik() {
    Map<String, GroupData> memberPerGroup =
        mitglieder.fold<Map<String, GroupData>>({}, (map, member) {
      String stufe = member.stufe;
      String taetigkeit = member.isMitgliedLeiter() ? 'leiter' : 'mitglied';

      if (stufe == 'keine Stufe') {
        taetigkeit = stufe;
      }

      if (!map.containsKey(stufe)) {
        map["Wölfling"] = GroupData(0, 0);
        map["Jungpfadfinder"] = GroupData(0, 0);
        map["Pfadfinder"] = GroupData(0, 0);
        map["Rover"] = GroupData(0, 0);
        map["keine Stufe"] = GroupData(0, 0);
      }

      if (taetigkeit == 'leiter') {
        map[stufe]!.leiter += 1;
      } else {
        map[stufe]!.mitglied += 1;
      }

      return map;
    });
    // memberPerGroup.remove('keine Stufe');

    return GroupBarChart(memberPerGroup: memberPerGroup);
  }

  List<BarChartGroupData> createDateForAltersChart(
      double barsWidth, double barsSpace) {
    Map<int, Map<Stufe, int>> data = SplayTreeMap();

    // Durchlaufe alle Mitglieder und sammle die Daten
    for (var mitglied in mitglieder) {
      int age = DateTime.now().year - mitglied.geburtsDatum.year;
      if (mitglied.geburtsDatum.month > DateTime.now().month) {
        age--;
      } else if (mitglied.geburtsDatum.month == DateTime.now().month &&
          mitglied.geburtsDatum.day > DateTime.now().day) {
        age--;
      }
      Stufe stufe = Stufe.getStufeByString(mitglied.stufe);

      if (mitglied.stufe == 'keine Stufe' || mitglied.isMitgliedLeiter()) {
        continue;
      }

      if (!data.containsKey(age)) {
        data[age] = {};
      }

      if (!data[age]!.containsKey(stufe)) {
        data[age]![stufe] = 0;
      }

      if (data[age]![stufe] != null) {
        data[age]![stufe] = (data[age]![stufe] ?? 0) + 1;
      }
    }

    for (int age = 6; age <= 21; age++) {
      if (!data.containsKey(age)) {
        data[age] = {};
      }
    }

    // Erstelle die BarChartGroupData aus den gesammelten Daten
    List<BarChartGroupData> chartData = [];
    data.forEach((age, stufenData) {
      List<BarChartRodStackItem> stackItems = [];
      double total = 0;
      stufenData.forEach((stufe, count) {
        stackItems.add(BarChartRodStackItem(total, total + count, stufe.farbe));
        total += count;
      });

      chartData.add(
        BarChartGroupData(
          x: age,
          barsSpace: barsSpace,
          barRods: [
            BarChartRodData(
              toY: total,
              rodStackItems: stackItems,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
    });

    return chartData;
  }

  Widget _buildAlterspyramide() {
    return AspectRatio(
      aspectRatio: 1.66,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: LayoutBuilder(builder: (context, constraints) {
          final barsSpace = 4.0 * constraints.maxWidth / 400;
          final barsWidth = 8.0 * constraints.maxWidth / 400;
          return BarChart(
            BarChartData(
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 3.0,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                          (value == 6)
                              ? 'Alter: 6       '
                              : (value % 3 == 0)
                                  ? value.toInt().toString()
                                  : '',
                          style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: false,
              ),
              gridData: const FlGridData(
                show: false,
              ),
              groupsSpace: barsSpace,
              barGroups: createDateForAltersChart(barsWidth, barsSpace),
            ),
          );
        }),
      ),
    );
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
                        Expanded(child: _buildMemberCountStatistik()),
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
                          child: _buildAlterspyramide(),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                      width: containerWidth * 2 + spacing * 2,
                      height: containerHeight * 1.5,
                      child: const StufenwechselInfo()),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    width: containerWidth * 2 + spacing * 2,
                    height: containerHeight,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Center(
                      child: Text(
                        'Demografie',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 20.0,
                        ),
                      ),
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
