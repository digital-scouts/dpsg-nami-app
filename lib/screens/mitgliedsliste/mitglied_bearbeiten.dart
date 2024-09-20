import 'package:flutter/material.dart';
import 'package:nami/utilities/external_apis/iban.dart';
import 'package:nami/utilities/external_apis/postcode.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:intl/intl.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:nami/utilities/hive/settings.dart';

// ignore: must_be_immutable
class MitgliedBearbeiten extends StatefulWidget {
  Mitglied? mitglied;

  MitgliedBearbeiten({required this.mitglied, super.key});

  @override
  MitgliedBearbeitenState createState() => MitgliedBearbeitenState();
}

class MitgliedBearbeitenState extends State<MitgliedBearbeiten> {
  bool _unsavedChanges = true;
  bool validateOnInteraction = false;
  List<PlzResult> _plzResult = [];
  IbanResult? _ibanResult;
  List<String> geschlechtOptions = [];
  List<String> landOptions = [];
  List<String> regionOptions = [];
  List<String> beitragsartOptions = [];
  List<String> mitgliedstypOptions = [];
  List<String> staatsangehoerigkeitOptions = [];
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  void initState() {
    super.initState();
    loadMetadata();
  }

  Future<void> loadMetadata() async {
    geschlechtOptions = getMetaGeschlechtOptions();
    landOptions = getMetaLandOptions();
    regionOptions = getMetaRegionOptions();
    beitragsartOptions = getMetaBeitragsartOptions();
    mitgliedstypOptions = getMetaMitgliedstypOptions();
    staatsangehoerigkeitOptions = getMetaStaatsangehoerigkeitOptions();
    return;
  }

