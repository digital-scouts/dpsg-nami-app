import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/stufe.dart';

class StufenwechselInfo extends StatefulWidget {
  const StufenwechselInfo({Key? key}) : super(key: key);

  @override
  State<StufenwechselInfo> createState() => _StufenwechselInfoState();
}

class _StufenwechselInfoState extends State<StufenwechselInfo> {
  // Die Liste der Namen
  List<DataRow> aktuelleTabellenZeilen = [];
  Map<Stufe, List<DataRow>> stufenwechselData = {};

  // Die ausgewählte Stufe (0-3 entsprechend den Bildern)
  Stufe ausgewaehlteStufe = Stufe.WOELFLING;

  // Funktion zum Ändern der ausgewählten Stufe
  void _stufeAendern(Stufe stufe) {
    setState(() {
      ausgewaehlteStufe = stufe;
      aktuelleTabellenZeilen = stufenwechselData[stufe] ?? [];
      // Hier könnten Sie die Liste namenListe basierend auf der ausgewählten Stufe aktualisieren.
    });
  }

  Map<Stufe, List<DataRow>> loadStufenwechselData() {
    Map<Stufe, List<DataRow>> stufenwechselData = {};
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
          minStufenWechselJahr <= getNextStufenwechselDatum().year;

      if (!isMinStufenWechselJahrInPast) {
        continue;
      }
      if (stufenwechselData[currentStufe] == null) {
        stufenwechselData[currentStufe] = [];
      }
      if (getFavouriteList().contains(mitglied.mitgliedsNummer) &&
          stufenwechselData[Stufe.FAVOURITE] == null) {
        stufenwechselData[Stufe.FAVOURITE] = [];
      }
      DataRow data = DataRow(
        onSelectChanged: (_) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MitgliedDetail(mitglied: mitglied),
            ),
          );
        },
        cells: [
          DataCell(
            Text(
                '${mitglied.vorname} ${mitglied.nachname.substring(0, 1)}. (${(currentDate.difference(mitglied.geburtsDatum).inDays / 365).toStringAsFixed(1)} Jahre alt)'),
          ),
          DataCell(
            Text('$minStufenWechselJahr-$maxStufenWechselJahr'),
          ),
          DataCell(
            Text('${currentDate.difference(mitglied.geburtsDatum).inDays}'),
          ),
        ],
      );
      stufenwechselData[currentStufe]!.add(data);
      if (getFavouriteList().contains(mitglied.mitgliedsNummer)) {
        stufenwechselData[Stufe.FAVOURITE]!.add(data);
      }
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
        if (element.cells.length == 3) element.cells.removeLast();
      }
    });
    return stufenwechselData;
  }

  @override
  Widget build(BuildContext context) {
    stufenwechselData = loadStufenwechselData();
    _stufeAendern(ausgewaehlteStufe);

    return Column(
      children: [
        // Bereich für die Stufenbilder
        Wrap(
          spacing: 5,
          children: [
            for (final stufe in [
              Stufe.BIBER,
              Stufe.WOELFLING,
              Stufe.JUNGPADFINDER,
              Stufe.PFADFINDER,
              Stufe.ROVER,
              Stufe.FAVOURITE
            ])
              if ((stufe != Stufe.BIBER ||
                      stufenwechselData[stufe]?.isNotEmpty == true) &&
                  (stufe != Stufe.FAVOURITE || getFavouriteList().isNotEmpty))
                ChoiceChip(
                  selected: stufe == ausgewaehlteStufe,
                  onSelected: (selected) {
                    if (selected) _stufeAendern(stufe);
                  },
                  label: Text(stufe.shortDisplay),
                  showCheckmark: false,
                  avatar: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Image.asset(stufe.imagePath!,
                        color: stufe == Stufe.FAVOURITE ? stufe.farbe : null),
                  ),
                ),
          ],
        ),
        // // Bereich für die Liste der Namen
        if (aktuelleTabellenZeilen.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Wechsel'))
                ],
                rows: aktuelleTabellenZeilen,
                showCheckboxColumn: false,
              ),
            ),
          )
        else ...[
          const SizedBox(height: 40),
          const ListTile(
            leading: Icon(Icons.block),
            title: Text(
              'Kein Wechsel zum angegebenen Datum',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
