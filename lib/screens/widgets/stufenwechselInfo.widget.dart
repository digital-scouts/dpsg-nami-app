import 'package:flutter/material.dart';

class StufenwechselInfo extends StatefulWidget {
  const StufenwechselInfo({Key? key}) : super(key: key);

  @override
  State<StufenwechselInfo> createState() => _StufenwechselInfoState();
}

class _StufenwechselInfoState extends State<StufenwechselInfo> {
  // Die Liste der Namen
  List<DataRow> tabellenZeilen = const [
    DataRow(cells: [
      DataCell(Text('Name 1', style: TextStyle(color: Colors.black))),
      DataCell(Text('Alter 1', style: TextStyle(color: Colors.black)))
    ]),
    DataRow(cells: [
      DataCell(Text('Name 2', style: TextStyle(color: Colors.black))),
      DataCell(Text('Alter 2', style: TextStyle(color: Colors.black)))
    ]),
    DataRow(cells: [
      DataCell(Text('Name 3', style: TextStyle(color: Colors.black))),
      DataCell(Text('Alter 3', style: TextStyle(color: Colors.black)))
    ]),
    DataRow(cells: [
      DataCell(Text('Name 4', style: TextStyle(color: Colors.black))),
      DataCell(Text('Alter 4', style: TextStyle(color: Colors.black)))
    ]),
  ];

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
      // Hier könnten Sie die Liste namenListe basierend auf der ausgewählten Stufe aktualisieren.
    });
  }

  // Funktion, um ein Bild in Graustufen darzustellen
  Widget _bildInGraustufen(String bildPfad) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.grey, // Graustufen
        BlendMode.saturation,
      ),
      child: Image.asset(
        bildPfad,
        width: 50.0,
        height: 50.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height;

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
                  child: ausgewaehlteStufe == index
                      ? Image.asset(
                          stufenBilder[index],
                          width: 50.0,
                          height: 50.0,
                        )
                      : _bildInGraustufen(stufenBilder[index]),
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
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Alter')),
              ],
              rows: tabellenZeilen,
            ),
          ),
        ],
      ),
    );
  }
}