  void _onWillPop(bool x) async {
    if (!_unsavedChanges || !_formKey.currentState!.isTouched) {
      return;
    }

    await showDialog(
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: widget.mitglied != null
              ? Text("${widget.mitglied!.vorname} ${widget.mitglied!.nachname}")
              : const Text("Neues Mitglied"),
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
        body: Container(
          margin: const EdgeInsets.all(8.0),
          child: FormBuilder(
            key: _formKey,
            autovalidateMode: validateOnInteraction
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Mitglied
                  buildSectionTitle('Mitglied'),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'vorname',
                      validator: FormBuilderValidators.required(),
                      decoration: const InputDecoration(
                        labelText: 'Vorname',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderTextField(
                      name: 'nachname',
                      validator: FormBuilderValidators.required(),
                      decoration: const InputDecoration(
                        labelText: 'Nachname',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderDropdown(
                      name: 'geschlecht',
                      validator: FormBuilderValidators.required(),
                      decoration: const InputDecoration(
                        labelText: 'Geschlecht',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      items: geschlechtOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {});
                      },
                    ),
                    FormBuilderDropdown(
                      name: 'staatsangehoerigkeit',
                      initialValue: 'deutsch',
                      validator: FormBuilderValidators.required(),
                      decoration: const InputDecoration(
                        labelText: 'Staatsangehörigkeit',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      items: staatsangehoerigkeitOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {});
                      },
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'konfession',
                      decoration: const InputDecoration(
                        labelText: 'Konfession*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderDateTimePicker(
                      inputType: InputType.date,
                      name: 'geburtstag',
                      validator: FormBuilderValidators.required(),
                      format: DateFormat('dd.MM.yyyy'),
                      decoration: const InputDecoration(
                        label: Text('Geburtstag'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderDateTimePicker(
                      inputType: InputType.date,
                      name: 'eintrittsdatum',
                      initialDate: DateTime.now(),
                      initialValue: DateTime.now(),
                      validator: FormBuilderValidators.required(),
                      format: DateFormat('dd.MM.yyyy'),
                      decoration: const InputDecoration(
                        label: Text('Eintrittsdatum'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderDropdown(
                      name: 'mitgliedsart',
                      validator: FormBuilderValidators.required(),
                      initialValue: 'Mitglied',
                      decoration: const InputDecoration(
                        labelText: 'Mitgliedsart',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      items: mitgliedstypOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {});
                      },
                    ),
                  ),
                  // Beitrag
                  buildSectionTitle('Beitrag'),
                  FormBuilderDropdown(
                    name: 'beitragsart',
                    validator: FormBuilderValidators.required(),
                    initialValue: 'Voller Beitrag - Stiftungseuro',
                    decoration: const InputDecoration(
                      labelText: 'Beitragsart',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    items: beitragsartOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {});
                    },
                  ),
                  const Text('Der Stammesbeitrag beträgt 20€.'),
                  FormBuilderCheckbox(
                    name: 'stiftungseuro',
                    initialValue: true,
                    title: const Text(
                        '"Ja!" zur Zukunft – "Ja!" zur Stiftung – "Ja!" zu einem Stiftungseuro pro Jahr'),
                    onChanged: (newValue) {},
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  FormBuilderCheckbox(
                    name: 'keine_mitgliedszeitschrift',
                    title: const Text(
                        "Ich möchte die Mitgliederzeitschrift nicht zugeschickt bekommen."),
                    onChanged: (newValue) {},
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  FormBuilderCheckbox(
                    name: 'datenweiterverwendung',
                    title: const Text(
                        "Nach der Beendigung der Mitgliedschaft dürfen die Daten weiter genutzt werden."),
                    onChanged: (newValue) {},
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  // Anschrift
                  buildSectionTitle('Anschrift'),
                  const Text('Es werden nur Deutsche Adressen akzeptiert.'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'street',
                      validator: FormBuilderValidators.required(),
                      decoration: const InputDecoration(
                        labelText: 'Straße und Hausnummer',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                      FormBuilderTextField(
                        name: 'plz',
                        maxLength: 5,
                        validator: FormBuilderValidators.required(),
                        onChanged: (plz) async => {
                          setState(() {
                            _plzResult = [];
                          }),
                          if (plz != null && plz.length == 5)
                            {
                              _plzResult = await fetchCityAndState(plz),
                              setState(() {
                                _plzResult = _plzResult;
                              }),
                              if (_plzResult.length == 1)
                                {
                                  setState(() {
                                    _formKey.currentState!.patchValue({
                                      'ort': _plzResult[0].city,
                                      'bundesland': _plzResult[0].state,
                                      'land': _plzResult[0].country
                                    });
                                  })
                                },
                            }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Postleitzahl',
                          alignLabelWithHint: true,
                          counterText: '',
                          hintText: ' ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      _plzResult.length < 2
                          ? FormBuilderTextField(
                              name: 'ort',
                              validator: FormBuilderValidators.required(),
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Ort',
                                alignLabelWithHint: true,
                                hintText: ' ',
                                border: OutlineInputBorder(),
                              ),
                            )
                          : FormBuilderDropdown(
                              name: 'ortDropdown',
                              validator: FormBuilderValidators.required(),
                              decoration: const InputDecoration(
                                labelText: 'Ort',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _plzResult.map((PlzResult value) {
                                return DropdownMenuItem<PlzResult>(
                                  value: value,
                                  child: Text(value.city),
                                );
                              }).toList(),
                              onChanged: (PlzResult? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _formKey.currentState!.patchValue({
                                      'bundesland': newValue.state,
                                      'land': newValue.country
                                    });
                                  });
                                }
                              },
                            )),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'bundesland',
                      validator: FormBuilderValidators.required(),
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Bundesland',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderTextField(
                      name: 'land',
                      readOnly: true,
                      validator: FormBuilderValidators.required(),
                      decoration: const InputDecoration(
                        labelText: 'Land',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'festnetznummer',
                      decoration: const InputDecoration(
                        labelText: 'Festnetznummer*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderTextField(
                      name: 'mobilfunknummer',
                      decoration: const InputDecoration(
                        labelText: 'Mobilfunknummer*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'geschaeftlich',
                      decoration: const InputDecoration(
                        labelText: 'Geschäftlich*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderTextField(
                      name: 'fax',
                      decoration: const InputDecoration(
                        labelText: 'Fax*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'email',
                      decoration: const InputDecoration(
                        labelText: 'E-Mail*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FormBuilderTextField(
                      name: 'email_sorgeberechtigter',
                      decoration: const InputDecoration(
                        labelText: 'E-Mail Sorgeberechtigter*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  // Kontodaten
                  buildSectionTitle('Kontodaten'),
                  const Text(
                      'Die Kontodaten sind zum anlegen eines Mitglieds nicht notwendig. Dies kann auch später nachgetragen werden. Es werden nur Deutsche Konten akzeptiert.'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'kontoinhaber',
                      decoration: const InputDecoration(
                        labelText: 'Kontoinhaber',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'iban',
                      maxLength: 22,
                      onChanged: (iban) async => {
                        _ibanResult = null,
                        setState(() {
                          _formKey.currentState!.patchValue({
                            'kreititnstitut': '',
                            'bic': '',
                          });
                        }),
                        if (iban != null && iban.length == 22)
                          {
                            _ibanResult = await validateIban(iban),
                            if (_ibanResult != null && _ibanResult!.valid)
                              {
                                setState(() {
                                  _formKey.currentState!.patchValue({
                                    'kreititnstitut': _ibanResult!.name,
                                    'bic': _ibanResult!.bic,
                                  });
                                })
                              }
                          }
                      },
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'IBAN',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  twoColumnRow(
                    FormBuilderTextField(
                      name: 'kreititnstitut',
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Kreditinstitut',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FormBuilderTextField(
                        name: 'bic',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'BIC',
                          alignLabelWithHint: true,
                          hintText: ' ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const Text('*Freiwillige Angaben'),
                  const Text(''),
                  const Text(
                      'Ich bestätige die Daten, vorallem im falle eines Imports, auf Korrektheit geprüft zu haben.'),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        validateOnInteraction = true;
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Processing Data')),
                          );
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget twoColumnRow(Widget child1, Widget child2) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Expanded(flex: 5, child: child1),
            const SizedBox(width: 8.0),
            Expanded(flex: 5, child: child2),
          ],
        ));
  }
}
