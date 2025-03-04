import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/data_change_history.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/dataChanges.service.dart';
import 'package:nami/utilities/hive/dataChanges.dart';
import 'package:provider/provider.dart';

class StatusInformationBanner extends StatefulWidget {
  const StatusInformationBanner({super.key});

  @override
  StatusInformationBannerState createState() => StatusInformationBannerState();
}

class StatusInformationBannerState extends State<StatusInformationBanner> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = context.watch<AppStateHandler>().syncState;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        );
      },
      child: _buildBanner(syncState),
    );
  }

  void _showDataChangeDialog(List<DataChange> changes) {
    showDialog(
      context: context,
      builder: (context) {
        return DataChangeHistory(
            changes: changes, title: 'Neuste Änderungen', isDialog: true);
      },
    );
  }

  Widget _buildBanner(SyncState syncState) {
    switch (syncState) {
      case SyncState.loading:
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 30), () {
          context.read<AppStateHandler>().syncState = SyncState.notStarted;
        });
        return MaterialBanner(
          key: const ValueKey('loading'),
          leading: Icon(Icons.sync, color: Theme.of(context).colorScheme.error),
          content: const Text('Daten werden synchronisiert.'),
          actions: const [TextButton(onPressed: null, child: SizedBox())],
        );
      case SyncState.successful:
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 10), () {
          context.read<AppStateHandler>().syncState = SyncState.notStarted;
        });
        List<DataChange> changes = DataChangesService()
            .getLatestEntry(duration: const Duration(minutes: 5));
        return MaterialBanner(
          key: const ValueKey('successful'),
          leading: Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary),
          content:
              Text('Synchronisation erfolgreich. ${changes.length} Änderungen'),
          actions: [
            changes.isEmpty
                ? const SizedBox()
                : TextButton(
                    onPressed: () => _showDataChangeDialog(changes),
                    child: const Text('Anzeigen')),
          ],
        );
      case SyncState.relogin:
        return MaterialBanner(
          leading: Icon(Icons.sync_problem,
              color: Theme.of(context).colorScheme.error),
          content: const Text(
              'Tägliche Aktualisierung nicht möglich. Deine Sitzung ist abgelaufen.'),
          actions: [
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                context.read<AppStateHandler>().syncState =
                    SyncState.notStarted;
              },
            ),
            ElevatedButton(
              child: const Text('Anmelden'),
              onPressed: () async {
                final appStateHandler = context.read<AppStateHandler>();
                final successfulRelogin =
                    await appStateHandler.setReloginState(showDialog: false);
                if (successfulRelogin) {
                  appStateHandler.setLoadDataState(
                      background: true, loadAll: false);
                }
              },
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }
}
