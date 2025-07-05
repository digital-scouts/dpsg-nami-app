import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/theme.dart';

class GroupBarChart extends StatefulWidget {
  final List<Mitglied> mitglieder;

  const GroupBarChart({required this.mitglieder, super.key});

  @override
  State<StatefulWidget> createState() => GroupBarChartState();
}

class GroupBarChartState extends State<GroupBarChart> {
  Map<Stufe, GroupData> getMemberPerGroup() {
    return widget.mitglieder.fold<Map<Stufe, GroupData>>(
      {
        for (var stufe in [
          Stufe.BIBER,
          Stufe.WOELFLING,
          Stufe.JUNGPADFINDER,
          Stufe.PFADFINDER,
          Stufe.ROVER,
          Stufe.KEINE_STUFE,
        ])
          stufe: GroupData(0, 0),
      },
      (map, member) {
        final stufe = member.currentStufeWithoutLeiter;

        if (member.isMitgliedLeiter()) {
          map[stufe]!.leiter += 1;
        } else {
          map[stufe]!.mitglied += 1;
        }

        return map;
      },
    );
  }

  int findHighestValue(Map<Stufe, GroupData> data) {
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
        case Stufe.BIBER:
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.biberFarbe,
            ),
          );
          break;
        case Stufe.WOELFLING:
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.woelfingFarbe,
            ),
          );
          break;
        case Stufe.JUNGPADFINDER:
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.jungpfadfinderFarbe,
            ),
          );
          break;
        case Stufe.PFADFINDER:
          sectionData.add(
            createGroupData(
              index,
              value.leiter.toDouble(),
              value.mitglied.toDouble(),
              DPSGColors.pfadfinderFarbe,
            ),
          );
          break;
        case Stufe.ROVER:
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
          break;
      }
      index++;
    });

    return sectionData;
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    String text;
    switch (value.toInt()) {
      case 0:
        text = 'Biber';
        break;
      case 1:
        text = 'Wölflinge';
        break;
      case 2:
        text = 'Jufis';
        break;
      case 3:
        text = 'Pfadis';
        break;
      case 4:
        text = 'Rover';
        break;
      default:
        text = 'Sonstige';
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  BarChartGroupData createGroupData(
    int x,
    double leaderCount,
    double memberCount,
    Color color,
  ) {
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
          width: 30,
          borderRadius: const BorderRadius.only(),
        ),
        BarChartRodData(
          fromY: leaderCount + betweenSpace,
          toY: leaderCount + betweenSpace + memberCount,
          color: color,
          width: 30,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final summAktiveMitglieder = widget.mitglieder
        .where((mitglied) => mitglied.status == 'Aktiv')
        .toList();
    final leitende = widget.mitglieder
        .where((mitglied) => mitglied.currentStufe == Stufe.LEITER)
        .toList();
    final aktiveMitglieder = widget.mitglieder
        .where(
          (mitglied) =>
              mitglied.currentStufe != Stufe.LEITER &&
              mitglied.currentStufe != Stufe.KEINE_STUFE,
        )
        .toList();
    final data = createData();
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 6 / 4,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceBetween,
              barTouchData: BarTouchData(
                enabled: false,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: -23,
                  getTooltipItem:
                      (
                        BarChartGroupData group,
                        int groupIndex,
                        BarChartRodData rod,
                        int rodIndex,
                      ) {
                        final count = (rod.toY - rod.fromY).round();
                        if (count == 0) {
                          return null;
                        }
                        return BarTooltipItem(
                          "$count",
                          TextStyle(
                            color:
                                rod.toY >=
                                    1 // Color text on bar different that on surface
                                ? Colors.black
                                : Theme.of(context).colorScheme.onSurface,
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
                    reservedSize: 25,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: data,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Gesamtanzahl aktive Mitglieder: ${summAktiveMitglieder.length}'),
        Text(
          '(Gruppenkinder: ${aktiveMitglieder.length} | Leitende: ${leitende.length} | Sonstige: ${summAktiveMitglieder.length - aktiveMitglieder.length - leitende.length})',
        ),
        Text(
          'Inaktive Mitglieder: ${widget.mitglieder.length - summAktiveMitglieder.length}',
        ),
      ],
    );
  }
}

class GroupData {
  int leiter;
  int mitglied;

  GroupData(this.leiter, this.mitglied);
}
