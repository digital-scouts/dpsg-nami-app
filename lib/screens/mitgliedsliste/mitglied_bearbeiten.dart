import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/utilities/external_apis/geoapify.dart';
import 'package:nami/utilities/external_apis/iban.dart';
import 'package:nami/utilities/external_apis/postcode.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:intl/intl.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/nami/nami_member_add_meta.dart';

// ignore: must_be_immutable
class MitgliedBearbeiten extends StatefulWidget {
  Mitglied? mitglied;

  MitgliedBearbeiten({required this.mitglied, super.key});

  @override
  MitgliedBearbeitenState createState() => MitgliedBearbeitenState();
}

class MitgliedBearbeitenState extends State<MitgliedBearbeiten> {
  Timer? _adressAutocompleteDebounce;
  bool canPop = false;
  List<GeoapifyAdress> _adressAutocompleteAdressesResults = [];
  String _adressAutocompleteSearchString = '';
  bool _adressAutocompleteActive = true;
  bool validateOnInteraction = false;
  List<PlzResult> _plzResult = [];
  IbanResult? _ibanResult;
  List<String> geschlechtOptions = [];
  List<String> landOptions = [];
  List<String> regionOptions = [];
  List<String> beitragsartOptions = [];
  List<String> mitgliedstypOptions = [];
  List<String> staatsangehoerigkeitOptions = [];
  List<String> konfessionOptions = [];
  List<String> ersteTaetigkeitOptions = [];
  List<String> ersteUntergliederungOptions = [];
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
    konfessionOptions = getMetaKonfessionOptions();
    ersteTaetigkeitOptions = getErsteTaetigkeitOptions();
    ersteUntergliederungOptions =
        await getErsteUntergliederungMeta('€ Mitglied');
    setState(() {
      ersteUntergliederungOptions = ersteUntergliederungOptions;
    });
  }

  void _onWillPop(bool didPop) async {
    if (didPop) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Warnung!'),
          content: const Text(
              'Die eingegebenen Daten gehen beim Verlassen verloren. Möchtest du die Seite wirklich verlassen?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nein, weiter bearbeiten.'),
            ),
            TextButton(
              onPressed: () {
                // Pop
                Navigator.of(context).pop();
                setState(() {
                  canPop = true;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Ja, verlassen.'),
            )
          ]),
    );
  }

  Future<void> updateCityAfterPlzChange(String? plz) async {
    setState(() {
      _plzResult = [];
    });
    if (plz != null && plz.length == 5) {
      _plzResult = await fetchCityAndState(plz);
      setState(() {
        _plzResult = _plzResult;
      });
      if (_plzResult.length == 1) {
        setState(() {
          _formKey.currentState!.patchValue({
            'ort': _plzResult[0].city,
            'bundesland': _plzResult[0].state,
            'land': _plzResult[0].country
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      key: const Key('MitgliedBearbeiten'),
      onPopInvoked: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: widget.mitglied != null
              ? Text("${widget.mitglied!.vorname} ${widget.mitglied!.nachname}")
              : const Text("Neues Mitglied"),
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
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Colors.yellow[700]!,
                        width: 2.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.yellow[700],
                        ),
                        const SizedBox(width: 8.0),
                        const Expanded(
                          child: Text(
                            'Erstellen von Mitglieder noch nicht möglich. Dies ist nur ein Formular um die Funktionalität zu testen.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    FormBuilderDropdown(
                      name: 'konfession',
                      items: konfessionOptions.map((String value) {
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
                      decoration: const InputDecoration(
                        labelText: 'Konfession*',
                        alignLabelWithHint: true,
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

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderDropdown(
                      name: 'taetigkeit',
                      validator: FormBuilderValidators.required(),
                      initialValue: '€ Mitglied',
                      decoration: const InputDecoration(
                        label: Text('Erste Tätigkeit'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      items: ersteTaetigkeitOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          ersteUntergliederungOptions =
                              await getErsteUntergliederungMeta(newValue);
                          _formKey.currentState!.patchValue({
                            'group': '',
                          });
                          setState(() {
                            ersteUntergliederungOptions =
                                ersteUntergliederungOptions;
                          });
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderDropdown(
                      name: 'group',
                      validator: FormBuilderValidators.required(),
                      enabled: ersteUntergliederungOptions.isNotEmpty,
                      decoration: const InputDecoration(
                        labelText: 'Stufe/Abteilung',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      items: ersteUntergliederungOptions.map((String value) {
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderDateTimePicker(
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
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('*Freiwillige Angaben'),
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
                  // ToDo in case of error disable autocomplete field and activate manual input
                  if (_adressAutocompleteActive)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Autocomplete<String>(
                        optionsBuilder:
                            (TextEditingValue textEditingValue) async {
                          // skip when searing for same string again
                          if (_adressAutocompleteSearchString ==
                              textEditingValue.text) {
                            return _adressAutocompleteAdressesResults
                                .map((address) => address.formatted)
                                .toList();
                          }
                          _adressAutocompleteSearchString =
                              textEditingValue.text;

                          // return empty when string is too short
                          if (_adressAutocompleteSearchString.length < 5) {
                            _adressAutocompleteAdressesResults = [];
                            return const Iterable<String>.empty();
                          }

                          // debounce when typing
                          if (_adressAutocompleteDebounce?.isActive ?? false) {
                            _adressAutocompleteDebounce!.cancel();
                          }
                          Completer<Iterable<String>> completer =
                              Completer<Iterable<String>>();

                          _adressAutocompleteDebounce = Timer(
                              const Duration(milliseconds: 500), () async {
                            try {
                              _adressAutocompleteAdressesResults =
                                  await autocompleteGermanAdress(
                                      textEditingValue.text);
                              completer.complete(
                                  _adressAutocompleteAdressesResults
                                      .map((address) => address.formatted)
                                      .toList());
                            } catch (e) {
                              debugPrint(e.toString());
                              setState(() {
                                _adressAutocompleteActive = false;
                              });
                            }
                          });

                          return completer.future;
                        },
                        onSelected: (String selection) async {
                          _adressAutocompleteSearchString = selection;
                          GeoapifyAdress adress =
                              _adressAutocompleteAdressesResults.firstWhere(
                                  (element) => element.formatted == selection);
                          /*
                          bool valid  = await validateGermanAdress(
                              adress.housenumber ?? '',
                              adress.street,
                              adress.postcode,
                              adress.city);
                          todo what to do with invalid?
                          */
                          setState(() {
                            _formKey.currentState!.patchValue({
                              'street':
                                  '${adress.street} ${adress.housenumber ?? ''}',
                              'plz': adress.postcode,
                            });
                          });

                          updateCityAfterPlzChange(adress.postcode);
                        },
                        fieldViewBuilder: (BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted) {
                          return TextFormField(
                            enabled: _adressAutocompleteActive,
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Ganze Adresse suchen',
                              alignLabelWithHint: true,
                              hintText: ' ',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'street',
                      readOnly: _adressAutocompleteActive,
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
                        readOnly: _adressAutocompleteActive,
                        maxLength: 5,
                        validator: FormBuilderValidators.required(),
                        onChanged: (plz) async =>
                            {updateCityAfterPlzChange(plz)},
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
                      initialValue: 'Deutschland',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'geschaeftlich',
                      decoration: const InputDecoration(
                        labelText: 'Weitere Nummer(n)*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'email',
                      decoration: const InputDecoration(
                        labelText: 'E-Mail*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'email_sorgeberechtigter',
                      decoration: const InputDecoration(
                        labelText: 'E-Mail Sorgeberechtigter*',
                        alignLabelWithHint: true,
                        hintText: ' ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('*Freiwillige Angaben'),
                  ),
                  // Kontodaten
                  buildSectionTitle('Kontodaten'),
                  const Text(
                      'Die Kontodaten sind zum anlegen eines Mitglieds nicht notwendig. Dies kann auch später nachgetragen werden. Es werden nur Deutsche Konten akzeptiert.'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'kontoinhaber',
                      validator: FormBuilderValidators.required(),
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
                      validator: FormBuilderValidators.required(),
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
                  buildSectionTitle('Neues Mitglied anlegen'),

                  FormBuilderCheckbox(
                    name: 'betaInfoChecked',
                    validator: FormBuilderValidators.required(),
                    title: const Text(
                        "Ich habe zur Kenntnis genommen, dass beim Anlegen eines Mitglieds über die App Fehler auftreten können. Bitte prüfe die Daten nach dem anlegen."),
                    onChanged: (newValue) {},
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

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
