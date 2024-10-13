import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nami/screens/utilities/fuehrungszeugnis.widget.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/nami/nami_fz.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:nami/utilities/types.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

class LoadingInfoScreen extends StatefulWidget {
  final ValueNotifier<List<AllowedFeatures>> rechteProgressNotifier;
  final ValueNotifier<String?> gruppierungProgressNotifier;
  final ValueNotifier<bool?> metaProgressNotifier;
  final ValueNotifier<bool?> memberOverviewProgressNotifier;
  final ValueNotifier<double> memberAllProgressNotifier;
  final bool loadAll;

  const LoadingInfoScreen({
    super.key,
    required this.rechteProgressNotifier,
    required this.gruppierungProgressNotifier,
    required this.metaProgressNotifier,
    required this.memberOverviewProgressNotifier,
    required this.memberAllProgressNotifier,
    this.loadAll = false,
  });

  @override
  LoadingInfoScreenState createState() => LoadingInfoScreenState();
}

class LoadingInfoScreenState extends State<LoadingInfoScreen> {
  @override
  void initState() {
    super.initState();
    widget.rechteProgressNotifier.addListener(_updateProgress);
    widget.gruppierungProgressNotifier.addListener(_updateProgress);
    widget.metaProgressNotifier.addListener(_updateProgress);
    widget.memberOverviewProgressNotifier.addListener(_updateProgress);
    widget.memberAllProgressNotifier.addListener(_updateProgress);
  }

  @override
  void dispose() {
    widget.rechteProgressNotifier.removeListener(_updateProgress);
    widget.gruppierungProgressNotifier.removeListener(_updateProgress);
    widget.metaProgressNotifier.removeListener(_updateProgress);
    widget.memberOverviewProgressNotifier.removeListener(_updateProgress);
    widget.memberAllProgressNotifier.removeListener(_updateProgress);
    super.dispose();
  }

  void _updateProgress() {
    setState(() {
      // This will trigger a rebuild of the widget with the new progress value.
    });
  }

  bool get _isDone =>
      widget.rechteProgressNotifier.value.isNotEmpty &&
      widget.memberOverviewProgressNotifier.value == true &&
      (widget.loadAll
          ? widget.gruppierungProgressNotifier.value != null &&
              widget.memberAllProgressNotifier.value == 1 &&
              widget.metaProgressNotifier.value == true
          : widget.memberAllProgressNotifier.value == 1);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        drawerEnableOpenDragGesture: false,
        appBar: AppBar(
          title: const Text('Lade Informationen'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: [
            _buildLoadingStatusRow(
              Icons.security,
              'Rechte',
              widget.rechteProgressNotifier.value,
            ),
            if (widget.loadAll)
              _buildLoadingStatusRow(
                Icons.label,
                'Gruppierung',
                widget.gruppierungProgressNotifier.value,
              ),
            if (widget.loadAll)
              _buildLoadingStatusRow(
                Icons.info,
                'Metadaten',
                widget.metaProgressNotifier.value,
              ),
            _buildLoadingStatusRow(
              Icons.groups,
              'Mitglieder',
              widget.memberOverviewProgressNotifier.value,
            ),
            _buildLoadingStatusRow(
              Icons.person,
              'Mitglieder Details',
              widget.memberAllProgressNotifier.value,
            ),
            if (_isDone)
              FilledButton.icon(
                onPressed: () {
                  AppStateHandler().setReadyState();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Weiter'),
              ),
            if (context.watch<AppStateHandler>().syncState ==
                SyncState.error) ...[
              TextButton.icon(
                onPressed: () => showSendLogsDialog(),
                icon: const Icon(Icons.send),
                label: const Text("Logs teilen"),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);

                  AppStateHandler().setLoggedOutState();
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer,
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Fehler. Du wirst ausgeloggt.'),
              ),
            ] else if (context.watch<AppStateHandler>().syncState ==
                SyncState.offline)
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.wifi_off),
                label: const Text(
                    'Keine Netzwerkverbindung. Versuch es später erneut'),
              )
            else if (context.watch<AppStateHandler>().syncState ==
                SyncState.noPermission)
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.block),
                    label: const Text(
                        'Du hast nicht die notwendige Berechtigung die App zu nutzen.'),
                  ),
                  const FuehrungszeugnisWidgets()
                ],
              )
            else if (context.watch<AppStateHandler>().syncState ==
                SyncState.relogin)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.sync_problem),
                label:
                    const Text('Kein Sync möglich ohne erneute Anmeldung. OK'),
              ),
          ],
        ),
      ),
    );
  }

  // try to show the FuehrungszeugnisBescheinigung even when user has no permission to open the app
  Widget _buildFuehrungszeugnisBescheinigung() {
    return FutureBuilder(
      future: loadFzDocumenets(),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            snapshot.connectionState == ConnectionState.waiting ||
            snapshot.requireData.isEmpty) {
          return Container();
        }

        final documents = snapshot.requireData;
        documents.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));

        return Card(
          margin: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Text(
                'Aktuellste Führungszeugnis-Bescheinigung',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ListTile(
                title: Text('Bescheinigung (${documents.first.fzNummer})'),
                isThreeLine: true,
                subtitle: Text(
                    'Bescheinigung von: ${documents.first.erstelltAm.prettyPrint()}\nFührungszeugnis von: ${documents.first.fzDatum.prettyPrint()}'),
                onTap: () {
                  Wiredash.trackEvent('Führungszeugnis',
                      data: {'type': 'Bescheinigung laden'});
                  loadFzDocument(documents.first.id).then((pdfData) async {
                    final output = await getTemporaryDirectory();
                    final file = File(
                        "${output.path}/dpsg-fz-bescheinigung_${documents.first.fzNummer}.pdf");
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

  Widget _buildLoadingStatusRow(
      IconData iconData, String label, dynamic value) {
    Widget? trailing;
    Widget? subtitle;
    final colorScheme = Theme.of(context).colorScheme;
    final successIcon = Icon(Icons.check, color: colorScheme.primary);
    final errorIcon = Icon(Icons.check, color: colorScheme.error);
    if (value is bool?) {
      if (value == true) {
        trailing = successIcon;
      } else if (value == false) {
        trailing = errorIcon;
      } else {
        // bool is null
        trailing = const CircularProgressIndicator();
      }
    } else if (value is double) {
      if (value == 1) {
        trailing = successIcon;
      } else {
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            trailing = CircularProgressIndicator(value: value),
            const SizedBox(width: 8),
            Text('${(value * 100).toStringAsFixed(0)}%'),
          ],
        );
      }
    } else if (value is String && value.isNotEmpty) {
      subtitle = Text(value);
      trailing = successIcon;
    } else if (value is List<AllowedFeatures>) {
      if (value.isEmpty) {
        trailing = const CircularProgressIndicator();
      } else {
        trailing = successIcon;
      }
      subtitle = Text(
        value.map((e) => e.toReadableString()).join(", "),
      );
    } else if (value == null || value is String) {
      trailing = const CircularProgressIndicator();
    } else {
      trailing = errorIcon;
    }
    return ListTile(
      title: Text(label),
      leading: Icon(iconData),
      trailing: trailing,
      subtitle: subtitle,
    );
  }
}
