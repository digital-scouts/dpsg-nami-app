import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nami/utilities/stufe.dart';

class MitgliedStufenPieChart extends StatefulWidget {
  final Map<String, int> memberPerGroup;
  final bool showLeiterGrafik;

  const MitgliedStufenPieChart(
      {required this.memberPerGroup,
      required this.showLeiterGrafik,
      super.key});

  @override
  State<StatefulWidget> createState() => MitgliedStufenPieChartState();
}

class MitgliedStufenPieChartState extends State<MitgliedStufenPieChart> {
  @override
  Widget build(BuildContext context) {
    Map<String, int> memberPerGroup =
        summarizeData(widget.memberPerGroup, widget.showLeiterGrafik);

    return SizedBox(
      height: 120, // Erhöhte Höhe, um Platz für den Schatten zu schaffen
      child: Padding(
        padding: const EdgeInsets.all(10.0), // Padding hinzufügen
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                spreadRadius: 2,
                offset: Offset(0, 4), // Verschiebung des Schattens nach unten
              ),
            ],
          ),
          child: PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 0,
              sections: createData(memberPerGroup, widget.showLeiterGrafik),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> summarizeData(
      Map<String, int> memberPerGroup, bool showLeiterGrafik) {
    int leiterSum = 0;
    int mitgliedSum = 0;

    memberPerGroup.forEach((key, value) {
      if (key.contains('LeiterIn')) {
        leiterSum += value;
      } else if (key.contains('Mitglied')) {
        mitgliedSum += value;
      }
    });
    if (showLeiterGrafik) {
      memberPerGroup.removeWhere((key, value) => key.contains('Mitglied'));
      memberPerGroup.addAll({'Mitglied': mitgliedSum});
    } else {
      memberPerGroup.removeWhere((key, value) => key.contains('LeiterIn'));
      memberPerGroup.addAll({'LeiterIn': leiterSum});
    }

    return memberPerGroup;
  }

  List<PieChartSectionData> createData(
      Map<String, int> memberPerGroup, bool showLeiterGrafik) {
    List<PieChartSectionData> sectionData = [];
    num index = 0;

    memberPerGroup.forEach((key, value) {
      if (showLeiterGrafik) {
        if (key.contains('Mitglied')) {
          sectionData
              .add(createPieElement(key, value, null, index, showLeiterGrafik));
        } else if (key.contains(Stufe.BIBER.display)) {
          sectionData.add(createPieElement(
              "LeiterIn", value, Stufe.BIBER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.WOELFLING.display)) {
          sectionData.add(createPieElement(
              "LeiterIn", value, Stufe.WOELFLING, index, showLeiterGrafik));
        } else if (key.contains(Stufe.JUNGPADFINDER.display)) {
          sectionData.add(createPieElement(
              "LeiterIn", value, Stufe.JUNGPADFINDER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.PFADFINDER.display)) {
          sectionData.add(createPieElement(
              "LeiterIn", value, Stufe.PFADFINDER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.ROVER.display)) {
          sectionData.add(createPieElement(
              "LeiterIn", value, Stufe.ROVER, index, showLeiterGrafik));
        }
      } else {
        if (key.contains('LeiterIn')) {
          sectionData.add(createPieElement(
              "LeiterIn", value, Stufe.LEITER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.BIBER.display)) {
          sectionData.add(createPieElement(
              key, value, Stufe.BIBER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.WOELFLING.display)) {
          sectionData.add(createPieElement(
              key, value, Stufe.WOELFLING, index, showLeiterGrafik));
        } else if (key.contains(Stufe.JUNGPADFINDER.display)) {
          sectionData.add(createPieElement(
              key, value, Stufe.JUNGPADFINDER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.PFADFINDER.display)) {
          sectionData.add(createPieElement(
              key, value, Stufe.PFADFINDER, index, showLeiterGrafik));
        } else if (key.contains(Stufe.ROVER.display)) {
          sectionData.add(createPieElement(
              key, value, Stufe.ROVER, index, showLeiterGrafik));
        }
      }
      index++;
    });

    return sectionData;
  }

  PieChartSectionData createPieElement(
      String name, num value, Stufe? stufe, num index, bool leiterElement) {
    const radius = 45.0;

    return PieChartSectionData(
      color: stufe?.farbe ?? Stufe.KEINE_STUFE.farbe,
      value: value.toDouble(),
      showTitle: false,
      radius: radius,
      badgeWidget: stufe == null
          ? null
          : leiterElement
              ? _buildBadgeLeader(stufe)
              : _buildBadgeMember(stufe),
      badgePositionPercentageOffset: widget.memberPerGroup.length == 1 ? 0 : .6,
    );
  }

  Widget? _buildBadgeLeader(Stufe stufe) {
    return _Badge(
      'assets/images/lilie_schwarz.png',
      size: 25.0,
      borderColor: Colors.black,
      imageColor: stufe != Stufe.BIBER ? stufe.farbe : null,
    );
  }

  Widget? _buildBadgeMember(Stufe stufe) {
    return _Badge(
      stufe.imagePath!,
      size: 25.0,
      borderColor: Colors.black,
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
            color: Colors.black.withValues(alpha: 0.5),
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
        cacheWidth: 54,
      )),
    );
  }
}
