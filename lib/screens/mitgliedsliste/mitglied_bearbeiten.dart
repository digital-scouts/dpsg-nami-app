import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/mitgliedsliste/mitglied_details.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/external_apis/geoapify.dart';
import 'package:nami/utilities/external_apis/iban.dart';
import 'package:nami/utilities/external_apis/postcode.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/model/nami_member_details.model.dart';
import 'package:nami/utilities/nami/nami_member.service.dart';
import 'package:nami/utilities/nami/nami_member_add.service.dart';
import 'package:nami/utilities/nami/nami_member_add_meta.dart';
import 'package:nami/utilities/types.dart';
import 'package:wiredash/wiredash.dart';

// ignore: must_be_immutable
class MitgliedBearbeiten extends StatefulWidget {
  Mitglied? mitglied;

  MitgliedBearbeiten({this.mitglied, super.key});

  @override
  MitgliedBearbeitenState createState() => MitgliedBearbeitenState();
}

class MitgliedBearbeitenState extends State<MitgliedBearbeiten> {
  Timer? _adressAutocompleteDebounce;
  bool canPop = false;
  bool _submitInProgress = false;
  List<GeoapifyAdress> _adressAutocompleteAdressesResults = [];
  String _adressAutocompleteSearchString = '';
  bool _adressAutocompleteActive = true;
  bool validateOnInteraction = false;
  List<PlzResult> _plzResult = [];
  IbanResult? _ibanResult;
  Map<String, String> geschlechtOptions = {};
  Map<String, String> landOptions = {};
  Map<String, String> regionOptions = {};
  Map<String, String> beitragsartOptions = {};
  Map<String, String> mitgliedstypOptions = {};
  Map<String, String> staatsangehoerigkeitOptions = {};
  Map<String, String> konfessionOptions = {};
  Map<String, String> ersteTaetigkeitOptions = {};
  Map<String, String> ersteUntergliederungOptions = {};
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  void initState() {
    super.initState();
    loadMetadata();
    if (widget.mitglied != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState!.patchValue({
          'vorname': widget.mitglied!.vorname,
          'nachname': widget.mitglied!.nachname,
          'geschlecht': widget.mitglied!.geschlechtId.toString(),
          'staatsangehoerigkeit':
              widget.mitglied?.staatssangehaerigkeitId.toString() ??
              '1054', // default to deutsch
          'konfession': widget.mitglied?.konfessionId == 'null'
              ? ''
              : widget.mitglied?.konfessionId,
          'geburtstag': widget.mitglied!.geburtsDatum,
          'beitragsart':
              widget.mitglied?.beitragsartId.toString() ??
              '4', // Voller Beitrag - Stiftungseuro - VERBANDSBEITRAG,
          'mitgliedszeitschrift': widget.mitglied?.mitgliedszeitschrift ?? true,
          'datenweiterverwendung': widget.mitglied!.datenweiterverwendung,
          'street': widget.mitglied!.strasse,
          'plz': widget.mitglied!.plz,
          'festnetznummer': widget.mitglied!.telefon1,
          'mobilfunknummer': widget.mitglied!.telefon2,
          'geschaeftlich': widget.mitglied!.telefon3,
          'email': widget.mitglied!.email,
          'email_sorgeberechtigter':
              widget.mitglied!.emailVertretungsberechtigter,
        });
      });
      _adressAutocompleteActive = false;
      updateCityAfterPlzChange(widget.mitglied!.plz);
    }
  }

  bool isHausnummerInStreetIsMissing() {
    final formState = _formKey.currentState;
    if (formState == null) return false;

    final streetValue = formState.fields['street']?.value ?? '';
    // Check if street contains a number
    final hasHausnummer = streetValue.contains(RegExp(r'\d'));
    return !hasHausnummer;
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
    try {
      ersteUntergliederungOptions = await getErsteUntergliederungMeta(
        '1',
      ); //€ Mitglied
    } on SessionExpiredException catch (_) {
      if (!await AppStateHandler().setReloginState()) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }
    }

    setState(() {});
  }

  void _onWillPop(bool didPop, Object? result) async {
    if (didPop) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warnung!'),
        content: const Text(
          'Die eingegebenen Daten gehen beim Verlassen verloren. Möchtest du die Seite wirklich verlassen?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nein, weiter bearbeiten.'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                canPop = true;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Ja, verlassen.'),
          ),
        ],
      ),
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
            'land': _plzResult[0].country,
          });
        });
      }
    }
  }

  NamiMemberDetailsModel createMemberFromForm() {
    NamiMemberDetailsModel model = NamiMemberDetailsModel(
      vorname: _formKey.currentState!.fields['vorname']!.value,
      nachname: _formKey.currentState!.fields['nachname']!.value,
      geschlechtId: int.parse(
        _formKey.currentState!.fields['geschlecht']!.value.toString(),
      ),
      staatsangehoerigkeitId: int.parse(
        _formKey.currentState!.fields['staatsangehoerigkeit']!.value.toString(),
      ),
      konfessionId:
          _formKey.currentState!.fields['konfession']!.value.isNotEmpty
          ? int.parse(_formKey.currentState!.fields['konfession']!.value)
          : null,
      geburtsDatum: _formKey.currentState!.fields['geburtstag']!.value,
      eintrittsdatum:
          widget.mitglied?.eintrittsdatum ??
          _formKey.currentState!.fields['eintrittsdatum']!.value,
      beitragsartId: int.parse(
        _formKey.currentState!.fields['beitragsart']!.value.toString(),
      ),
      zeitschriftenversand:
          _formKey.currentState!.fields['mitgliedszeitschrift']!.value,
      wiederverwendenFlag:
          _formKey.currentState!.fields['datenweiterverwendung']!.value,
      strasse: _formKey.currentState!.fields['street']!.value,
      plz: _formKey.currentState!.fields['plz']!.value,
      ort: _formKey.currentState!.fields['ort']!.value,
      regionId: int.parse(
        regionOptions.entries
            .firstWhere(
              (element) => element.value.contains(
                _formKey.currentState!.fields['bundesland']!.value,
              ),
            )
            .key,
      ),
      landId: int.parse(
        landOptions.entries
            .firstWhere(
              (element) => element.value.contains(
                _formKey.currentState!.fields['land']!.value,
              ),
            )
            .key,
      ),
      telefon1: _formKey.currentState!.fields['festnetznummer']!.value,
      telefon2: _formKey.currentState!.fields['mobilfunknummer']!.value,
      telefon3: _formKey.currentState!.fields['geschaeftlich']!.value,
      email: _formKey.currentState!.fields['email']!.value,
      emailVertretungsberechtigter:
          _formKey.currentState!.fields['email_sorgeberechtigter']!.value,
      version: widget.mitglied == null ? 0 : widget.mitglied!.version,
      gruppierungId: getGruppierungId()!,
    );

    if (widget.mitglied != null) {
      model.id = widget.mitglied!.id;
    }

    if (widget.mitglied == null) {
      model.ersteTaetigkeitId = _formKey
          .currentState!
          .fields['taetigkeit']!
          .value
          .toString();
      model.ersteUntergliederungId = int.parse(
        _formKey.currentState!.fields['group']!.value.toString(),
      );
      model.mglTypeId = mitgliedstypOptions.entries
          .firstWhere((element) => element.value == 'Mitglied')
          .key;
      model.kontoverbindung = Kontoverbindung(
        kontoinhaber: _formKey.currentState!.fields['kontoinhaber']!.value,
        iban: _formKey.currentState!.fields['iban']!.value,
        bic: _formKey.currentState!.fields['bic']!.value,
        institut: _formKey.currentState!.fields['kreditinstitut']!.value,
      );
    }

    return model;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      key: const Key('MitgliedBearbeiten'),
      onPopInvokedWithResult: _onWillPop,
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
                  _twoColumnRow(
                    FormBuilderTextField(
                      name: 'vorname',
                      keyboardType: TextInputType.name,
                      validator: FormBuilderValidators.required(),
                      decoration: _buildActiveInputDecoration('Vorname *'),
                    ),
                    FormBuilderTextField(
                      name: 'nachname',
                      keyboardType: TextInputType.name,
                      validator: FormBuilderValidators.required(),
                      decoration: _buildActiveInputDecoration('Nachname *'),
                    ),
                  ),
                  _twoColumnRow(
                    FormBuilderDropdown(
                      name: 'geschlecht',
                      validator: FormBuilderValidators.required(),
                      decoration: _buildActiveInputDecoration('Geschlecht *'),
                      items: geschlechtOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {});
                      },
                    ),
                    FormBuilderDropdown(
                      name: 'staatsangehoerigkeit',
                      initialValue: '1054', // default to deutsch
                      validator: FormBuilderValidators.required(),
                      decoration: _buildActiveInputDecoration(
                        'Staatsangehörigkeit *',
                      ),
                      items: staatsangehoerigkeitOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {});
                      },
                    ),
                  ),
                  _twoColumnRow(
                    FormBuilderDropdown(
                      name: 'konfession',
                      initialValue: '',
                      items: konfessionOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {});
                      },
                      decoration: _buildActiveInputDecoration('Konfession'),
                    ),
                    FormBuilderDateTimePicker(
                      inputType: InputType.date,
                      name: 'geburtstag',
                      validator: FormBuilderValidators.required(),
                      format: DateFormat('dd.MM.yyyy'),
                      decoration: _buildActiveInputDecoration('Geburtstag *'),
                    ),
                  ),
                  if (widget.mitglied == null) // tätigkeit
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FormBuilderDropdown(
                        name: 'taetigkeit',
                        validator: FormBuilderValidators.required(),
                        initialValue: '1', // € Mitglied
                        decoration: _buildActiveInputDecoration('Tätigkeit *'),
                        items: ersteTaetigkeitOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) async {
                          if (newValue != null) {
                            ersteUntergliederungOptions =
                                await getErsteUntergliederungMeta(newValue);
                            _formKey.currentState!.patchValue({'group': ''});
                            setState(() {
                              ersteUntergliederungOptions =
                                  ersteUntergliederungOptions;
                            });
                          }
                        },
                      ),
                    ),
                  if (widget.mitglied == null) // group
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FormBuilderDropdown(
                        name: 'group',
                        validator: FormBuilderValidators.required(),
                        enabled: ersteUntergliederungOptions.isNotEmpty,
                        decoration: _buildActiveInputDecoration(
                          'Stufe/Abteilung *',
                        ),
                        items: ersteUntergliederungOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {});
                        },
                      ),
                    ),
                  if (widget.mitglied == null) // eintrittsdatum
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FormBuilderDateTimePicker(
                        inputType: InputType.date,
                        name: 'eintrittsdatum',
                        initialDate:
                            widget.mitglied?.eintrittsdatum ?? DateTime.now(),
                        initialValue:
                            widget.mitglied?.eintrittsdatum ?? DateTime.now(),
                        validator: FormBuilderValidators.required(),
                        format: DateFormat('dd.MM.yyyy'),
                        decoration: _buildActiveInputDecoration(
                          'Eintrittsdatum *',
                        ),
                      ),
                    ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('* Pflichtfeld'),
                  ),
                  // Beitrag
                  _buildSectionTitle('Beitrag'),
                  FormBuilderDropdown(
                    name: 'beitragsart',
                    validator: FormBuilderValidators.required(),
                    initialValue:
                        '4', // Voller Beitrag - Stiftungseuro - VERBANDSBEITRAG
                    decoration: _buildActiveInputDecoration('Beitragsart'),
                    items: beitragsartOptions.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {});
                    },
                  ),
                  FormBuilderCheckbox(
                    name: 'mitgliedszeitschrift',
                    initialValue: true,
                    title: const Text(
                      "Ich möchte die Mitgliederzeitschrift zugeschickt bekommen.",
                    ),
                    onChanged: (newValue) {},
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  FormBuilderCheckbox(
                    name: 'datenweiterverwendung',
                    initialValue: false,
                    title: const Text(
                      "Nach der Beendigung der Mitgliedschaft dürfen die Daten weiter genutzt werden.",
                    ),
                    onChanged: (newValue) {},
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  // Anschrift
                  _buildSectionTitle('Anschrift'),
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
                              if (_adressAutocompleteDebounce?.isActive ??
                                  false) {
                                _adressAutocompleteDebounce!.cancel();
                              }
                              Completer<Iterable<String>> completer =
                                  Completer<Iterable<String>>();

                              _adressAutocompleteDebounce = Timer(
                                const Duration(milliseconds: 500),
                                () async {
                                  try {
                                    _adressAutocompleteAdressesResults =
                                        await autocompleteGermanAdress(
                                          textEditingValue.text,
                                        );
                                    completer.complete(
                                      _adressAutocompleteAdressesResults
                                          .map((address) => address.formatted)
                                          .toList(),
                                    );
                                  } catch (e) {
                                    debugPrint(e.toString());
                                    sensLog.e('Failed to autocomplete adress');
                                    sensLog.e(e.toString());
                                    setState(() {
                                      _adressAutocompleteActive = false;
                                    });
                                  }
                                },
                              );

                              return completer.future;
                            },
                        onSelected: (String selection) async {
                          _adressAutocompleteSearchString = selection;
                          GeoapifyAdress adress =
                              _adressAutocompleteAdressesResults.firstWhere(
                                (element) => element.formatted == selection,
                              );

                          // Patch Werte im Formular
                          _formKey.currentState!.patchValue({
                            'street':
                                '${adress.street} ${adress.housenumber ?? ''}',
                            'plz': adress.postcode,
                            'ort': adress.city,
                            'bundesland': adress.state ?? adress.city,
                            'land': adress.country,
                          });

                          // State nach Patch aktualisieren, damit Werte im Widget sichtbar sind
                          setState(() {});
                        },
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController textEditingController,
                              FocusNode focusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              return TextFormField(
                                enabled: _adressAutocompleteActive,
                                controller: textEditingController,
                                keyboardType: TextInputType.streetAddress,
                                focusNode: focusNode,
                                decoration: _buildActiveInputDecoration(
                                  'Vollständige deutsche Anschrift',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Bitte geben Sie eine vollständige Adresse ein';
                                  }
                                  if (_formKey
                                          .currentState!
                                          .fields['street']!
                                          .value
                                          .isNotEmpty &&
                                      !_formKey
                                          .currentState!
                                          .fields['street']!
                                          .value
                                          .contains(RegExp(r'\d'))) {
                                    return 'Bitte geben Sie eine Hausnummer ein';
                                  }
                                  return null;
                                },
                              );
                            },
                      ),
                    ),
                  if (_adressAutocompleteActive)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        _formKey.currentState != null &&
                                _formKey.currentState!.fields['street'] !=
                                    null &&
                                _formKey.currentState!.fields['plz'] != null &&
                                _formKey.currentState!.fields['ort'] != null
                            ? '${_formKey.currentState!.fields['street']?.value ?? ''}, '
                                  '${_formKey.currentState!.fields['plz']?.value ?? ''} '
                                  '${_formKey.currentState!.fields['ort']?.value ?? ''} '
                            : '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (_adressAutocompleteActive &&
                      isHausnummerInStreetIsMissing())
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Hausnummer fehlt',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  Visibility(
                    visible: !_adressAutocompleteActive,
                    maintainState: true,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: FormBuilderTextField(
                            name: 'street',
                            readOnly: true,
                            decoration: _buildDisabledInputDecoration(
                              'Straße und Hausnummer',
                            ),
                          ),
                        ),
                        _twoColumnRow(
                          FormBuilderTextField(
                            name: 'plz',
                            readOnly: true,
                            decoration: _buildDisabledInputDecoration(
                              'Postleitzahl',
                            ),
                          ),
                          FormBuilderTextField(
                            name: 'ort',
                            readOnly: true,
                            decoration: _buildDisabledInputDecoration('Ort'),
                          ),
                        ),
                        _twoColumnRow(
                          FormBuilderTextField(
                            name: 'bundesland',
                            readOnly: true,
                            decoration: _buildDisabledInputDecoration(
                              'Bundesland',
                            ),
                          ),
                          FormBuilderTextField(
                            name: 'land',
                            readOnly: true,
                            decoration: _buildDisabledInputDecoration('Land'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _twoColumnRow(
                    FormBuilderTextField(
                      name: 'festnetznummer',
                      keyboardType: TextInputType.phone,
                      decoration: _buildActiveInputDecoration('Festnetznummer'),
                    ),
                    FormBuilderTextField(
                      name: 'mobilfunknummer',
                      keyboardType: TextInputType.phone,
                      decoration: _buildActiveInputDecoration(
                        'Mobilfunknummer',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      name: 'geschaeftlich',
                      keyboardType: TextInputType.phone,
                      decoration: _buildActiveInputDecoration(
                        'Weitere Nummer(n)',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      keyboardType: TextInputType.emailAddress,
                      name: 'email',
                      decoration: _buildActiveInputDecoration('E-Mail'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: FormBuilderTextField(
                      keyboardType: TextInputType.emailAddress,
                      name: 'email_sorgeberechtigter',
                      decoration: _buildActiveInputDecoration(
                        'E-Mail Sorgeberechtigter',
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('* Pflichtfeld'),
                  ),
                  // Kontodaten
                  if (widget.mitglied == null)
                    Row(
                      children: [
                        _buildSectionTitle('Deutsche Kontodaten'),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'Info',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Hinweis'),
                                content: const Text(
                                  'Die Kontodaten sind für die eigene Verwaltung und Zahlungsabwicklung und werden nicht von der DPSG benötigt.\n\nMöchtest du eine ausländische Kontoverbindung anlegen, musst du das über die NaMi Weboberfläche machen. Das Feld Zahlungsart darf dabei nicht ausgefüllt werden.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  if (widget.mitglied == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FormBuilderTextField(
                        name: 'kontoinhaber',
                        keyboardType: TextInputType.name,
                        decoration: _buildActiveInputDecoration('Kontoinhaber'),
                      ),
                    ),
                  if (widget.mitglied == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FormBuilderTextField(
                        name: 'iban',
                        maxLength: 22,
                        inputFormatters: [UpperCaseTextFormatter()],
                        onChanged: (iban) async {
                          _ibanResult = null;
                          setState(() {
                            _formKey.currentState!.patchValue({
                              'kreditinstitut': '',
                              'bic': '',
                            });
                          });

                          if (iban != null && iban.length == 22) {
                            _ibanResult = await validateIban(iban);
                            if (_ibanResult != null && _ibanResult!.valid) {
                              _formKey.currentState!.fields['iban']!.validate();
                              setState(() {
                                _formKey.currentState!.patchValue({
                                  'kreditinstitut': filterKreditinstitutName(
                                    _ibanResult!.name ?? '',
                                  ),
                                  'bic': _ibanResult!.bic,
                                });
                              });
                            } else {
                              // Zeige eine Fehlermeldung an, wenn die IBAN ungültig ist
                              setState(() {
                                _formKey.currentState!.fields['iban']!
                                    .invalidate('Ungültige IBAN');
                              });
                            }
                          }
                        },
                        decoration: _buildActiveInputDecoration('IBAN'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return null;
                          }
                          if (value.length != 22) {
                            return 'Die IBAN muss 22 Zeichen lang sein';
                          }
                          if (_ibanResult != null && !_ibanResult!.valid) {
                            return 'Ungültige IBAN';
                          }
                          return null;
                        },
                      ),
                    ),
                  if (widget.mitglied == null)
                    _twoColumnRow(
                      FormBuilderTextField(
                        name: 'kreditinstitut',
                        readOnly: true,
                        focusNode: AlwaysDisabledFocusNode(),
                        decoration: _buildDisabledInputDecoration(
                          'Kreditinstitut',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: FormBuilderTextField(
                          name: 'bic',
                          readOnly: true,
                          focusNode: AlwaysDisabledFocusNode(),
                          decoration: _buildDisabledInputDecoration('BIC'),
                        ),
                      ),
                    ),

                  _buildSectionTitle(
                    widget.mitglied == null
                        ? 'Neues Mitglied anlegen'
                        : 'Mitglied bearbeiten',
                  ),

                  FormBuilderCheckbox(
                    name: 'betaInfoChecked',
                    validator: FormBuilderValidators.required(),
                    title: Text(
                      "Ich habe zur Kenntnis genommen, dass beim ${widget.mitglied == null ? 'anlegen' : 'bearbeiten'} eines Mitglieds über die App Fehler auftreten können. Bitte prüfe die Daten nach dem ${widget.mitglied == null ? 'anlegen' : 'bearbeiten'}.",
                    ),
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
                      onPressed: _submitInProgress ? null : submit,
                      child: _submitInProgress
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                          : Text(
                              'Mitglied ${widget.mitglied == null ? 'anlegen' : 'bearbeiten'}',
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> submit() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _submitInProgress = true;
    });

    Wiredash.trackEvent(
      'Mitglied bearbeiten',
      data: {
        'type': 'submit button clicked',
        'valid': _formKey.currentState!.isValid,
      },
    );

    // invalid form
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _submitInProgress = false;
      });
      return;
    }

    // valid form
    NamiMemberDetailsModel formMitglied = createMemberFromForm();
    int memberId;
    try {
      if (widget.mitglied != null) {
        Wiredash.trackEvent('Mitglied bearbeiten', data: {'type': 'edit'});
        memberId = await editMember(formMitglied, scaffoldMessenger, navigator);
      } else {
        Wiredash.trackEvent('Mitglied bearbeiten', data: {'type': 'create'});
        memberId = await createNewMember(
          formMitglied,
          scaffoldMessenger,
          navigator,
        );
      }
    } catch (e) {
      sensLog.e('Failed to create/edit member');
      sensLog.e(e.toString());
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      Wiredash.trackEvent(
        'Mitglied bearbeiten',
        data: {'type': 'edit/create', 'error': e.toString()},
      );
      setState(() {
        _submitInProgress = false;
      });
      return;
    }

    Mitglied? mitglied;
    try {
      mitglied = await updateOneMember(memberId);
    } catch (e) {
      sensLog.e('Failed to update after successfull create/edit member');
      sensLog.e(e.toString());
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      Wiredash.trackEvent(
        'Mitglied bearbeiten',
        data: {'type': 'update', 'error': e.toString()},
      );
    }

    navigator.pop();
    setState(() {
      _submitInProgress = false;
    });

    if (mitglied != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => MitgliedDetail(mitglied: mitglied!),
        ),
      );
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Mitglied mit ID ${mitglied.id} erfolgreich ${widget.mitglied == null ? 'angelegt' : 'bearbeitet'}',
          ),
        ),
      );
    }
  }

  Future<int> editMember(
    NamiMemberDetailsModel formMitglied,
    ScaffoldMessengerState scaffoldMessenger,
    NavigatorState navigator,
  ) async {
    try {
      return await namiEditMember(formMitglied);
    } on MemberCreationException catch (_) {
      // Todo handle error
      rethrow;
    }
  }

  Future<int> createNewMember(
    NamiMemberDetailsModel formMitglied,
    ScaffoldMessengerState scaffoldMessenger,
    NavigatorState navigator,
  ) async {
    try {
      return await namiCreateMember(formMitglied);
    } on MemberCreationException catch (e) {
      if (e.fieldInfo.isNotEmpty) {
        showDialog(
          // ignore: use_build_context_synchronously
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Fehler beim Anlegen'),
              content: Text(
                e.fieldInfo
                    .map((e) => '${e.fieldName}: ${e.message}')
                    .join(', '),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      rethrow;
    }
  }

  InputDecoration _buildDisabledInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      counterText: '',
      fillColor: Theme.of(context).disabledColor,
      filled: true,
      border: const OutlineInputBorder(),
    );
  }

  InputDecoration _buildActiveInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      hintText: ' ',
      counterText: '',
      alignLabelWithHint: true,
      border: const OutlineInputBorder(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _twoColumnRow(Widget child1, Widget child2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 5, child: child1),
          const SizedBox(width: 8.0),
          Expanded(flex: 5, child: child2),
        ],
      ),
    );
  }
}

String filterKreditinstitutName(String input) {
  String filtered = input
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  if (filtered.length < 4) {
    filtered = filtered.padRight(4, 'x');
  }
  return filtered;
}

class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
