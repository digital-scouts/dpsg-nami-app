import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
import 'package:nami/utilities/logger.dart';

import '../../utilities/stufe.dart';

class StufenwechselAlterSetting extends StatefulWidget {
  final Stufe stufe;

  const StufenwechselAlterSetting({super.key, required this.stufe});

  @override
  State<StufenwechselAlterSetting> createState() =>
      _StufenwechselAlterSettingState();
}

class _StufenwechselAlterSettingState extends State<StufenwechselAlterSetting> {
  final minAgeController = TextEditingController();
  final maxAgeController = TextEditingController();
  final maxAgeFocusNode = FocusNode();
  final minAgeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    maxAgeFocusNode.addListener(() {
      if (!maxAgeFocusNode.hasFocus) {
        // Das Textfeld hat den Fokus verloren
        int? number = int.tryParse(maxAgeController.text);
        if (number != null) {
          consLog.i('maxAgeFocusNode.addListener: $number');
          setStufeMaxAge(widget.stufe, number);
        }
      }
    });
    minAgeFocusNode.addListener(() {
      if (!minAgeFocusNode.hasFocus) {
        // Das Textfeld hat den Fokus verloren
        int? number = int.tryParse(minAgeController.text);
        if (number != null) {
          consLog.i('minAgeFocusNode.addListener: $number');
          setStufeMinAge(widget.stufe, number);
        }
      }
    });
  }

  @override
  void dispose() {
    // Vergessen Sie nicht, den Listener zu entfernen, wenn er nicht mehr benötigt wird
    maxAgeFocusNode.dispose();
    minAgeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    minAgeController.text = getStufeMinAge(widget.stufe).toString();
    maxAgeController.text = getStufeMaxAge(widget.stufe).toString();

    return ListTile(
      title: Text(widget.stufe.display),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: TextFormField(
              keyboardType: TextInputType.number,
              focusNode: minAgeFocusNode,
              controller: minAgeController,
              maxLength: 2,
              decoration: const InputDecoration(
                counterText: "",
                labelText: 'Alter von',
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            child: TextFormField(
              keyboardType: TextInputType.number,
              focusNode: maxAgeFocusNode,
              controller: maxAgeController,
              maxLength: 2,
              decoration: const InputDecoration(
                counterText: "",
                labelText: 'bis',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () {
              setStufeMinAge(widget.stufe, widget.stufe.alterMin ?? 0);
              setStufeMaxAge(widget.stufe, widget.stufe.alterMax ?? 99);
              minAgeController.text = getStufeMinAge(widget.stufe).toString();
              maxAgeController.text = getStufeMaxAge(widget.stufe).toString();
            },
          ),
        ],
      ),
    );
  }
}
