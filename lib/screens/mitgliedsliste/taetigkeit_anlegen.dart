import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:intl/intl.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/nami/nami_member_add_meta.dart';
import 'package:nami/utilities/nami/nami_taetigkeiten.service.dart';

class TaetigkeitAnlegen extends StatefulWidget {
  final int mitgliedId;
  const TaetigkeitAnlegen({required this.mitgliedId, super.key});

  @override
  TaetigkeitAnlegenState createState() => TaetigkeitAnlegenState();
}

class TaetigkeitAnlegenState extends State<TaetigkeitAnlegen> {
  Map<String, String> ersteTaetigkeitOptions = {};
  Map<String, String> ersteUntergliederungOptions = {};
  Map<int, String> caeaGroupOptions = {};
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  void initState() {
    super.initState();
    loadMetadata();
  }

  Future<void> loadMetadata() async {
    ersteTaetigkeitOptions = getErsteTaetigkeitOptions();
    ersteUntergliederungOptions =
        await getErsteUntergliederungMeta('1'); //€ Mitglied
    caeaGroupOptions = await loadCaeaGroupAufTaetigkeit('1'); //€ Mitglied
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tätigkeit erstellen'),
      content: FormBuilder(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: FormBuilderDateTimePicker(
                inputType: InputType.date,
                name: 'aktivVon',
                format: DateFormat('dd.MM.yyyy'),
                validator: FormBuilderValidators.required(),
                decoration: const InputDecoration(
                    labelText: 'Beginn',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: FormBuilderDropdown(
                name: 'taetigkeit',
                validator: FormBuilderValidators.required(),
                initialValue: '1', // € Mitglied
                decoration: const InputDecoration(
                    labelText: 'Tätigkeit',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
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
                    caeaGroupOptions =
                        await loadCaeaGroupAufTaetigkeit(newValue);
                    _formKey.currentState!.patchValue({
                      'group': '',
                      'caeaGroup': '',
                    });
                    setState(() {});
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
                    border: OutlineInputBorder()),
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
            if (caeaGroupOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: FormBuilderDropdown(
                  name: 'caeaGroup',
                  enabled: caeaGroupOptions.isNotEmpty,
                  decoration: const InputDecoration(
                      labelText: 'Rechte',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder()),
                  items: caeaGroupOptions.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {});
                  },
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Abbrechen'),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        TextButton(
          child: const Text('Speichern'),
          onPressed: () async {
            if (_formKey.currentState?.saveAndValidate(focusOnInvalid: false) ??
                false) {
              await createTaetigkeit(
                widget.mitgliedId,
                _formKey.currentState!.value['aktivVon'],
                _formKey.currentState!.value['taetigkeit'],
                _formKey.currentState!.value['group'],
                caeaGroup: _formKey.currentState!.value['caeaGroup'].toString(),
              );

              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
    );
  }
}
