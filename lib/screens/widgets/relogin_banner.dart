import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:provider/provider.dart';

class ReloginBanner extends StatelessWidget {
  const ReloginBanner({super.key});

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
      child: syncState == SyncState.relogin
          ? MaterialBanner(
              leading: Icon(Icons.sync_problem,
                  color: Theme.of(context).colorScheme.error),
              content: const Text(
                  'Deine Sitzung ist abgelaufen, weshalb der tägliche Sync fehlschlug.'),
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
                    final successfulRelogin = await appStateHandler
                        .setReloginState(showDialog: false);
                    if (successfulRelogin) {
                      appStateHandler.setLoadDataState(
                          background: true, loadAll: false);
                    }
                  },
                ),
              ],
            )
          : const SizedBox(),
    );
  }
}
