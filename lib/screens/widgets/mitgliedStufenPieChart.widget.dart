import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MitgliedStufenPieChart extends StatefulWidget {
  final Map<String, int> memberPerGroup;

  const MitgliedStufenPieChart({required this.memberPerGroup, Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => MitgliedStufenPieChartState();
}

class MitgliedStufenPieChartState extends State<MitgliedStufenPieChart> {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.3,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 0,
          sections: createData(),
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
          sectionData.add(createPieElement(
              key, value, Colors.orange, 'assets/images/woe.png', index));
          break;
        case "Jungpfadfinder":
          sectionData.add(createPieElement(
              key, value, Colors.blue, 'assets/images/jufi.png', index));
          break;
        case "Pfadfinder":
          sectionData.add(createPieElement(
              key, value, Colors.green, 'assets/images/pfadi.png', index));
          break;
        case "Rover":
          sectionData.add(createPieElement(
              key, value, Colors.red, 'assets/images/rover.png', index));
          break;
        case "LeiterIn":
          sectionData.add(createPieElement(key, value, Colors.yellow,
              'assets/images/lilie_schwarz.png', index));
          break;
        default:
          sectionData.add(createPieElement(key, value, Colors.grey, '', index));
      }
      index++;
    });

    return sectionData;
  }

  PieChartSectionData createPieElement(
      String name, num value, Color color, String badge, num index) {
    const radius = 45.0;
    const widgetSize = 25.0;

    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      showTitle: false,
      radius: radius,
      badgeWidget: badge.isNotEmpty
          ? _Badge(
              badge,
              size: widgetSize,
              borderColor: Colors.black,
            )
          : null,
      badgePositionPercentageOffset: widget.memberPerGroup.length == 1 ? 0 : .6,
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
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            offset: const Offset(3, 3),
            blurRadius: 10,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .1),
      child: Center(
        child: Image.asset(
          svgAsset,
        ),
      ),
    );
  }
}
