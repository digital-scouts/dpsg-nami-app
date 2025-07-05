import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/stufenwechsel_alter_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_datum_setting.dart';
import 'package:nami/utilities/stufe.dart';

class SettingsStufenwechsel extends StatelessWidget {
  const SettingsStufenwechsel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stufenwechsel')),
      body: ListView(
        children: const [
          StufenwechelDatumSetting(),
          StufenwechselAlterSetting(stufe: Stufe.BIBER),
          StufenwechselAlterSetting(stufe: Stufe.WOELFLING),
          StufenwechselAlterSetting(stufe: Stufe.JUNGPADFINDER),
          StufenwechselAlterSetting(stufe: Stufe.PFADFINDER),
          StufenwechselAlterSetting(stufe: Stufe.ROVER),
        ],
      ),
    );
  }
}
