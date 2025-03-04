import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';
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

  Widget _buildBanner(SyncState syncState) {
    switch (syncState) {
      case SyncState.loading:
        return MaterialBanner(
          key: const ValueKey('loading'),
          leading: Icon(Icons.sync, color: Theme.of(context).colorScheme.error),
          content: const Text('Daten werden synchronisiert.'),
          actions: const [TextButton(onPressed: null, child: SizedBox())],
        );
      case SyncState.successful:
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 5), () {
          context.read<AppStateHandler>().syncState = SyncState.notStarted;
        });
        return MaterialBanner(
          key: const ValueKey('successful'),
          leading: Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary),
          content: const Text('Synchronisation erfolgreich.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                context.read<AppStateHandler>().syncState =
                    SyncState.notStarted;
              },
            ),
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
