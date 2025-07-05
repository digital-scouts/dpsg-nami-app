import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/types.dart';
import 'package:wiredash/wiredash.dart';

class StufenwechselInfo extends StatefulWidget {
  const StufenwechselInfo({super.key});

  @override
  State<StufenwechselInfo> createState() => _StufenwechselInfoState();
}

class _StufenwechselInfoState extends State<StufenwechselInfo> {
  // Die Liste der Namen
  List<DataRow> aktuelleTabellenZeilen = [];
  Map<Stufe, List<DataRow>> stufenwechselData = {};
  DateTime nextStufenwechselDatum = getNextStufenwechselDatum();

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
    mitglieder.sort((a, b) {
      return a.geburtsDatum.compareTo(b.geburtsDatum);
    });

    for (var mitglied in mitglieder) {
      Stufe currentStufe = mitglied.currentStufe;
      if (currentStufe == Stufe.LEITER || currentStufe == Stufe.KEINE_STUFE) {
        continue;
      }

      double alterNextStufenwechsel = getAlterAm(
          referenceDate: nextStufenwechselDatum, date: mitglied.geburtsDatum);
      DateTime? maxStufenWechselDatum = mitglied.getMaxStufenWechselDatum();
      DateTime? minStufenWechselDatum = mitglied.getMinStufenWechselDatum() ??
          maxStufenWechselDatum!.subtract(const Duration(days: 365 * 2));
      bool isMinStufenWechselJahrInPast =
          minStufenWechselDatum.isBefore(getNextStufenwechselDatum());

      if (!isMinStufenWechselJahrInPast) {
        continue;
      }
      if (stufenwechselData[currentStufe] == null) {
        stufenwechselData[currentStufe] = [];
      }
      DataRow data = DataRow(
        onSelectChanged: (_) {
          Wiredash.trackEvent('Show Member Details',
              data: {'type': 'stufenwechselInfoWidget'});
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MitgliedDetail(mitglied: mitglied),
            ),
          );
        },
        cells: [
          DataCell(
            Text('${mitglied.vorname} ${mitglied.nachname.substring(0, 1)}.'),
          ),
          DataCell(
            Text(_formatAlterJahrMonat(alterNextStufenwechsel)),
          ),
          DataCell(
            Text(
              currentStufe == Stufe.ROVER
                  ? maxStufenWechselDatum!.year.toString()
                  : '${minStufenWechselDatum.year}-${maxStufenWechselDatum!.year.toString().substring(2)}',
            ),
          ),
        ],
      );
      stufenwechselData[currentStufe]!.add(data);
    }

    // sortiere die Liste nach dem Alter und entferne die Spalte mit dem Alter
    stufenwechselData.forEach((key, value) {
      value.sort((a, b) {
        final String textA = (a.cells[1].child as Text).data ?? '';
        final String textB = (b.cells[1].child as Text).data ?? '';
        final double valueA = double.tryParse(textA) ?? -1;
        final double valueB = double.tryParse(textB) ?? -1;
        return valueB.compareTo(valueA);
      });
    });

    return stufenwechselData;
  }

  String _formatAlterJahrMonat(double alter) {
    int jahre = alter.floor();
    int monate = ((alter - jahre) * 12).round();
    return "${jahre}J ${monate}M";
  }

  @override
  Widget build(BuildContext context) {
    stufenwechselData = loadStufenwechselData();
    _stufeAendern(ausgewaehlteStufe);

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 5,
          children: [
            for (final stufe in [
              Stufe.BIBER,
              Stufe.WOELFLING,
              Stufe.JUNGPADFINDER,
              Stufe.PFADFINDER,
              Stufe.ROVER
            ])
              if ((stufe != Stufe.BIBER ||
                  stufenwechselData[stufe]?.isNotEmpty == true))
                ChoiceChip(
                  selected: stufe == ausgewaehlteStufe,
                  onSelected: (selected) {
                    if (selected) _stufeAendern(stufe);
                  },
                  label: Text(stufe.shortDisplay),
                  showCheckmark: false,
                  avatar: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Image.asset(
                      stufe.imagePath!,
                      cacheHeight: 50,
                    ),
                  ),
                ),
          ],
        ),
        // Bereich für die Liste der Namen
        if (aktuelleTabellenZeilen.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Column(children: [
                Text(
                    'Wechsel am ${nextStufenwechselDatum.prettyPrint()} (${getStufeMinAge(Stufe.getStufeByOrder(ausgewaehlteStufe.index + 1)!)}-${getStufeMaxAge(ausgewaehlteStufe)} Jahre)'),
                DataTable(
                  columns: [
                    const DataColumn(
                      label: Text('Name'),
                    ),
                    const DataColumn(label: Text('Alter')),
                    DataColumn(
                        label: Text(ausgewaehlteStufe == Stufe.ROVER
                            ? 'Ende'
                            : 'Wechsel'))
                  ],
                  rows: aktuelleTabellenZeilen,
                  showCheckboxColumn: false,
                )
              ]),
            ),
          )
        else ...[
          const SizedBox(height: 40),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(
              'Kein Wechsel zum ${nextStufenwechselDatum.prettyPrint()}',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
