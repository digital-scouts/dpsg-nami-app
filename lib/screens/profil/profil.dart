import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/nami/model/nami_fz.model.dart';
import 'package:nami/utilities/nami/nami_fz.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/types.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  var loadingAntrag = false;
  bool sessionFailed = false;
  Future<List<FzDocument>>? documentsFuture;

  @override
  initState() {
    super.initState();
    documentsFuture = loadFzDocumenets();
  }

  Future<void> loadAntrag() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Wiredash.trackEvent('Fuehrungszeugnis', data: {'type': 'Antrag laden'});
    setState(() => loadingAntrag = true);
    try {
      final pdfData = await loadFzAntrag();
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/fuehrungszeugnisAntrag.pdf");
      await file.writeAsBytes(pdfData, flush: true);

      OpenFile.open(file.path);
    } on NamiServerException catch (_) {
      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text(
            'Serverfehler. Möglicherweise fehlt die Berechtigung zum laden der Antragsunterlagen.'),
      ));
    } finally {
      setState(() => loadingAntrag = false);
    }
  }

  Widget buildFzList() {
    return FutureBuilder(
      future: documentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          if (snapshot.error is SessionExpiredException) {
            setState(() {
              sessionFailed = true;
            });
            // Login abgelaufen -> await setReloginState();
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Session abgelaufen. Bitte erneut einloggen."),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await context
                          .read<AppStateHandler>()
                          .setReloginState(showDialog: false);

                      setState(() {
                        sessionFailed = false;
                      });
                    },
                    child: const Text("Erneut einloggen"),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text("Fehler beim Laden"));
        }

        final documents = snapshot.requireData;
        documents.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));

        return Card(
          child: Column(
            children: [
              for (final doc in documents)
                ListTile(
                  title: Text('Bescheinigung (${doc.fzNummer})'),
                  isThreeLine: true,
                  subtitle: Text(
                      'Bescheinigung von: ${doc.erstelltAm.prettyPrint()}\nFührungszeugnis von: ${doc.fzDatum.prettyPrint()}'),
                  onTap: () {
                    Wiredash.trackEvent('Führungszeugnis',
                        data: {'type': 'Bescheinigung laden'});
                    loadFzDocument(doc.id).then((pdfData) async {
                      final output = await getTemporaryDirectory();
                      final file = File(
                          "${output.path}/dpsg-fz-bescheinigung_${doc.fzNummer}.pdf");
                      await file.writeAsBytes(pdfData, flush: true);

                      OpenFile.open(file.path);
                    });
                  },
                )
            ],
          ),
        );
      },
    );
  }

  Widget buildFzView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Führungszeugnis",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (!sessionFailed)
          GestureDetector(
            onTap: loadAntrag,
            child: Text(
              "Antragsunterlagen laden",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: Colors.blue),
            ),
          ),
        const SizedBox(height: 8),
        buildFzList(),
      ],
    );
  }

  _buildFeatureIcon(bool active, IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        color: active ? Colors.green : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = getAllowedFeatures();

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Profil')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Berechtigungen",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Mitglied/Tätigkeiten',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.appStart),
                          Icons.visibility,
                          'Mitglieder anzeigen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.memberEdit),
                          Icons.edit,
                          'Mitglieder bearbeiten'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.memberCreate),
                          Icons.person_add_alt_1,
                          'Mitglieder hinzufügen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.memberImport),
                          Icons.group_add,
                          'Mitglieder übernehmen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.membershipEnd),
                          Icons.delete,
                          'Mitgliedschaft beenden'),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Ausbildung',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungRead),
                          Icons.visibility,
                          'Ausbidlungen anzeigen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungEdit),
                          Icons.edit,
                          'Ausbildungen bearbeiten'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungCreate),
                          Icons.add_box,
                          'Ausbildungen hinzufügen'),
                      _buildFeatureIcon(
                          features.contains(AllowedFeatures.ausbildungDelete),
                          Icons.delete,
                          'Ausbildungen löschen'),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Stufenwechsel',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                          message:
                              features.contains(AllowedFeatures.stufenwechsel)
                                  ? 'Stufenwechsel erlaubt'
                                  : 'Stufenwechsel nicht erlaubt',
                          child:
                              features.contains(AllowedFeatures.stufenwechsel)
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : const Icon(Icons.close, color: Colors.red)),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Führungszeugnis',
                  ),
                  subtitle: const Text('Laden von SGB VIII-Bescheinigungen'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                          message: features
                                  .contains(AllowedFeatures.stufenwechsel)
                              ? 'Führungszeugnis kann angezeigt werden'
                              : 'Führungszeugnis kann nicht angezeigt werden',
                          child: features
                                  .contains(AllowedFeatures.fuehrungszeugnis)
                              ? const Icon(Icons.check, color: Colors.green)
                              : const Icon(Icons.close, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (getAllowedFeatures().contains(AllowedFeatures.fuehrungszeugnis))
            buildFzView()
        ],
      ),
    );
  }
}
