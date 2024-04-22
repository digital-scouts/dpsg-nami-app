import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nami/utilities/stufe.dart';

class GroupPieChart extends StatefulWidget {
  final Map<String, int> memberPerGroup;

  const GroupPieChart({required this.memberPerGroup, Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => GroupPieChartState();
}

class GroupPieChartState extends State<GroupPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: AspectRatio(
        aspectRatio: 1,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
            borderData: FlBorderData(
              show: false,
            ),
            sectionsSpace: 0,
            centerSpaceRadius: 0,
            sections: createData(),
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> createData() {
    List<PieChartSectionData> sectionData = [];
    num index = 0;
    widget.memberPerGroup.forEach((key, value) {
      switch (key) {
        case "Wölfling":
          sectionData.add(createPieElement(key, value, Stufe.WOELFLING, index));
          break;
        case "Jungpfadfinder":
          sectionData
              .add(createPieElement(key, value, Stufe.JUNGPADFINDER, index));
          break;
        case "Pfadfinder":
          sectionData
              .add(createPieElement(key, value, Stufe.PFADFINDER, index));
          break;
        case "Rover":
          sectionData.add(createPieElement(key, value, Stufe.ROVER, index));
          break;
        default:
          sectionData.add(createPieElement(key, value, null, index));
      }
      index++;
    });

    return sectionData;
  }

  PieChartSectionData createPieElement(
      String name, num value, Stufe? stufe, num index) {
    final isTouched = index == touchedIndex;
    final fontSize = isTouched ? 20.0 : 16.0;
    final radius = isTouched ? 110.0 : 100.0;
    final widgetSize = isTouched ? 55.0 : 40.0;
    const shadows = [Shadow(color: Colors.black, blurRadius: 2)];

    return PieChartSectionData(
      color: stufe?.farbe ?? Stufe.KEINE_STUFE.farbe,
      value: value.toDouble(),
      title: value.toString(),
      radius: radius,
      titleStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: const Color(0xffffffff),
        shadows: shadows,
      ),
      badgeWidget: stufe != null
          ? _Badge(
              stufe.imagePath!,
              size: widgetSize,
              borderColor: Colors.black,
            )
          : null,
      badgePositionPercentageOffset: .98,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
    this.svgAsset, {
    required this.size,
    required this.borderColor,
  });
  final String svgAsset;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            offset: const Offset(3, 3),
            blurRadius: 3,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Image.asset(
          svgAsset,
        ),
      ),
    );
  }
}
