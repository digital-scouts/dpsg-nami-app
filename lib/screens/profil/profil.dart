import 'package:flutter/material.dart';
import 'package:nami/utilities/nami/model/nami_fz.model.dart';
import 'package:nami/utilities/nami/nami_fz.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/types.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:wiredash/wiredash.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  var loadingAntrag = false;
  Future<List<FzDocument>>? documentsFuture;

  @override
  initState() {
    super.initState();
    documentsFuture = loadFzDocumenets();
  }

  Future<void> loadAntrag() async {
    Wiredash.trackEvent('Führungszeugnis', data: {'type': 'Antrag laden'});
    setState(() => loadingAntrag = true);
    try {
      final pdfData = await loadFzAntrag();
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/fuehrungszeugnisAntrag.pdf");
      await file.writeAsBytes(pdfData, flush: true);

      OpenFile.open(file.path);
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
                      Icon(
                        Icons.visibility,
                        color: features.contains(AllowedFeatures.appStart)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.edit,
                        color: features.contains(AllowedFeatures.memberEdit)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        color: features.contains(AllowedFeatures.memberCreate)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.group_add,
                        color: features.contains(AllowedFeatures.memberImport)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.delete,
                        color: features.contains(AllowedFeatures.membershipEnd)
                            ? Colors.green
                            : Colors.grey,
                      ),
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
                      Icon(
                        Icons.visibility,
                        color: features.contains(AllowedFeatures.ausbildungRead)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.edit,
                        color: features.contains(AllowedFeatures.ausbildungEdit)
                            ? Colors.green
                            : Colors.grey,
                      ),
                      Icon(
                        Icons.add_box,
                        color:
                            features.contains(AllowedFeatures.ausbildungCreate)
                                ? Colors.green
                                : Colors.grey,
                      ),
                      Icon(
                        Icons.delete,
                        color:
                            features.contains(AllowedFeatures.ausbildungDelete)
                                ? Colors.green
                                : Colors.grey,
                      ),
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
                      features.contains(AllowedFeatures.stufenwechsel)
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Icon(Icons.close, color: Colors.red),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Führungszeugnis',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      features.contains(AllowedFeatures.fuehrungszeugnis)
                          ? const Icon(Icons.check, color: Colors.green)
                          : const Icon(Icons.close, color: Colors.red),
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
