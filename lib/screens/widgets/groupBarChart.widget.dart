import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/theme.dart';

class GroupBarChart extends StatefulWidget {
  final List<Mitglied> mitglieder;

  const GroupBarChart({required this.mitglieder, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupBarChartState();
}

class GroupBarChartState extends State<GroupBarChart> {
  Map<String, GroupData> getMemberPerGroup() {
    return widget.mitglieder.fold<Map<String, GroupData>>({}, (map, member) {
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
  }

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
    getMemberPerGroup().forEach((key, value) {
      switch (key) {
        case "Wölfling":
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.woelfingFarbe,
            ),
          );
          break;
        case "Jungpfadfinder":
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.jungpfadfinderFarbe,
            ),
          );
          break;
        case "Pfadfinder":
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.pfadfinderFarbe,
            ),
          );
          break;
        case "Rover":
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.roverFarbe,
            ),
          );
          break;
        default:
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.leiterFarbe,
            ),
          );
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
    final data = createData();
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
                  TextStyle(
                    color: rod.toY >=
                            1 // Color text on bar different that on surface
                        ? Colors.black
                        : Theme.of(context).colorScheme.onBackground,
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
          barGroups: data,
          maxY: findHighestValue(getMemberPerGroup()).toDouble() + 5,
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
