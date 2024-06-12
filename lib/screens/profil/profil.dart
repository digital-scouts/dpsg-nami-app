import 'package:flutter/material.dart';
import 'package:nami/utilities/nami/model/nami_fz.model.dart';
import 'package:nami/utilities/nami/nami_fz.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/types.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Profil')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Deine Rechte:", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final feature in getAllowedFeatures())
                  ListTile(
                    title: Text(
                      feature.toReadableString(),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text("Führungszeugnis",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: loadingAntrag ? null : loadAntrag,
            child: loadingAntrag
                ? const CircularProgressIndicator()
                : const Text("Antragsunterlagen laden"),
          ),
          const SizedBox(height: 8),
          Text(
            "Deine Bescheinigungen",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          buildFzList(),
        ],
      ),
    );
  }
}
