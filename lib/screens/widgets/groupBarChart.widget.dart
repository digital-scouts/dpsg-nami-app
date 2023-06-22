import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GroupBarChart extends StatefulWidget {
  final Map<String, GroupData> memberPerGroup;

  const GroupBarChart({required this.memberPerGroup, Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupBarChartState();
}

class GroupBarChartState extends State<GroupBarChart> {
  int findHighestValue(Map<String, GroupData> data) {
    int highestValue = 0;

    data.forEach((key, value) {
      if (value.leiter > highestValue) {
        highestValue = value.leiter;
      }

      if (value.mitglied > highestValue) {
        highestValue = value.mitglied;
      }
    });

    return highestValue;
  }

  List<BarChartGroupData> createData() {
    List<BarChartGroupData> sectionData = [];

    int index = 0;
    widget.memberPerGroup.forEach((key, value) {
      switch (key) {
        case "Wölfling":
          sectionData.add(createGroupData(index, value.leiter.toDouble(),
              value.mitglied.toDouble(), Colors.orange));
          break;
        case "Jungpfadfinder":
          sectionData.add(createGroupData(index, value.leiter.toDouble(),
              value.mitglied.toDouble(), Colors.blue));
          break;
        case "Pfadfinder":
          sectionData.add(createGroupData(index, value.leiter.toDouble(),
              value.mitglied.toDouble(), Colors.green));
          break;
        case "Rover":
          sectionData.add(createGroupData(index, value.leiter.toDouble(),
              value.mitglied.toDouble(), Colors.red));
          break;
        default:
          sectionData.add(createGroupData(index, value.leiter.toDouble(),
              value.mitglied.toDouble(), Colors.grey));
          break;
      }
      index++;
    });

    return sectionData;
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10);
    String text;
    switch (value.toInt()) {
      case 0:
        text = 'Wö';
        break;
      case 1:
        text = 'Jufi';
        break;
      case 2:
        text = 'Pfadi';
        break;
      case 3:
        text = 'Rover';
        break;

      default:
        text = '';
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
  }

  BarChartGroupData createGroupData(
      int x, double leaderCount, double memberCount, Color color) {
    const leaderColor = Colors.yellow;
    const betweenSpace = 0.2;

    return BarChartGroupData(
      x: x,
      groupVertically: true,
      showingTooltipIndicators: [0, 1],
      barRods: [
        BarChartRodData(
          fromY: 0,
          toY: leaderCount,
          color: leaderColor,
          width: 20,
          borderRadius: const BorderRadius.only(),
        ),
        BarChartRodData(
          fromY: leaderCount + betweenSpace,
          toY: leaderCount + betweenSpace + memberCount,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          barTouchData: BarTouchData(
            enabled: false,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: -23,
              getTooltipItem: (
                BarChartGroupData group,
                int groupIndex,
                BarChartRodData rod,
                int rodIndex,
              ) {
                return BarTooltipItem(
                  rod.toY > 0 ? (rod.toY - rod.fromY).round().toString() : '',
                  const TextStyle(
                    color: Colors.black,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: bottomTitles,
                reservedSize: 20,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: createData(),
          maxY: findHighestValue(widget.memberPerGroup).toDouble() + 5,
        ),
      ),
    );
  }
}

class GroupData {
  int leiter;
  int mitglied;

  GroupData(this.leiter, this.mitglied);
}
