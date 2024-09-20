import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/nami_change_toggle.dart';
import 'package:nami/screens/widgets/stamm_heim_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_datum_setting.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Willkommen'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Wir freunen uns, dich hier zu haben!",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Bitte beachte, dass unsere App sich noch in der Entwicklung befindet und es daher zu Problemen kommen kann. Dein Feedback ist uns jedoch sehr wichtig! Wenn du auf Probleme stößt oder Verbesserungsvorschläge hast, lass es uns bitte wissen. Wir sind dankbar für jede Unterstützung bei der Weiterentwicklung unserer App.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Wenige Einstellungen zu Beginn",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    StufenwechelDatumSetting(),
                    StammHeimSetting(),
                    NamiChangeToggle(showEditIcon: false)
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text("Willkommen und viel Spaß beim Erkunden!"),
            )
          ],
        ),
      ),
    );
  }
}
