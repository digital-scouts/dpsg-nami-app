import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nami/utilities/stufe.dart';

class MitgliedStufenPieChart extends StatefulWidget {
  final Map<String, int> memberPerGroup;
  final bool showLeiterGrafik;

  const MitgliedStufenPieChart(
      {required this.memberPerGroup, required this.showLeiterGrafik, Key? key})
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
      if (widget.showLeiterGrafik) {
        if (key.contains('Mitglied')) {
          sectionData.add(createPieElement(key, value, null, index));
        } else if (key.contains("Biber")) {
          sectionData
              .add(createPieElement("LeiterIn", value, Stufe.BIBER, index));
        } else if (key.contains("Wölfling")) {
          sectionData
              .add(createPieElement("LeiterIn", value, Stufe.WOELFLING, index));
        } else if (key.contains("Jungpfadfinder")) {
          sectionData.add(
              createPieElement("LeiterIn", value, Stufe.JUNGPADFINDER, index));
        } else if (key.contains("Pfadfinder")) {
          sectionData.add(
              createPieElement("LeiterIn", value, Stufe.PFADFINDER, index));
        } else if (key.contains("Rover")) {
          sectionData
              .add(createPieElement("LeiterIn", value, Stufe.ROVER, index));
        }
      } else {
        if (key.contains('LeiterIn')) {
          sectionData.add(createPieElement("LeiterIn", value, null, index));
        } else if (key.contains("Biber")) {
          sectionData.add(createPieElement(key, value, Stufe.BIBER, index));
        } else if (key.contains("Wölfling")) {
          sectionData.add(createPieElement(key, value, Stufe.WOELFLING, index));
        } else if (key.contains("Jungpfadfinder")) {
          sectionData
              .add(createPieElement(key, value, Stufe.JUNGPADFINDER, index));
        } else if (key.contains("Pfadfinder")) {
          sectionData
              .add(createPieElement(key, value, Stufe.PFADFINDER, index));
        } else if (key.contains("Rover")) {
          sectionData.add(createPieElement(key, value, Stufe.ROVER, index));
        }
      }
      index++;
    });

    return sectionData;
  }

  PieChartSectionData createPieElement(
      String name, num value, Stufe? stufe, num index) {
    const radius = 45.0;

    return PieChartSectionData(
      color: stufe?.farbe ?? Stufe.KEINE_STUFE.farbe,
      value: value.toDouble(),
      showTitle: false,
      radius: radius,
      badgeWidget:
          stufe == null ? null : _buildBadge(stufe, name.contains('LeiterIn')),
      badgePositionPercentageOffset: widget.memberPerGroup.length == 1 ? 0 : .6,
    );
  }

  Widget? _buildBadge(Stufe stufe, bool leiter) {
    return _Badge(
      leiter ? 'assets/images/lilie_schwarz.png' : stufe.imagePath!,
      size: 25.0,
      borderColor: Colors.black,
      imageColor: leiter && stufe != Stufe.BIBER ? stufe.farbe : null,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
    this.svgAsset, {
    required this.size,
    required this.borderColor,
    this.imageColor,
  });
  final String svgAsset;
  final double size;
  final Color borderColor;
  final Color? imageColor;

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
        width: 80.0,
        height: 80.0,
        color: imageColor,
        colorBlendMode: BlendMode.srcIn,
      )),
    );
  }
}
