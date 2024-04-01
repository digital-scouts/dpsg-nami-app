import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nami/utilities/stufe.dart';

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
      aspectRatio: 1.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                spreadRadius: 0.1,
                blurRadius: 5,
              ),
            ],
          ),
          child: PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 0,
              sections: createData(),
            ),
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
        case "LeiterIn":
          sectionData.add(createPieElement(key, value, Stufe.LEITER, index));
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
    const radius = 45.0;
    const widgetSize = 25.0;

    return PieChartSectionData(
      color: stufe?.farbe ?? Stufe.KEINE_STUFE.farbe,
      value: value.toDouble(),
      showTitle: false,
      radius: radius,
      badgeWidget: stufe != null
          ? _Badge(
              stufe.imagePath!,
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
