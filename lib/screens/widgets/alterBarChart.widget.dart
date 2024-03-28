import 'dart:collection';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';

// ignore: must_be_immutable
class AlterBarChartWidget extends StatefulWidget {
  List<Mitglied> mitglieder;

  AlterBarChartWidget({super.key, required this.mitglieder});

  @override
  AlterBarChartWidgetState createState() => AlterBarChartWidgetState();
}

class AlterBarChartWidgetState extends State<AlterBarChartWidget> {
  (List<BarChartGroupData>, int minAge, int maxAge) createDateForAltersChart(
    List<Mitglied> mitglieder,
    double barsWidth,
    double barsSpace,
  ) {
    Map<int, Map<Stufe, int>> data = SplayTreeMap();
    int minAge = 99;
    int maxAge = 0;

    // Durchlaufe alle Mitglieder und sammle die Daten
    for (var mitglied in mitglieder) {
      int age = DateTime.now().year - mitglied.geburtsDatum.year;
      if (mitglied.geburtsDatum.month > DateTime.now().month) {
        age--;
      } else if (mitglied.geburtsDatum.month == DateTime.now().month &&
          mitglied.geburtsDatum.day > DateTime.now().day) {
        age--;
      }
      Stufe stufe = mitglied.currentStufe;

      if (stufe == Stufe.KEINE_STUFE || stufe == Stufe.LEITER) {
        continue;
      }
      minAge = min(minAge, age);
      maxAge = max(maxAge, age);

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

    for (int age = minAge; age <= maxAge; age++) {
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
            ),
          ],
        ),
      );
    });

    return (chartData, minAge, maxAge);
  }

  @override
  Widget build(BuildContext context) {
    const emptySideTile = AxisTitles(
      sideTitles: SideTitles(showTitles: false),
    );
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: LayoutBuilder(builder: (context, constraints) {
          final barsSpace = 4.0 * constraints.maxWidth / 400;
          final barsWidth = 8.0 * constraints.maxWidth / 400;
          final (data, minAge, maxAge) = createDateForAltersChart(
            widget.mitglieder,
            barsWidth,
            barsSpace,
          );
          return BarChart(
            BarChartData(
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text("Alter"),
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      String display;
                      if (value % 2 == 0 ||
                          value == minAge ||
                          value == maxAge) {
                        display = value.toInt().toString();
                      } else {
                        display = '';
                      }

                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          display,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  axisNameWidget: Text("Anzahl"),
                  sideTitles: SideTitles(
                    showTitles: true,
                  ),
                ),
                topTitles: emptySideTile,
                rightTitles: emptySideTile,
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (
                    BarChartGroupData group,
                    int groupIndex,
                    BarChartRodData rod,
                    int rodIndex,
                  ) {
                    final count = (rod.toY - rod.fromY).round();
                    return BarTooltipItem(
                      "$count",
                      const TextStyle(),
                    );
                  },
                ),
              ),
              borderData: FlBorderData(
                show: false,
              ),
              gridData: const FlGridData(
                drawHorizontalLine: true,
                drawVerticalLine: false,
              ),
              groupsSpace: barsSpace,
              barGroups: data,
            ),
          );
        }),
      ),
    );
  }
}
