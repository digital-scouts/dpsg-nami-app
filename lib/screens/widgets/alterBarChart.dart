import 'dart:collection';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';

// ignore: must_be_immutable
class AlterBarChartWidget extends StatefulWidget {
  List<Mitglied> mitglieder;
  int minAge;
  int maxAge;

  AlterBarChartWidget(
      {super.key, required this.mitglieder, this.minAge = 6, this.maxAge = 21});

  @override
  _AlterBarChartWidgetState createState() => _AlterBarChartWidgetState();
}

class _AlterBarChartWidgetState extends State<AlterBarChartWidget> {
  List<BarChartGroupData> createDateForAltersChart(
      List<Mitglied> mitglieder, double barsWidth, double barsSpace) {
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

    for (int age = widget.minAge; age <= widget.maxAge; age++) {
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

  @override
  Widget build(BuildContext context) {
    const emptySideTile = AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    );
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
                          (value == widget.minAge)
                              ? 'Alter: ${widget.minAge}       '
                              : (value % 2 == 0)
                                  ? value.toInt().toString()
                                  : '',
                          style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
                leftTitles: emptySideTile,
                topTitles: emptySideTile,
                rightTitles: emptySideTile,
              ),
              borderData: FlBorderData(
                show: false,
              ),
              gridData: const FlGridData(
                show: false,
              ),
              groupsSpace: barsSpace,
              barGroups: createDateForAltersChart(
                  widget.mitglieder, barsWidth, barsSpace),
            ),
          );
        }),
      ),
    );
  }
}
