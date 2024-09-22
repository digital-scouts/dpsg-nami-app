import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/hive.handler.dart';

class NewVersionInfoScreen extends StatelessWidget {
  final List<String> features;
  final List<String> bugFixes;
  final bool dataReset;
  final String version;
  const NewVersionInfoScreen({
    super.key,
    required this.features,
    required this.bugFixes,
    required this.version,
    this.dataReset = false,
  });

  Widget _buildDataResetWarning() {
    logout();
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.white),
          Expanded(
            child: Text(
              'Es gab größere Änderungen an der App, die ein zurücksetzten der Daten erfordern. Bitte melde dich erneut an.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewVersionInfo(String featureText, {bool isFeature = true}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isFeature ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          isFeature
              ? const Icon(Icons.new_releases, color: Colors.white)
              : const Icon(Icons.bug_report, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              featureText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String headerText) {
    return Container(
        margin: const EdgeInsets.only(top: 10),
        child: Text(
          headerText,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Was ist neu in Version $version'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 20.0,
              ),
              children: [
                if (dataReset) _buildDataResetWarning(),
                if (features.isNotEmpty) _buildSectionHeader('Neue Funktionen'),
                for (final feature in features) _buildNewVersionInfo(feature),
                if (bugFixes.isNotEmpty)
                  _buildSectionHeader('Fehlerbehebungen'),
                for (final bugFix in bugFixes)
                  _buildNewVersionInfo(bugFix, isFeature: false),
                const SizedBox(height: 20),
                Text(
                  "Bitte beachte, dass die App sich noch in der Entwicklung befindet und es daher zu Problemen kommen kann. Dein Feedback ist sehr wichtig! Wenn du auf Probleme stößt oder Verbesserungsvorschläge hast, lass es mich bitte wissen. Ich bin dankbar für jede Unterstützung bei der Weiterentwicklung dieser App.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 20.0,
              bottom: 40.0,
            ),
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              label: const Text("Weiter"),
            ),
          ),
        ],
      ),
    );
  }
}
