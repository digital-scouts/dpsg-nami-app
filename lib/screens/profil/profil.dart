import 'package:flutter/material.dart';
import 'package:nami/utilities/nami/model/nami_fz.model.dart';
import 'package:nami/utilities/nami/nami_fz.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class Profil extends StatefulWidget {
  const Profil({Key? key}) : super(key: key);

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  void loadAntrag() {
    loadFzAntrag().then((pdfData) async {
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/fuehrungszeugnisAntrag.pdf");
      await file.writeAsBytes(pdfData, flush: true);

      OpenFile.open(file.path);
    });
  }

  Widget buildFzList() {
    return FutureBuilder(
      future: loadFzDocumenets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Fehler beim Laden"));
        }

        final documents = snapshot.data as List<FzDocument>;
        documents.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));

        return ListView.builder(
          shrinkWrap: true,
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];
            return ListTile(
              title: Text(
                  'Bescheinigung (${document.fzNummer}) - ${document.erstelltAm.month}/${document.erstelltAm.year}'),
              onTap: () {
                loadFzDocument(document.id).then((pdfData) async {
                  final output = await getTemporaryDirectory();
                  final file = File(
                      "${output.path}/dpsg-fz-bescheinigung_${document.fzNummer}.pdf");
                  await file.writeAsBytes(pdfData, flush: true);

                  OpenFile.open(file.path);
                });
              },
            );
          },
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
          Text("Führungszeugnis",
              style: Theme.of(context).textTheme.titleMedium),
          TextButton(
              onPressed: loadAntrag, child: const Text("Antragsunterlagen")),
          buildFzList()
        ],
      ),
    );
  }
}
