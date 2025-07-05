import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/nami/model/nami_fz.model.dart';
import 'package:nami/utilities/nami/nami_fz.service.dart';
import 'package:nami/utilities/types.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wiredash/wiredash.dart';

class FuehrungszeugnisWidgets extends StatefulWidget {
  const FuehrungszeugnisWidgets({super.key});

  @override
  State<FuehrungszeugnisWidgets> createState() =>
      _FuehrungszeugnisWidgetsState();
}

class _FuehrungszeugnisWidgetsState extends State<FuehrungszeugnisWidgets> {
  Future<List<FzDocument>>? documentsFuture;
  var loadingAntrag = false;
  bool sessionFailed = false;
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
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Serverfehler. Möglicherweise fehlt die Berechtigung zum laden der Antragsunterlagen.',
          ),
        ),
      );
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
            sessionFailed = true;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Session abgelaufen. Bitte erneut einloggen."),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (await AppStateHandler().setReloginState(
                        showDialog: false,
                      )) {
                        sessionFailed = false;
                        documentsFuture = loadFzDocumenets();
                      }
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
                    'Bescheinigung von: ${doc.erstelltAm.prettyPrint()}\nFührungszeugnis von: ${doc.fzDatum.prettyPrint()}',
                  ),
                  onTap: () {
                    Wiredash.trackEvent(
                      'Führungszeugnis',
                      data: {'type': 'Bescheinigung laden'},
                    );
                    loadFzDocument(doc.id).then((pdfData) async {
                      final output = await getTemporaryDirectory();
                      final file = File(
                        "${output.path}/dpsg-fz-bescheinigung_${doc.fzNummer}.pdf",
                      );
                      await file.writeAsBytes(pdfData, flush: true);

                      OpenFile.open(file.path);
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(color: Colors.blue),
            ),
          ),
        const SizedBox(height: 8),
        buildFzList(),
      ],
    );
  }
}
