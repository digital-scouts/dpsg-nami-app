import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionInfo {
  final String version;
  final List<String> features;
  final List<String> bugFixes;
  final bool dataReset;

  VersionInfo(
      {required this.version,
      required this.features,
      required this.bugFixes,
      required this.dataReset});

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'],
      dataReset: json['data_reset'],
      features: List<String>.from(json['features']),
      bugFixes: List<String>.from(json['bugFixes']),
    );
  }
}

Future<List<VersionInfo>> loadVersionInfo() async {
  final jsonString = await rootBundle.loadString('assets/changelog.json');
  final jsonResponse = json.decode(jsonString);
  return (jsonResponse['versions'] as List)
      .map((data) => VersionInfo.fromJson(data))
      .toList();
}

class NewVersionInfoScreen extends StatelessWidget {
  final String currentVersion;

  const NewVersionInfoScreen({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Was ist neu in Version $currentVersion'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<VersionInfo>>(
        future: loadVersionInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Fehler beim Laden der Versionsinformationen'));
          }

          final versionInfo = snapshot.data?.firstWhere(
              (version) => version.version == currentVersion,
              orElse: () => VersionInfo(
                  version: '', dataReset: false, features: [], bugFixes: []));

          if (versionInfo == null) {
            return const Center(
                child: Text('Keine Informationen für diese Version gefunden'));
          }
          if (versionInfo.features.isEmpty) {
            versionInfo.features.add('Keine neuen Funktionen');
          }
          if (versionInfo.bugFixes.isEmpty) {
            versionInfo.bugFixes.add('Keine Fehlerbehebungen');
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (versionInfo.dataReset) _buildDataResetWarning(),
              if (versionInfo.features.isNotEmpty)
                _buildSectionHeader('Neue Funktionen'),
              for (final feature in versionInfo.features)
                _buildNewVersionInfo(feature),
              if (versionInfo.bugFixes.isNotEmpty)
                _buildSectionHeader('Fehlerbehebungen'),
              for (final bugFix in versionInfo.bugFixes)
                _buildNewVersionInfo(bugFix, isFeature: false),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: TextButton(
                  onPressed: () {
                    launchUrl(Uri.parse(
                        'https://github.com/digital-scouts/dpsg-nami-app/releases'));
                  },
                  child: const Text(
                    'Mehr Infos zu älteren Versionen',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
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
          );
        },
      ),
    );
  }

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
      ),
    );
  }
}
