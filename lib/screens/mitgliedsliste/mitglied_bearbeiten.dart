import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:intl/intl.dart';

// ignore: must_be_immutable
class MitgliedBearbeiten extends StatefulWidget {
  Mitglied? mitglied;

  MitgliedBearbeiten({required this.mitglied, Key? key}) : super(key: key);

  @override
  MitgliedBearbeitenState createState() => MitgliedBearbeitenState();
}

class MitgliedBearbeitenState extends State<MitgliedBearbeiten> {
  bool _unsavedChanges = true;

  Future<bool> _onWillPop() async {
    if (!_unsavedChanges) {
      return true;
    }

    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warnung!'),
        content: const Text(
            'Sie haben ungespeicherte Änderungen. Wollen Sie wirklich verlassen?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nein, weiter bearbeiten.'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Ja, Änderungen verwerfen.',
              selectionColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: widget.mitglied != null
              ? Text("${widget.mitglied!.vorname} ${widget.mitglied!.nachname}")
              : Text("Neues Mitglied"),
          actions: <Widget>[
            IconButton(
              color: _unsavedChanges
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              icon: const Icon(Icons.save),
              onPressed: () {
                setState(() {
                  _unsavedChanges = false;
                });
              },
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              // Mitglied
              buildSectionTitle('Mitglied'),
              buildTwoColumnRow(
                buildFormTextField('Vorname'),
                buildFormTextField('Nachname'),
              ),
              buildTwoColumnRow(
                buildDropdownField(
                    ['männlich', 'weiblich', 'divers', 'Keine Angabe'],
                    'Geschlecht*'),
                buildDropdownField(['deutsch'], 'Staatsangehörigkeit'),
              ),
              buildTwoColumnRow(
                buildFormTextField('Konfession*'),
                buildDateField('Geburtsdatum'),
              ),
              buildTwoColumnRow(
                buildDateField('Eintritsdatum'),
                buildDropdownField(['Bieber', 'Wölfling'], 'Mitgliedsart'),
              ),
              // Beitrag
              buildSectionTitle('Beitrag'),
              buildTwoColumnRow(
                  buildDropdownField(
                      ['Normal', 'Familie', 'Sozial'], 'Beitragsart'),
                  buildFormTextField('Stammesbeitrag',
                      suffix: '€', readonly: true, value: '20'),
                  isSixtyForty: true),
              buildFullWidthCheckbox("Ja zum Stiftungseuro"),
              buildFullWidthCheckbox("Keine Mitgliedszeitschrift"),
              buildFullWidthCheckbox("Datenweiterverwendung"),
              // Anschrift
              buildSectionTitle('Anschrift'),
              buildFormTextField('Straße und Hausnummer', fullWidth: true),
              buildTwoColumnRow(
                buildFormTextField('PLZ'),
                buildFormTextField('Ort'),
              ),
              buildTwoColumnRow(
                buildFormTextField('Bundesland'),
                buildFormTextField('Land'),
              ),
              buildTwoColumnRow(
                buildFormTextField('Festnetznummer*'),
                buildFormTextField('Mobilfunknummer*'),
              ),
              buildTwoColumnRow(
                buildFormTextField('Geschäftlich*'),
                buildFormTextField('Fax*'),
              ),
              buildTwoColumnRow(
                buildFormTextField('E-Mail*'),
                buildFormTextField('E-Mail Sorgeberechtigter*'),
              ),

              // Kontodaten
              buildSectionTitle('Kontodaten'),
              buildFormTextField('Kontoinhaber', fullWidth: true),
              buildFormTextField('IBAN', fullWidth: true),
              buildTwoColumnRow(
                buildFormTextField('Kreditinstitut'),
                buildFormTextField('BIC'),
              ),
              Text('*Freiwillige Angaben'),
              Text(
                  'Ich bestätige die Daten, im falle eines Imports, auf korrektheit geprüft zu haben.'),
              TextButton(onPressed: () => {}, child: Text('Mitglied anlegen'))
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildTwoColumnRow(Widget child1, Widget child2,
      {bool isSixtyForty = false}) {
    return Row(
      children: [
        Expanded(
            flex: isSixtyForty
                ? 6
                : 5, // 60% of space for child1 if isSixtyForty is true, otherwise 50%
            child: child1),
        SizedBox(width: 8.0),
        Expanded(
            flex: isSixtyForty
                ? 4
                : 5, // 40% of space for child2 if isSixtyForty is true, otherwise 50%
            child: child2),
      ],
    );
  }

  Widget buildFormTextField(String label,
      {bool fullWidth = false,
      String suffix = '',
      readonly = false,
      value = ''}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        readOnly: readonly,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          hintText: ' ',
          suffixText: suffix,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget buildFullWidthCheckbox(String title) {
    return CheckboxListTile(
      title: Text(title),
      value: false,
      onChanged: (newValue) {},
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget buildDropdownField(List<String> options, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: DropdownButtonFormField<String>(
        value: options.first,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {});
        },
      ),
    );
  }

  Widget buildDateField(String label) {
    return Padding(
        padding: EdgeInsets.only(bottom: 8.0),
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
          },
          controller: TextEditingController(
              text: DateFormat('dd.MM.yyyy').format(DateTime.now())),
        ));
  }
}
