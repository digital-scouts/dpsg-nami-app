import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/stufe.dart';

class StufenwechselInfo extends StatefulWidget {
  const StufenwechselInfo({Key? key}) : super(key: key);

  @override
  State<StufenwechselInfo> createState() => _StufenwechselInfoState();
}

class _StufenwechselInfoState extends State<StufenwechselInfo> {
  // Die Liste der Namen
  List<DataRow> aktuelleTabellenZeilen = [];
  Map<int, List<DataRow>> stufenwechselData = {};

  // Die ausgewählte Stufe (0-3 entsprechend den Bildern)
  int ausgewaehlteStufe = 0;

  // Bilder für die Stufen
  List<String> stufenBilder = [
    'assets/images/woe.png',
    'assets/images/jufi.png',
    'assets/images/pfadi.png',
    'assets/images/rover.png',
  ];

  // Funktion zum Ändern der ausgewählten Stufe
  void _stufeAendern(int index) {
    setState(() {
      ausgewaehlteStufe = index;
      aktuelleTabellenZeilen = stufenwechselData[index] ?? [];
      // Hier könnten Sie die Liste namenListe basierend auf der ausgewählten Stufe aktualisieren.
    });
  }

  Map<int, List<DataRow>> loadStufenwechselData() {
    Map<int, List<DataRow>> stufenwechselData = {};
    List<Mitglied> mitglieder =
        Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();
    DateTime currentDate = DateTime.now();

    for (var mitglied in mitglieder) {
      if (mitglied.isMitgliedLeiter() || mitglied.stufe == 'keine Stufe') {
        continue;
      }

      Stufe? currentStufe = Stufe.getStufeByString(mitglied.stufe);
      int? minStufenWechselJahr = mitglied.getMinStufenWechselJahr();
      int? maxStufenWechselJahr = mitglied.getMaxStufenWechselJahr();
      bool isMinStufenWechselJahrInPast = minStufenWechselJahr != null &&
          minStufenWechselJahr <= currentDate.year;

      if (!isMinStufenWechselJahrInPast) {
        continue;
      }

      if (stufenwechselData[currentStufe.order - 1] == null) {
        stufenwechselData[currentStufe.order - 1] = [];
      }

      stufenwechselData[currentStufe.order - 1]!.add(DataRow(cells: [
        DataCell(Text(
            '${mitglied.vorname} ${mitglied.nachname.substring(0, 1)}. (${(currentDate.difference(mitglied.geburtsDatum).inDays / 365).toStringAsFixed(1)} Jahre alt)',
            style: const TextStyle(color: Colors.white))),
        DataCell(Text('$minStufenWechselJahr-$maxStufenWechselJahr',
            style: const TextStyle(color: Colors.white))),
        DataCell(Text('${currentDate.difference(mitglied.geburtsDatum).inDays}',
            style: const TextStyle(color: Colors.white))),
      ]));
    }

    // sortiere die Liste nach dem Alter unt entferne die Spalte mit dem Alter
    stufenwechselData.forEach((key, value) {
      value.sort((a, b) {
        return b.cells[2].child
            .toString()
            .compareTo(a.cells[2].child.toString());
      });
    });
    stufenwechselData.forEach((key, value) {
      for (var element in value) {
        element.cells.removeLast();
      }
    });
    return stufenwechselData;
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height;

    stufenwechselData = loadStufenwechselData();
    _stufeAendern(ausgewaehlteStufe);

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Bereich für die Stufenbilder
          SizedBox(
            width: 50.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(stufenBilder.length, (index) {
                return GestureDetector(
                  onTap: () {
                    _stufeAendern(index);
                  },
                  child: Container(
                    width: 50.0,
                    height: 50.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ausgewaehlteStufe == index
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    child: Center(
                      child: Image.asset(
                        stufenBilder[index],
                        width: 30.0,
                        height: 30.0,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 16.0, right: 5),
            width: 1.0,
            color: Colors.grey,
            height: availableHeight, // Höhe anpassen, abhängig von Ihrer Liste
          ),
          // Bereich für die Liste der Namen
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: aktuelleTabellenZeilen.isNotEmpty
                    ? DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Wechsel'))
                        ],
                        rows: aktuelleTabellenZeilen,
                      )
                    : const Text('Kein Wechsel zum angegebenen Datum'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
