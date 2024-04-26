import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/types.dart';

class StufenwechelDatumSetting extends StatelessWidget {
  const StufenwechelDatumSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: settingsBox.listenable(),
      builder: (context, _, __) {
        return ListTile(
          title: const Text('Nächster Stufenwechsel'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                      initialDate: DateTime.now());
                  if (date != null) {
                    setStufenwechselDatum(date);
                  }
                },
                child: Text(
                  getStufenWechselDatum().prettyPrint(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
